# frozen_string_literal: true

require_relative 'src/blockchain'

my_blockchain = Blockchain.new

my_blockchain.add_block('First Block')
my_blockchain.add_block('Second Block')
my_blockchain.add_block('Third Block')

my_blockchain.chain.each do |block|
  puts "Index: #{block.index}"
  puts "Timestamp: #{block.timestamp}"
  puts "Data: #{block.data}"
  puts "Previous Hash: #{block.previous_hash}"
  puts "Hash: #{block.hash}"
  puts '------'
end

puts "Blockchain valid? #{my_blockchain.valid?}"

my_blockchain.chain[1].instance_variable_set('@data', 'Tampered Data')

puts "Blockchain valid? #{my_blockchain.valid?}"
