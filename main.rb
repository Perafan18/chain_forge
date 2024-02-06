# frozen_string_literal: true
require 'sinatra'
require 'json'
require 'mongoid'
require 'dotenv/load'
require_relative 'src/blockchain'
Mongoid.load!('./config/mongoid.yml', ENV['ENVIRONMENT'] || :development)

get '/' do
  'Hello to ChainForge!'
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
  block = blockchain.add_block(block_data)

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

  valid = block.valid_data?(block_id, block_data)

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
