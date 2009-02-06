module TSearchable
  def self.included(base)
    base.extend ClassMethods
    base.extend SingletonMethods
  end

  module ClassMethods
    def tsearchable(options = {})
      @config = {:index => 'gist', :vector_name => 'ts_index', :catalog => 'pg_catalog.english' }
      @config.update(options) if options.is_a?(Hash)
      @config.each {|k,v| instance_variable_set(:"@#{k}", v)}
      raise "You must explicitly specify which fields you want to be searchable" unless @fields or @suggest

      @indexable_fields = @fields.inject([]) {|a,f| a << "coalesce(#{f.to_s},'')"}.join(' || \' \' || ') if not @fields.nil?
      @suggestable_fields = @suggest if not @suggest.nil?
      
      create_trigger
      create_tsvector
      
      named_scope :text_search, lambda { |search_terms|
        { :conditions => "#{@config[:vector_name]} @@ to_tsquery(#{self.quote_value(parse(search_terms))})" }
      }
      
#      after_save :update_tsvector_row
      define_method(:per_page) { 30 } unless respond_to?(:per_page)
      include TSearchable::InstanceMethods
    end

    private
      def coalesce(table, field)
        "coalesce(#{table}z.#{field},'')"
      end
  end

  module InstanceMethods
    def update_tsvector_row
      self.class.update_tsvector(self.id)
    end
  end

  #  text_searchable :fields => [:title, :body]
  module SingletonMethods    
    def find_by_trgm(keyword, options = {})
      raise ActiveRecord::RecordNotFound, "Couldn't find #{name} without a keyword" if keyword.blank?
      return if @suggestable_fields.empty?

      query = []
      sel = []
      @suggestable_fields.each do |field|
        query  << "#{field} % '#{clean(keyword)}'"
        sel << "similarity(#{field}, '#{clean(keyword)}') AS sml_#{field}"
      end
      query = query.join(" AND ")
      sel = sel.join(", ")
      
      options[:conditions] ? (options[:conditions] << ("AND " << query)) : (options[:conditions] = query)
      options[:select] = "*, " << sel
      options[:page] = nil if not options.key?(:page)
      
      paginate(options)
    end

    def update_tsvector(rowid = nil)
      create_tsvector unless column_names.include?(@vector_name)
      # added unindexable hook
      if respond_to?(:is_indexable) && !is_indexable?
        return update_all({:vector_name => nil}, {:id => id})
      end
      update = "UPDATE #{table_name} SET #{@vector_name} = to_tsvector(#{@indexable_fields})"
      update << " WHERE #{table_name}.id = #{rowid}" if rowid
      execute_query(update)
    end
    alias_method :update_vector, :update_tsvector

    # creates the tsvector column and the index
    def create_tsvector(sql = [])
      return if column_names.include?(@vector_name)
      
      sql << "ALTER TABLE #{table_name} ADD COLUMN #{@vector_name} tsvector"
      sql << "CREATE INDEX #{table_name}_ts_idx ON #{table_name} USING #{@index}(#{@vector_name})"
      execute_query(sql)
    end
    alias_method :create_vector, :create_tsvector
    
    # creates the trigram index
    def create_trgm(sql = [])
      return if column_names.include?(@vector_name)
      
      @suggestable_fields.each do |field|
        sql << "CREATE INDEX index_#{table_name}_#{field}_trgm ON #{table_name} USING gist(#{field} gist_trgm_ops)"
      end
      execute_query(sql)
    end

    # creates the trigger to auto-update vector column
    def create_trigger(sql = "")
      create_tsvector(sql) if not column_names.include?(@vector_name)

      sql << "CREATE TRIGGER tsvectorupdate_#{table_name}_#{@vector_name} BEFORE INSERT OR UPDATE ON #{table_name} FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger(#{@vector_name}, '#{@catalog}', " << @fields.join(' ,') << ')'
      execute_query(sql)
    rescue ActiveRecord::StatementInvalid => error
      raise error unless /already exists/.match error
    end

    # googly search terms to tsearch format.  jacked from bens acts_as_tsearch.
    def parse(query)
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
    
    def clean(query)
      query
    end

    # always reset the column info !
    def update_table
      yield
      reset_column_information
    end

    def count_all_indexable
      count(:conditions => {:is_indexable => true})
    end

    private

    def execute_query(sql)
      if sql.is_a? Array then
        sql.each {|s| update_table { connection.execute(s) }}
      else
        update_table { connection.execute(sql) }
      end
    end
  end
end
