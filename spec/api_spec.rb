# frozen_string_literal: true

require 'rspec'
require 'rack/test'
require_relative '../main'

RSpec.describe 'ChainForge API' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe 'GET /' do
    it 'returns welcome message' do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to eq('Hello to ChainForge!')
    end
  end

  describe 'POST /chain' do
    it 'creates a new blockchain' do
      post '/chain'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      json = JSON.parse(last_response.body)
      expect(json).to have_key('id')
      expect(json['id']).not_to be_nil
    end
  end

  describe 'POST /chain/:id/block' do
    let(:blockchain) { Blockchain.create! }
    let(:block_data) { { data: 'Test Block Data' } }

    it 'adds a new block to the blockchain' do
      post "/chain/#{blockchain.id}/block", block_data.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      json = JSON.parse(last_response.body)
      expect(json['chain_id']).to eq(blockchain.id.to_s)
      expect(json['block_id']).not_to be_nil
      expect(json['block_hash']).not_to be_nil
    end

    it 'returns error when chain not found' do
      post '/chain/invalid_id/block', block_data.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(500)
    end
  end

  describe 'POST /chain/:id/block/:block_id/valid' do
    let(:blockchain) { Blockchain.create! }
    let(:block_data) { { data: 'Validation Test Data' } }
    let!(:block) { blockchain.add_block(block_data[:data]) }

    it 'validates block with correct data' do
      post "/chain/#{blockchain.id}/block/#{block.id}/valid",
           block_data.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['valid']).to be true
    end

    it 'invalidates block with incorrect data' do
      invalid_data = { data: 'Wrong Data' }
      post "/chain/#{blockchain.id}/block/#{block.id}/valid",
           invalid_data.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['valid']).to be false
    end
  end
end
