require File.dirname(__FILE__) + '/test_helper'
require File.dirname(__FILE__) + '/tsearchable_helper'

require 'test/unit'

class TsearchableTest < Test::Unit::TestCase
  include TsearchableHelper
  
  def setup
    @moose     = TsearchableHelper.create_moose_article
    @woodchuck = TsearchableHelper.create_woodchuck_article
    @tagged    = TsearchableHelper.create_tagged_article
  end

  def teardown
    Article.delete_all
  end

  ## testing search
  def test_should_be_searchable
    assert Article.text_search("moose")
  end

  def test_should_find_a_result_with_matching_keyword
    # assert_equal @moose.id, Article.text_search("moose").first.id
    assert !Article.text_search("moose").empty?
  end

  def test_should_update_tsvector_row_on_save
    @moose.update_attributes({:title => 'bathtub full of badgers', :body => ''})
    assert !Article.text_search("badgers").empty?
  end

  def test_should_return_correct_number_from_count_by_text_search
    Article.create({:title => "moose"})
    assert_equal 2, Article.text_search("moose").count
  end

  ## testing parameter parsing
  def test_should_allow_OR_searches
    assert_equal 2, Article.text_search("moose OR woodchuck").count
  end

  def test_should_allow_AND_searches
    assert_equal 0, Article.text_search("moose AND woodchuck").count
  end

  def test_should_allow_MINUS_searches
    assert_equal 0, Article.text_search("moose -mousse").count
  end

  def test_should_allow_PLUS_searches
    assert_equal 1, Article.text_search("moose +mousse").count
  end
  
  def test_trgm_phrase_search
    assert_equal @moose.id, Article.phrase_search('moose mousse').first.id
  end
  
  def test_trgm_phrase_search_nonexistant_entry
    assert_equal 0, Article.phrase_search("blah 98248934894389 blah").count
  end
  
  def test_tags_are_getting_associated
    assert_equal 2, @tagged.tags.count
  end 
  
  # tests for computed fields
  def test_class_variable_is_set_properly
    assert_equal "tags.all.map(&:name).join(' ')", Article.text_search_config[:include]
  end
  
  def test_class_method_should_allow_a_proc_to_include_computed_fields
    article = Article.create(:title => 'hello')
    assert article.save
    tag = Tag.create(:name => 'crazy')
    assert tag.save
    article.tags << tag
    assert article.save
    assert article.tags.map(&:id).include?(tag.id)
    article.reload
    assert_match /craz/, article.vectors
  end
  
  def test_computed_fields_should_be_updated_when_model_is_saved_with_update_attributes
    article = Article.create(:title => 'hello')
    tag = Tag.create(:name => 'somelongword')
    article.tags << tag
    article.update_attributes(:title => 'new title')
    search = Article.text_search('somelongword')
    assert search.nitems == 1
    assert_equal article.id, search.first.id
  end
end
