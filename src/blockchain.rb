# frozen_string_literal: true

require 'mongoid'

require_relative 'block'

# This is the 'Blockchain' class which models a simple blockchain system.
# The Blockchain is an array of Blocks. It contains methods to create an instance
# of a Blockchain, to add a new block into the chain, to validate the entire chain, etc.
class Blockchain
  include Mongoid::Document

  has_many :blocks

  after_create :add_genesis_block

  # Add a new Block to this Blockchain
  #
  # @param data [Object] the data that needs to be added to the new Block
  # @param difficulty [Integer] the mining difficulty (number of leading zeros)
  # @return [Block] the newly created and mined Block
  def add_block(data, difficulty: 2)
    integrity_valid? or raise 'Blockchain is not valid'
    last_block = blocks.last
    block = blocks.build(
      index: last_block.index + 1,
      data:,
      previous_hash: last_block._hash,
      difficulty:
    )
    block.mine_block
    block.save!
    block
  end

  # Get the last block of this Blockchain
  #
  # @return [Block] the last Block in the Blockchain
  # @raise [RuntimeError] when no block exists in the Blockchain
  def last_block
    blocks.last or raise 'No block exists'
  end

  # Checks the validity of the Blockchain
  #
  # @return [Boolean] returns true if the blockchain is valid, otherwise false.
  def integrity_valid?
    blocks.each_cons(2).all? do |previous_block, current_block|
      previous_block._hash == current_block.previous_hash &&
        current_block._hash == current_block.calculate_hash &&
        current_block.valid_hash?
    end
  end

  private

  # Add a Genesis Block to this Blockchain
  # This method is automatically invoked when a new Blockchain is created
  def add_genesis_block
    blocks.create(index: 0, data: 'Genesis Block', previous_hash: '0') if blocks.empty?
  end
end
