require 'rubygems'
require 'activerecord'
require File.dirname(__FILE__) + '/../init'

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')

ActiveRecord::Base.establish_connection(config['jdbcpostgresql'])
load(File.dirname(__FILE__) + '/schema.rb')

begin 
  require 'redgreen'
  rescue LoadError  
end
