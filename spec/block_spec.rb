# frozen_string_literal: true

require 'rspec'
require_relative '../src/blockchain'

RSpec.describe Block do
  let(:blockchain) { Blockchain.create! }
  let(:index) { 1 }
  let(:data) { 'block data' }
  let(:prev_hash) { 'abcde12345' }
  let(:now) { Time.now.to_i }

  subject do
    described_class.create!(index:, data:, previous_hash: prev_hash, blockchain:)
  end

  it 'initializes with correct attributes' do
    expect(subject.index).to eq(index)
    expect(subject.data).to eq(data)
    expect(subject.previous_hash).to eq(prev_hash)
  end

  describe '#hash' do
    it 'returns a SHA256 hash' do
      expect(subject._hash.size).to eq(64) # A SHA256 digest string is 64 characters long
      expect(subject._hash).to_not include(' ') # A SHA256 digest string has no empty spaces
    end
  end

  describe '#created_at' do
    it 'returns the current Unix timestamp' do
      expect(subject.created_at.to_i).to be_within(1).of(now)
    end
  end

  describe '#valid_data?' do
    context 'when the data is valid' do
      it 'returns true' do
        expect(subject.valid_data?(data)).to be true
      end
    end

    context 'when the data is invalid' do
      it 'returns false' do
        expect(subject.valid_data?('invalid data')).to be false
      end
    end
  end
end
