# frozen_string_literal: true

# Set test environment
ENV['ENVIRONMENT'] = 'test'

# SimpleCov must be loaded before application code
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/config/'
    add_filter '/vendor/'

    add_group 'Models', 'src'
    add_group 'API', 'main.rb'

    minimum_coverage 80
  end
end

require 'mongoid'
require 'dotenv/load'
require 'rspec'

Mongoid.load!('./config/mongoid.yml', :test)
