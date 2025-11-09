# frozen_string_literal: true

require 'sinatra'
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

post '/chain' do
  blockchain = Blockchain.create
  blockchain.save!
  { id: blockchain.id }.to_json
end

post '/chain/:id/block' do
  block_data = parse_json_body
  chain_id = params[:id]
  blockchain = find_block_chain(chain_id)
  difficulty = block_data['difficulty'] || 2
  block = blockchain.add_block(block_data['data'], difficulty: difficulty)

  {
    chain_id: chain_id,
    block_id: block.id.to_s,
    block_hash: block._hash,
    nonce: block.nonce,
    difficulty: block.difficulty
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

get '/chain/:id/block/:block_id' do
  chain_id = params[:id]
  block_id = params[:block_id]
  blockchain = find_block_chain(chain_id)
  block = blockchain.blocks.find(block_id)
  raise 'Block not found' unless block

  {
    chain_id: chain_id,
    block: {
      id: block.id.to_s,
      index: block.index,
      data: block.data,
      hash: block._hash,
      previous_hash: block.previous_hash,
      nonce: block.nonce,
      difficulty: block.difficulty,
      timestamp: block.created_at.to_i,
      valid_hash: block.valid_hash?
    }
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
