# blockchain_spec.rb
require_relative '../src/blockchain'  # adjust this path to the correct one for your project
require_relative '../src/block'  # adjust this path to the correct one for your project

RSpec.describe Blockchain do
  subject { Blockchain.new }

  describe '#initialize' do
    it 'creates a new blockchain with a single block (genesis block)' do
      expect(subject.chain.length).to eq(1)
      expect(subject.chain[0].index).to eq(0)
    end
  end

  describe '#add_block' do
    it 'adds a new block to the blockchain' do
      subject.add_block('Block Data')
      expect(subject.chain.length).to eq(2)
    end
  end

  describe '#last_block' do
    it 'returns the last block in the chain' do
      subject.add_block('Block Data')
      expect(subject.last_block.data).to eq('Block Data')
    end
  end

  describe '#valid?' do
    it 'validates the blockchain' do
      expect(subject.valid?).to be true
    end

    it 'invalidates the blockchain if the hash is inconsistent' do
      subject.add_block('Block Data')
      subject.last_block.instance_variable_set(:@hash, 'bogus hash')
      expect(subject.valid?).to be false
    end
  end
end
