ActiveRecord::Schema.define(:version => 0) do
  create_table :articles, :force => true do |t|
    t.string     :title
    t.text       :body
    t.timestamps
  end
  
  create_table :tags, :force => true do |t|
    t.string    :name
    t.string    :taggable_type
    t.integer   :taggable_id
  end
end
