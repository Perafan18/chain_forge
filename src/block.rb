# frozen_string_literal: true

require 'digest'
require 'mongoid'

# The `Block` is part of a `Blockchain` that holds the digital
# information (the “block”) stored in a public database (the “chain”).
#
# Each `Block` has an `index`, a `timestamp` (in Unix time, auto-generated during creation),
# transaction `data`, a `hash` pointer to the previous block’s `hash`, and a `hash` of its own data.
class Block
  include Mongoid::Document
  include Mongoid::Timestamps

  # @!attribute [r] index
  #   @return [Integer] The location of the `Block` on the `Blockchain`.
  # @!attribute [r] data
  #   @return [Object] The information that is stored inside the `Block`.
  # @!attribute [r] previous_hash
  #   @return [String] The `hash` of the previous `Block` in the `Blockchain`.
  # @!attribute [r] nonce
  #   @return [Integer] The number used once for Proof of Work mining.
  # @!attribute [r] difficulty
  #   @return [Integer] The number of leading zeros required in the hash.
  field :index, type: Integer
  field :data, type: String
  field :previous_hash, type: String
  field :_hash, type: String, as: :hash
  field :nonce, type: Integer, default: 0
  field :difficulty, type: Integer, default: 2

  belongs_to :blockchain

  # Before committing an instance to the Database, calculate the `hash` of the block.
  before_validation :calculate_hash

  # Calculates the SHA256 hash of the block.
  #
  # The `hash` is generated from the `Block`'s `index`, `timestamp`, transaction `data`,
  # the `hash` of the previous block, and the `nonce`.
  #
  # @return [String] The `hash` of the block
  def calculate_hash
    set_created_at
    self._hash = Digest::SHA256.hexdigest("#{index}#{created_at.to_i}#{data}#{previous_hash}#{nonce}")
  end

  # Validates the integrity of the `Block`'s data.
  # @return [Boolean] `true` if the `Block`'s data is valid, `false` otherwise.
  def valid_data?(data)
    Digest::SHA256.hexdigest("#{index}#{created_at.to_i}#{data}#{previous_hash}#{nonce}") == _hash
  end

  # Mines the block using Proof of Work algorithm.
  #
  # Increments the nonce until a hash is found that starts with the required number
  # of leading zeros specified by the difficulty level.
  #
  # @return [String] The mined hash with required difficulty
  def mine_block
    target = '0' * difficulty
    loop do
      calculate_hash
      break if _hash.start_with?(target)

      self.nonce += 1
    end
    _hash
  end

  # Validates that the block's hash meets the difficulty requirement.
  #
  # @return [Boolean] `true` if the hash has the required leading zeros, `false` otherwise.
  def valid_hash?
    target = '0' * difficulty
    _hash.start_with?(target)
  end
end
