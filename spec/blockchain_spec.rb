# frozen_string_literal: true

require 'rspec'
require_relative '../src/blockchain'
require_relative '../src/block'

RSpec.describe Blockchain do
  subject { described_class.create! }

  describe '#initialize' do
    it 'creates a new blockchain with a single block (genesis block)' do
      expect(subject.blocks.count).to eq(1)
      expect(subject.blocks.first.index).to eq(0)
    end
  end

  describe '#add_block' do
    it 'adds a new block to the blockchain' do
      subject.add_block('Block Data')
      expect(subject.blocks.count).to eq(2)
    end
  end

  describe '#last_block' do
    it 'returns the last block in the chain' do
      subject.add_block('Block Data')
      expect(subject.last_block.data).to eq('Block Data')
    end
  end

  describe '#integrity_valid?' do
    it 'validates the blockchain' do
      expect(subject.integrity_valid?).to be true
    end

    it 'invalidates the blockchain if the hash is inconsistent' do
      subject.add_block('Block Data')
      subject.last_block.update_attribute(:_hash, 'bogus hash')
      expect(subject.integrity_valid?).to be false
    end
  end
end
