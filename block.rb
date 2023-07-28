# frozen_string_literal: true

require 'digest'

class Block
  attr_reader :index, :data, :timestamp, :previous_hash, :hash

  def initialize(index, data, previous_hash)
    @index = index
    @timestamp = time_now
    @data = data
    @previous_hash = previous_hash
    @hash = calculate_hash
  end

  def calculate_hash
    Digest::SHA256.hexdigest("#{@index}#{@timestamp}#{@data}#{@previous_hash}")
  end

  private

  def time_now
    Time.now.to_i
  end
end
