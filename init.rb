require 'tsearchable'
require 'postgresql_extensions'
ActiveRecord::Base.send :include, TSearchable
