require File.dirname(__FILE__) + '/lib/tsearchable'
require File.dirname(__FILE__) + '/lib/postgresql_extensions'
ActiveRecord::Base.send :include, TSearchable
