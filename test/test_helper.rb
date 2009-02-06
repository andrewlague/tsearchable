ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')

ActiveRecord::Base.establish_connection(config['jdbcpostgresql'])
load(File.dirname(__FILE__) + '/schema.rb')

begin 
  require 'redgreen'
  rescue LoadError  
end
