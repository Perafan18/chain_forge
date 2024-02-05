# frozen_string_literal: true

# This is the 'Blockchain' class which models a simple blockchain system.
# The Blockchain is an array of Blocks. It contains methods to create an instance
# of a Blockchain, to add a new block into the chain, to validate the entire chain, etc.

require_relative 'block'

class Blockchain
  # @return [Array<Block>] the array representation of the blockchain
  attr_reader :chain

  # Initialize the new Blockchain object with Genesis block
  # Genesis block is added to the blockchain during initilialization
  def initialize
    @chain = [create_genesis_block]
  end

  # This method adds a new block to the blockchain
  # @param data [Object] The data that needs to be added to the new block
  def add_block(data)
    @chain << new_block(data)
  end

  # This method returns the last block (current tail) of the blockchain
  # @return [Block] Returns the last block in the chain
  def last_block
    @chain.last
  end

  # This method checks if the blockchain is valid or not
  # It validates the hash links and recalculates the hashes to check consistency.
  # @return [Boolean] Returns true if the blockchain is valid, otherwise false.
  def valid?
    @chain.each_cons(2) do |previous_block, current_block|
      return false if previous_block.hash != current_block.previous_hash
      return false if current_block.hash != current_block.calculate_hash
    end

    true
  end

  private

  # This method creates a new block in the blockchain.
  # It calculates the new block's index, data and previous_hash.
  # @param data [Object] The data that needs to be added to the new block
  # @return [Block] Returns a new Block with the passed data and appropriate index, previous_hash
  def new_block(data)
    Block.new(
      last_block.index + 1,
      data,
      last_block.hash
    )
  end

  # This method creates the Genesis block
  # The genesis block is added to the blockchain during initialization,
  # and it is the only block that can have '0' as its previous_hash
  # @return [Block] Returns the genesis Block object
  # @raise [RuntimeError] Raises an error if an attempt to create genesis block is found when genesis block already exists in the chain
  def create_genesis_block
    raise 'Genesis Block already exists' unless @chain.nil?

    Block.new(
      0,
      'Genesis Block',
      '0'
    )
  end
end
