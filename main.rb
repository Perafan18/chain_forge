# frozen_string_literal: true

require 'sinatra'
require 'sinatra/namespace'
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
    validation = BlockDataContract.new.call(block_data)

    halt 400, { errors: validation.errors.to_h }.to_json if validation.failure?

    chain_id = params[:id]
    blockchain = find_block_chain(chain_id)
    difficulty = validate_difficulty(block_data['difficulty'])
    block = blockchain.add_block(validation[:data], difficulty: difficulty)

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

  def validate_difficulty(difficulty)
    difficulty = difficulty.nil? ? 2 : difficulty.to_i
    halt 422, { error: 'Difficulty must be a positive integer' }.to_json if difficulty <= 0
    halt 422, { error: 'Difficulty must be between 1 and 10' }.to_json if difficulty > 10
    difficulty
  end
end
