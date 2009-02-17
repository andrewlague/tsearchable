class Tag < ActiveRecord::Base
  belongs_to :taggable, :polymorphic => true
end

class Article < ActiveRecord::Base
  has_many :tags, :as => :taggable
  
  tsearchable :fields        => [ :title, :body ], 
              :vector_name   => 'vectors', 
              :suggest       => [ :title ],
              :include       => "tags.all.map(&:name).join(' ')"
end

module TsearchableHelper
  def self.create_moose_article
    title = "chocolate pudding is good, but mousse is better"
    body  = <<-EOS
      nothing beats a big bathtub full of chocolate mousse.  pudding seems a bit to slimy.
      mousse is silky and smooth.  moose are not silky.  they are hairy, and pretty damn big.
      never try filling you bathtub up with moose.  that is extremely dangerous.
      moose is dangerous, mousse isn't.  it's a common mistake.
      the words look too damn similar
    EOS
    Article.create({:title => title, :body => body})
  end

  def self.create_woodchuck_article
    title = "how much wood could a wood chuck chuck"
    body = <<-EOS
      how much wood could a woodchuck chuck if a woodchuck could chuck would?
      a woodchuck could chuck as much wood as a woodchuck could chuck if a woodchuck could chuck wood
    EOS
    Article.create({:title => title, :body => body})
  end
  
  def self.create_tagged_article
    article = Article.create :title => "an article with tags", :body  => "blah blah zeitgeist world"
    article.tags.create(:name => 'crazy')
    article.tags.create(:name => 'wonderful')
    article.reload
  end
end
