require File.dirname(__FILE__) + '/test_helper'
require File.dirname(__FILE__) + '/tsearchable_helper'

require 'test/unit'

class TsearchableTest < Test::Unit::TestCase
  include TsearchableHelper
  
  def setup
    @moose     = TsearchableHelper.create_moose_article
    @woodchuck = TsearchableHelper.create_woodchuck_article
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
end
