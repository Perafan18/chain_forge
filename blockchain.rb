# frozen_string_literal: true

require_relative 'block'

class Blockchain
  attr_reader :chain

  def initialize
    @chain = [create_genesis_block]
  end

  def add_block(data)
    @chain << new_block(data)
  end

  def new_block(data)
    Block.new(
      last_block.index + 1,
      data,
      last_block.hash
    )
  end

  def last_block
    @chain.last
  end

  def valid?
    @chain.each_cons(2) do |previous_block, current_block|
      return false if previous_block.hash != current_block.previous_hash
      return false if current_block.hash != current_block.calculate_hash
    end

    true
  end

  private

  def create_genesis_block
    raise 'Genesis Block already exists' unless @chain.nil?

    Block.new(
      0,
      'Genesis Block',
      '0'
    )
  end
end
