# frozen_string_literal: true
#
require 'rspec'
require_relative '../src/block'

RSpec.describe Block do
  let(:index) { 1 }
  let(:data) { 'block data' }
  let(:prev_hash) { 'abcde12345' }
  let(:now) { Time.now.to_i }

  subject { described_class.new(index, data, prev_hash) }

  it 'initializes with correct attributes' do
    expect(subject.index).to eq(index)
    expect(subject.data).to eq(data)
    expect(subject.previous_hash).to eq(prev_hash)
  end

  describe '#hash' do
    it 'returns a SHA256 hash' do
      expect(subject.hash.size).to eq(64)  #A SHA256 digest string is 64 characters long
      expect(subject.hash).to_not include(" ")  #A SHA256 digest string has no empty spaces
    end
  end

  describe '#timestamp' do
    it 'returns the current Unix timestamp' do
      expect(subject.timestamp).to be_within(1).of(now)
    end
  end
end
