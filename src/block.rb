# frozen_string_literal: true

require 'digest'

# The Block class is part of a Blockchain that holds the digital
# information (the “block”) stored in a public database (the “chain”).
#
# Each block has an index, a timestamp (in Unix time), transaction
# data, a hash pointer to the previous block’s hash, and a hash of its
# own data.
# It provides methods for creating and managing the blocks on the chain.
class Block
  # Allow read access for instance variables
  attr_reader :index, :data, :timestamp, :previous_hash, :hash

  # Initialize a new Block.
  #
  # @param [Integer] index The location of the block on the chain.
  # @param [Object] data The information that is stored inside the block.
  # @param [String] previous_hash The hash of the previous block in the chain.
  def initialize(index, data, previous_hash)
    @index = index
    @timestamp = current_time
    @data = data
    @previous_hash = previous_hash
    @hash = calculate_hash
  end

  # Calculates the SHA256 hash of the block.
  #
  # The hash is generated from the block's index, timestamp, transaction data,
  # and the hash of the previous block.
  #
  # @return [String] the hash of the block
  def calculate_hash
    Digest::SHA256.hexdigest("#{@index}#{@timestamp}#{@data}#{@previous_hash}")
  end

  private

  # Get the current unix timestamp
  # @return [Integer] current unix timestamp
  def current_time
    Time.now.to_i
  end
end
