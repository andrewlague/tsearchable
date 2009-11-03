module TSearchable
  def self.included(base)
    base.extend ClassMethods
    base.extend SingletonMethods
  end

  module ClassMethods
    def tsearchable(options = {})
      include TSearchable::InstanceMethods

      @text_search_config = {:index => 'gist', :vector_name => 'ts_index', :catalog => 'pg_catalog.english' }
      @text_search_config.update(options) if options.is_a?(Hash)
      
      unless @text_search_config[:fields] || @text_search_config[:suggest]
        raise "You must explicitly specify which fields you want to be searchable"
      end

      @text_search_indexable_fields = @text_search_config[:fields].inject([]) { |a,f| 
        a << "coalesce(#{f.to_s},'')" }.join(' || \' \' || ') if not @text_search_config[:fields].nil?
      
      create_tsvector_column   
      create_trgm_indexes
      
      named_scope :text_search, lambda { |search_terms|
        return {} if search_terms.blank?
        query = self.quote_value(text_search_parse(search_terms))
        {
                :select => self.table_name + ".*, ts_rank(#{@text_search_config[:vector_name]}, to_tsquery(#{query})) AS ts_rank", 
                :conditions => "#{@text_search_config[:vector_name]} @@ to_tsquery(#{query})",
                :order => "ts_rank DESC"
        }
      }

      named_scope :phrase_search, lambda { |phrase|
        returning options = {} do
          return options if phrase.blank?
          return options if @text_search_config[:suggest].empty?

          connection.execute 'SELECT set_limit(0.1)'

          query = []
          sel = []
          @text_search_config[:suggest].each do |field|
            query  << "#{field} % #{self.quote_value(phrase)}"
            sel << "similarity(#{field}, #{self.quote_value(phrase)}) AS sml_#{field}"
            options[:order] = "sml_#{field} DESC"
          end
          query = query.join(" AND ")
          sel = sel.join(", ")

          options[:conditions] ? (options[:conditions] << ("AND " << query)) : (options[:conditions] = query)
          options[:select] = "*, " << sel
        end
      }
    end

 
    private
 
    def coalesce(table, field)
      "coalesce(#{table}z.#{field},'')"
    end
  end



  module InstanceMethods
    def self.included(base)
      base.class_eval do
        def self.text_search_config
          @text_search_config.clone
        end

        def self.text_search_indexable_fields
          @text_search_indexable_fields.clone
        end
        after_save :update_tsvector
      end
    end
    
    def update_tsvector
      include_text = ""
      unless self.class.text_search_config[:include].nil?
        include_text = eval(self.class.text_search_config[:include])
      end
      sql = "UPDATE #{self.class.table_name} SET #{self.class.text_search_config[:vector_name]} =
             to_tsvector(#{self.class.text_search_indexable_fields} || ' ' || #{quote_value include_text})
             WHERE #{self.class.table_name}.id = #{self.id}"
      connection.execute sql
    end

    def text_search_score(terms)
      query = connection.quote(self.class.text_search_parse(terms))
      result = connection.execute "SELECT ts_rank(#{self.class.text_search_config[:vector_name]}, to_tsquery(#{query})) AS ts_rank 
                                   FROM #{self.class.table_name} WHERE id = #{id}"
      result[0]['ts_rank']
    end
  end


  module SingletonMethods    
    def update_tsvector_column
      create_tsvector unless column_names.include?(@text_search_config[:vector_name])
      all.each do |item|
        item.update_tsvector
      end
    end

    # creates the tsvector column and the index
    def create_tsvector_column
      return if column_names.include?(@text_search_config[:vector_name])
      connection.execute "ALTER TABLE #{table_name} ADD COLUMN 
            #{@text_search_config[:vector_name]} tsvector"
      connection.execute "CREATE INDEX #{table_name}_ts_idx ON #{table_name} USING 
            #{@text_search_config[:index]}(#{@text_search_config[:vector_name]})"
      reset_column_information
    end
    
    
    # creates the trigram indexes
    def create_trgm_indexes
      @text_search_config[:suggest].each do |field|
        create_trgm_index(field)
      end unless @text_search_config[:suggest].blank?
    end
    

    def create_trgm_index(field)
      connection.execute "CREATE INDEX index_#{table_name}_#{field}_trgm ON 
                          #{table_name} USING gin (#{field} gin_trgm_ops)"
    rescue ActiveRecord::StatementInvalid => error
      raise error unless /already exists/.match error
    end


    # googly search terms to tsearch format.  jacked from bens acts_as_tsearch.
    def text_search_parse(query)
      unless query.blank?
        query = query.gsub(/[^\w\-\+'"]+/, " ").gsub("'", "''").strip.downcase
        query = query.scan(/(\+|or \-?|and \-?|\-)?("[^"]*"?|[\w\-]+)/).collect do |prefix, term|
          term = "(#{term.scan(/[\w']+/).join('&')})" if term[0,1] == '"'
          term = "!#{term}" if prefix =~ /\-/
          [(prefix =~ /or/) ? '|' : '&', term] 
        end.flatten!
        query.shift
        query.join
      end
    end

  end
end
