# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'mongoid'
require 'dotenv/load'
require 'rack/attack'
require_relative 'src/blockchain'
require_relative 'src/validators'
require_relative 'config/rack_attack'

Mongoid.load!('./config/mongoid.yml', ENV['ENVIRONMENT'] || :development)

# Enable Rack::Attack middleware (disabled in test environment)
use Rack::Attack unless ENV['ENVIRONMENT'] == 'test'

get '/' do
  'Hello to ChainForge!'
end

post '/chain' do
  content_type :json
  blockchain = Blockchain.create
  blockchain.save!
  { id: blockchain.id }.to_json
end

post '/chain/:id/block' do
  content_type :json
  block_data = parse_json_body
  validation = BlockDataContract.new.call(block_data)

  halt 400, { errors: validation.errors.to_h }.to_json if validation.failure?

  chain_id = params[:id]
  blockchain = find_block_chain(chain_id)
  block = blockchain.add_block(validation[:data])

  {
    chain_id: chain_id,
    block_id: block.id.to_s,
    block_hash: block._hash
  }.to_json
end

post '/chain/:id/block/:block_id/valid' do
  content_type :json
  block_data = parse_json_body
  validation = BlockDataContract.new.call(block_data)

  halt 400, { errors: validation.errors.to_h }.to_json if validation.failure?

  chain_id = params[:id]
  block_id = params[:block_id]
  blockchain = find_block_chain(chain_id)
  block = blockchain.blocks.find(block_id)
  raise 'Block not found' unless block

  valid = block.valid_data?(validation[:data])

  {
    chain_id: chain_id,
    block_id: block.id.to_s,
    valid: valid
  }.to_json
end

helpers do
  def parse_json_body
    JSON.parse(request.body.read)
  end

  def find_block_chain(chain_id)
    blockchain = Blockchain.find(chain_id)
    raise 'Chain not found' unless blockchain

    blockchain
  end
end
