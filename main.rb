# frozen_string_literal: true

require 'sinatra'
require 'sinatra/namespace'
require 'json'
require 'mongoid'
require 'dotenv/load'
require_relative 'src/blockchain'

Mongoid.load!('./config/mongoid.yml', ENV['ENVIRONMENT'] || :development)

# Set default content type for JSON responses
before do
  content_type :json if request.post?
end

get '/' do
  content_type :html
  'Hello to ChainForge!'
end

# API v1
namespace '/api/v1' do
  before do
    content_type :json
  end

  post '/chain' do
    blockchain = Blockchain.create
    blockchain.save!
    { id: blockchain.id }.to_json
  end

  post '/chain/:id/block' do
    block_data = parse_json_body
    chain_id = params[:id]
    blockchain = find_block_chain(chain_id)
    block = blockchain.add_block(block_data['data'])

    {
      chain_id: chain_id,
      block_id: block.id.to_s,
      block_hash: block._hash
    }.to_json
  end

  post '/chain/:id/block/:block_id/valid' do
    block_data = parse_json_body
    chain_id = params[:id]
    block_id = params[:block_id]
    blockchain = find_block_chain(chain_id)
    block = blockchain.blocks.find(block_id)
    raise 'Block not found' unless block

    valid = block.valid_data?(block_data['data'])

    {
      chain_id: chain_id,
      block_id: block.id.to_s,
      valid: valid
    }.to_json
  end
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
