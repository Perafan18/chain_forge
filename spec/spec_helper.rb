# frozen_string_literal: true

require 'mongoid'
require 'dotenv/load'
require 'rspec'

Mongoid.load!('./config/mongoid.yml', ENV['ENVIRONMENT'] || :test)
