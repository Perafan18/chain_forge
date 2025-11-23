# Task 08: Structured Transaction Model

**PR**: #16
**Fase**: 3 - Blockchain Avanzado
**Complejidad**: Medium
**Estimación**: 5-6 días
**Prioridad**: P1
**Dependencias**: Task 07 (Merkle Trees) - works together

## Objetivo

Reemplazar strings opacos de "data" con un modelo estructurado de transacciones tipo Bitcoin/Ethereum, con campos específicos para sender, receiver, amount, etc.

## Motivación

**Problema actual**: Transactions son strings arbitrarios sin estructura. No hay forma de:
- Validar formato de transactions
- Trackear quién envía/recibe
- Calcular balances
- Buscar transactions por sender/receiver

**Solución**: Transaction model estructurado con campos typed y validación.

**Educational value**: Enseña cómo funcionan las transactions en blockchains reales.

## Transaction Schema

```ruby
{
  from: "alice_public_key",      # Sender address/public key
  to: "bob_public_key",          # Receiver address/public key
  amount: 100.0,                 # Amount transferred
  timestamp: 1699524000,         # Unix timestamp
  signature: "hex_signature",    # Digital signature (Task 09)
  data: "Optional memo",         # Additional data (optional)
  fee: 0.1                       # Transaction fee (optional)
}
```

## Cambios Técnicos

### 1. Transaction Model

**Archivo**: `src/models/transaction.rb`

```ruby
class Transaction
  include Mongoid::Document
  include Mongoid::Timestamps

  # Core fields
  field :from, type: String
  field :to, type: String
  field :amount, type: Float
  field :timestamp, type: Integer
  field :signature, type: String
  field :data, type: String  # Optional memo/metadata
  field :fee, type: Float, default: 0.0

  # Metadata
  field :tx_hash, type: String  # Hash of transaction
  field :block_index, type: Integer  # Which block included this tx
  field :confirmed, type: Boolean, default: false

  embedded_in :block

  # Validations
  validates :from, presence: true, length: { minimum: 10 }
  validates :to, presence: true, length: { minimum: 10 }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :timestamp, presence: true
  validates :fee, numericality: { greater_than_or_equal_to: 0 }

  validate :from_and_to_different
  validate :valid_signature_format

  before_validation :set_defaults
  before_save :calculate_tx_hash

  def calculate_tx_hash
    # Hash includes all transaction data except signature
    content = "#{from}#{to}#{amount}#{timestamp}#{data}#{fee}"
    self.tx_hash = Digest::SHA256.hexdigest(content)
  end

  # Convert to hash for merkle tree
  def to_merkle_hash
    {
      from: from,
      to: to,
      amount: amount,
      timestamp: timestamp,
      tx_hash: tx_hash
    }
  end

  # Serialize for API responses
  def as_json(options = {})
    {
      from: from,
      to: to,
      amount: amount,
      fee: fee,
      timestamp: timestamp,
      data: data,
      tx_hash: tx_hash,
      signature: signature,
      block_index: block_index,
      confirmed: confirmed
    }
  end

  private

  def set_defaults
    self.timestamp ||= Time.now.to_i
    self.tx_hash ||= calculate_tx_hash
  end

  def from_and_to_different
    if from == to
      errors.add(:to, "cannot be the same as from")
    end
  end

  def valid_signature_format
    # Placeholder - full validation in Task 09
    if signature.present? && signature.length < 64
      errors.add(:signature, "is too short")
    end
  end
end
```

### 2. Mempool (Transaction Pool)

**Archivo**: `src/models/mempool.rb`

```ruby
class Mempool
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :blockchain

  # Pending transactions
  field :pending_transactions, type: Array, default: []

  # Stats
  field :total_transactions, type: Integer, default: 0
  field :total_fees, type: Float, default: 0.0

  validates :blockchain, presence: true

  # Add transaction to mempool
  def add_transaction(tx_data)
    # Validate transaction
    tx = Transaction.new(tx_data)

    unless tx.valid?
      raise ValidationError, "Invalid transaction: #{tx.errors.full_messages.join(', ')}"
    end

    # Check for duplicates
    if transaction_exists?(tx.tx_hash)
      raise ValidationError, "Transaction already in mempool"
    end

    # Add to pending
    self.pending_transactions << tx.as_json
    self.total_transactions += 1
    self.total_fees += tx.fee

    save!

    LOGGER.info "Transaction added to mempool",
      blockchain_id: blockchain.id.to_s,
      tx_hash: tx.tx_hash,
      from: tx.from[0..15],
      to: tx.to[0..15],
      amount: tx.amount

    tx
  end

  # Get transactions for mining (highest fee first)
  def get_transactions_for_mining(limit = 100)
    pending_transactions
      .sort_by { |tx| -tx['fee'] }  # Highest fee first
      .take(limit)
  end

  # Remove transactions that were included in a block
  def remove_transactions(tx_hashes)
    removed_count = 0
    removed_fees = 0.0

    tx_hashes.each do |tx_hash|
      tx = pending_transactions.find { |t| t['tx_hash'] == tx_hash }
      if tx
        pending_transactions.delete(tx)
        removed_count += 1
        removed_fees += tx['fee']
      end
    end

    self.total_transactions -= removed_count
    self.total_fees -= removed_fees

    save! if removed_count > 0

    LOGGER.info "Transactions removed from mempool",
      count: removed_count,
      total_fees: removed_fees

    removed_count
  end

  # Check if transaction exists
  def transaction_exists?(tx_hash)
    pending_transactions.any? { |tx| tx['tx_hash'] == tx_hash }
  end

  # Clear all pending transactions
  def clear!
    count = pending_transactions.length
    self.pending_transactions = []
    self.total_transactions = 0
    self.total_fees = 0.0
    save!
    count
  end

  # Get mempool statistics
  def stats
    {
      pending_count: pending_transactions.length,
      total_fees: total_fees.round(4),
      avg_fee: pending_transactions.any? ? (total_fees / pending_transactions.length).round(4) : 0,
      oldest_tx: pending_transactions.min_by { |tx| tx['timestamp'] },
      highest_fee_tx: pending_transactions.max_by { |tx| tx['fee'] }
    }
  end
end
```

### 3. Actualizar Block Model

**Archivo**: `src/models/block.rb` (additions)

```ruby
class Block
  include Mongoid::Document
  include Mongoid::Timestamps

  field :index, type: Integer
  field :transactions, type: Array, default: []
  field :merkle_root, type: String
  field :hash, type: String
  field :previous_hash, type: String
  field :nonce, type: Integer, default: 0
  field :difficulty, type: Integer, default: 2
  field :timestamp, type: Integer
  field :mining_duration, type: Float

  # NEW: Transaction fees
  field :total_fees, type: Float, default: 0.0
  field :miner_reward, type: Float, default: 0.0

  embedded_in :blockchain

  # Convert transactions array to Transaction objects for validation
  def transaction_objects
    @transaction_objects ||= transactions.map do |tx_data|
      Transaction.new(tx_data)
    end
  end

  # Validate all transactions in block
  def valid_transactions?
    transaction_objects.all?(&:valid?)
  end

  # Calculate total fees
  def calculate_total_fees
    transaction_objects.sum(&:fee)
  end

  # Mark transactions as confirmed
  def confirm_transactions!
    self.total_fees = calculate_total_fees

    transactions.each do |tx|
      tx['confirmed'] = true
      tx['block_index'] = index
    end
  end

  # Add before mining
  before_validation :confirm_transactions!
end
```

### 4. Actualizar Blockchain Model

**Archivo**: `src/models/blockchain.rb` (additions)

```ruby
class Blockchain
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :blocks
  has_one :mempool

  field :current_difficulty, type: Integer, default: 2
  field :last_adjustment_at, type: Integer
  field :block_reward, type: Float, default: 50.0  # NEW: Mining reward

  after_create :create_mempool

  def initialize(attributes = {})
    super
    self.current_difficulty ||= 2
    self.last_adjustment_at ||= 0
    self.block_reward ||= 50.0
    create_genesis_block if blocks.empty?
  end

  # Mine block with transactions from mempool
  def mine_pending_transactions(miner_address, custom_difficulty: nil)
    # Get transactions from mempool
    tx_list = mempool.get_transactions_for_mining

    raise ValidationError, "No pending transactions to mine" if tx_list.empty?

    # Add coinbase transaction (mining reward)
    coinbase_tx = {
      from: "COINBASE",
      to: miner_address,
      amount: block_reward + tx_list.sum { |tx| tx['fee'] },
      timestamp: Time.now.to_i,
      data: "Block reward + fees",
      fee: 0.0
    }

    all_transactions = [coinbase_tx] + tx_list

    # Mine block
    new_block = add_block(all_transactions, custom_difficulty: custom_difficulty)

    # Remove mined transactions from mempool
    tx_hashes = tx_list.map { |tx| tx['tx_hash'] }
    mempool.remove_transactions(tx_hashes)

    LOGGER.info "Block mined with transactions",
      block_index: new_block.index,
      tx_count: all_transactions.length,
      total_fees: new_block.total_fees,
      miner_reward: coinbase_tx[:amount]

    new_block
  end

  # Get all transactions across all blocks
  def all_transactions
    blocks.flat_map(&:transactions)
  end

  # Find transaction by hash
  def find_transaction_by_hash(tx_hash)
    blocks.each do |block|
      tx = block.transactions.find { |t| t['tx_hash'] == tx_hash }
      return { transaction: tx, block: block } if tx
    end
    nil
  end

  # Calculate balance for an address
  def balance_of(address)
    received = 0.0
    sent = 0.0

    all_transactions.each do |tx|
      received += tx['amount'] if tx['to'] == address
      sent += (tx['amount'] + tx['fee']) if tx['from'] == address
    end

    received - sent
  end

  # Get transaction history for address
  def transaction_history(address, limit: 100)
    txs = all_transactions.select do |tx|
      tx['from'] == address || tx['to'] == address
    end

    txs.sort_by { |tx| -tx['timestamp'] }.take(limit)
  end

  private

  def create_mempool
    build_mempool.save! unless mempool.present?
  end

  def create_genesis_block
    genesis = blocks.build(
      index: 0,
      transactions: [{
        from: "GENESIS",
        to: "GENESIS",
        amount: 0,
        timestamp: Time.now.to_i,
        data: "Genesis Block",
        fee: 0.0
      }],
      previous_hash: '0',
      difficulty: current_difficulty
    )
    genesis.mine_block
  end
end
```

### 5. Transaction Validation Contract

**Archivo**: `lib/transaction_validator.rb`

```ruby
require 'dry-validation'

module ChainForge
  class TransactionValidator < Dry::Validation::Contract
    params do
      required(:from).filled(:string, min_size?: 10)
      required(:to).filled(:string, min_size?: 10)
      required(:amount).filled(:float, gt?: 0)
      optional(:fee).filled(:float, gteq?: 0)
      optional(:timestamp).filled(:integer)
      optional(:data).maybe(:string, max_size?: 1000)
      optional(:signature).maybe(:string)
    end

    rule(:from, :to) do
      if values[:from] == values[:to]
        key(:to).failure('cannot be the same as from')
      end
    end

    rule(:amount) do
      if values[:amount] && values[:amount] > 1_000_000
        key(:amount).failure('exceeds maximum allowed amount')
      end
    end

    rule(:fee) do
      if values[:fee] && values[:amount] && values[:fee] > values[:amount]
        key(:fee).failure('cannot be greater than amount')
      end
    end
  end
end
```

### 6. API Endpoints

**Archivo**: `main.rb`

```ruby
# Add transaction to mempool
post '/api/v1/chain/:id/transaction' do
  content_type :json

  # Validate input
  validator = ChainForge::TransactionValidator.new
  result = validator.call(params)

  if result.failure?
    halt 400, { errors: result.errors.to_h }.to_json
  end

  chain = Blockchain.find(params[:id])

  # Add to mempool
  tx = chain.mempool.add_transaction(result.to_h)

  status 201
  {
    message: "Transaction added to mempool",
    transaction: tx.as_json,
    mempool_size: chain.mempool.pending_transactions.length
  }.to_json
rescue ValidationError => e
  halt 400, { error: e.message }.to_json
end

# Mine pending transactions
post '/api/v1/chain/:id/mine' do
  content_type :json

  miner_address = params[:miner_address] || params[:to]
  halt 400, { error: 'Miner address required' }.to_json unless miner_address

  chain = Blockchain.find(params[:id])

  # Mine block with pending transactions
  block = chain.mine_pending_transactions(
    miner_address,
    custom_difficulty: params[:difficulty]&.to_i
  )

  {
    message: "Block mined successfully",
    block_index: block.index,
    block_hash: block.hash,
    transactions_count: block.transactions.length,
    total_fees: block.total_fees,
    miner_reward: block.transactions.first['amount'],  # Coinbase tx
    mining_duration: block.mining_duration.round(2)
  }.to_json
rescue ValidationError => e
  halt 400, { error: e.message }.to_json
end

# Get mempool status
get '/api/v1/chain/:id/mempool' do
  content_type :json

  chain = Blockchain.find(params[:id])

  {
    pending_transactions: chain.mempool.pending_transactions,
    stats: chain.mempool.stats
  }.to_json
end

# Get all transactions
get '/api/v1/chain/:id/transactions' do
  content_type :json

  chain = Blockchain.find(params[:id])

  # Optional filters
  address = params[:address]
  limit = (params[:limit] || 100).to_i

  transactions = if address
    chain.transaction_history(address, limit: limit)
  else
    chain.all_transactions.take(limit)
  end

  {
    chain_id: chain.id.to_s,
    transactions: transactions,
    count: transactions.length
  }.to_json
end

# Get transaction by hash
get '/api/v1/chain/:id/transaction/:tx_hash' do
  content_type :json

  chain = Blockchain.find(params[:id])
  result = chain.find_transaction_by_hash(params[:tx_hash])

  halt 404, { error: 'Transaction not found' }.to_json unless result

  {
    transaction: result[:transaction],
    block_index: result[:block].index,
    block_hash: result[:block].hash,
    confirmations: chain.blocks.length - result[:block].index
  }.to_json
end

# Get balance for address
get '/api/v1/chain/:id/balance/:address' do
  content_type :json

  chain = Blockchain.find(params[:id])
  balance = chain.balance_of(params[:address])

  {
    address: params[:address],
    balance: balance.round(4),
    chain_id: chain.id.to_s
  }.to_json
end
```

## Tests

**Archivo**: `spec/models/transaction_spec.rb`

```ruby
RSpec.describe Transaction do
  describe 'validations' do
    it 'validates presence of required fields' do
      tx = Transaction.new
      expect(tx.valid?).to be false
      expect(tx.errors[:from]).to be_present
      expect(tx.errors[:to]).to be_present
      expect(tx.errors[:amount]).to be_present
    end

    it 'validates amount is positive' do
      tx = Transaction.new(
        from: 'alice123456',
        to: 'bob123456',
        amount: -10
      )
      expect(tx.valid?).to be false
      expect(tx.errors[:amount]).to include('must be greater than 0')
    end

    it 'validates from and to are different' do
      tx = Transaction.new(
        from: 'alice123456',
        to: 'alice123456',
        amount: 10
      )
      expect(tx.valid?).to be false
      expect(tx.errors[:to]).to be_present
    end

    it 'creates valid transaction' do
      tx = Transaction.new(
        from: 'alice123456',
        to: 'bob123456',
        amount: 10.5,
        fee: 0.1
      )
      expect(tx.valid?).to be true
    end
  end

  describe '#calculate_tx_hash' do
    it 'generates consistent hash' do
      tx1 = Transaction.new(
        from: 'alice123456',
        to: 'bob123456',
        amount: 10,
        timestamp: 1234567890
      )
      tx1.calculate_tx_hash

      tx2 = Transaction.new(
        from: 'alice123456',
        to: 'bob123456',
        amount: 10,
        timestamp: 1234567890
      )
      tx2.calculate_tx_hash

      expect(tx1.tx_hash).to eq(tx2.tx_hash)
    end

    it 'generates different hash for different data' do
      tx1 = Transaction.new(
        from: 'alice123456',
        to: 'bob123456',
        amount: 10
      )
      tx1.calculate_tx_hash

      tx2 = Transaction.new(
        from: 'alice123456',
        to: 'bob123456',
        amount: 11
      )
      tx2.calculate_tx_hash

      expect(tx1.tx_hash).not_to eq(tx2.tx_hash)
    end
  end
end
```

**Archivo**: `spec/models/mempool_spec.rb`

```ruby
RSpec.describe Mempool do
  let(:chain) { Blockchain.create }
  let(:mempool) { chain.mempool }

  describe '#add_transaction' do
    it 'adds valid transaction to mempool' do
      tx_data = {
        from: 'alice123456',
        to: 'bob123456',
        amount: 10.0,
        fee: 0.1
      }

      tx = mempool.add_transaction(tx_data)

      expect(mempool.pending_transactions.length).to eq(1)
      expect(mempool.total_fees).to eq(0.1)
    end

    it 'rejects invalid transaction' do
      tx_data = {
        from: 'alice',
        to: 'bob',
        amount: -10  # Invalid amount
      }

      expect {
        mempool.add_transaction(tx_data)
      }.to raise_error(ValidationError)
    end

    it 'rejects duplicate transaction' do
      tx_data = {
        from: 'alice123456',
        to: 'bob123456',
        amount: 10.0,
        timestamp: 123456
      }

      mempool.add_transaction(tx_data)

      expect {
        mempool.add_transaction(tx_data)
      }.to raise_error(ValidationError, /already in mempool/)
    end
  end

  describe '#get_transactions_for_mining' do
    it 'returns transactions sorted by fee (highest first)' do
      mempool.add_transaction(from: 'alice123456', to: 'bob123456', amount: 10, fee: 0.1)
      mempool.add_transaction(from: 'bob123456', to: 'charlie123456', amount: 20, fee: 0.5)
      mempool.add_transaction(from: 'charlie123456', to: 'dave123456', amount: 15, fee: 0.3)

      txs = mempool.get_transactions_for_mining

      expect(txs.map { |tx| tx['fee'] }).to eq([0.5, 0.3, 0.1])
    end

    it 'respects limit parameter' do
      5.times do |i|
        mempool.add_transaction(
          from: "sender#{i}123456",
          to: "receiver#{i}123456",
          amount: 10,
          fee: i * 0.1
        )
      end

      txs = mempool.get_transactions_for_mining(3)
      expect(txs.length).to eq(3)
    end
  end

  describe '#remove_transactions' do
    it 'removes specified transactions' do
      tx1 = mempool.add_transaction(from: 'alice123456', to: 'bob123456', amount: 10, fee: 0.1)
      tx2 = mempool.add_transaction(from: 'bob123456', to: 'charlie123456', amount: 20, fee: 0.2)

      removed = mempool.remove_transactions([tx1.tx_hash])

      expect(removed).to eq(1)
      expect(mempool.pending_transactions.length).to eq(1)
      expect(mempool.total_fees).to eq(0.2)
    end
  end
end
```

**Archivo**: `spec/models/blockchain_transactions_spec.rb`

```ruby
RSpec.describe 'Blockchain with Transactions' do
  let(:chain) { Blockchain.create }

  describe '#mine_pending_transactions' do
    before do
      # Add transactions to mempool
      chain.mempool.add_transaction(
        from: 'alice123456',
        to: 'bob123456',
        amount: 10.0,
        fee: 0.1
      )
      chain.mempool.add_transaction(
        from: 'bob123456',
        to: 'charlie123456',
        amount: 5.0,
        fee: 0.05
      )
    end

    it 'mines block with pending transactions' do
      block = chain.mine_pending_transactions('miner123456', custom_difficulty: 1)

      # Should have coinbase tx + 2 pending txs
      expect(block.transactions.length).to eq(3)

      # First tx should be coinbase (mining reward)
      coinbase = block.transactions.first
      expect(coinbase['from']).to eq('COINBASE')
      expect(coinbase['to']).to eq('miner123456')
      expect(coinbase['amount']).to eq(50.15)  # 50 reward + 0.15 fees
    end

    it 'clears mempool after mining' do
      chain.mine_pending_transactions('miner123456', custom_difficulty: 1)

      expect(chain.mempool.pending_transactions).to be_empty
      expect(chain.mempool.total_fees).to eq(0)
    end

    it 'raises error when no pending transactions' do
      chain.mempool.clear!

      expect {
        chain.mine_pending_transactions('miner123456')
      }.to raise_error(ValidationError, /No pending transactions/)
    end
  end

  describe '#balance_of' do
    before do
      # Mine some blocks with transactions
      chain.mempool.add_transaction(from: 'alice123456', to: 'bob123456', amount: 10, fee: 0.1)
      chain.mine_pending_transactions('miner123456', custom_difficulty: 1)

      chain.mempool.add_transaction(from: 'bob123456', to: 'charlie123456', amount: 5, fee: 0.05)
      chain.mine_pending_transactions('miner123456', custom_difficulty: 1)
    end

    it 'calculates balance correctly' do
      # Alice sent 10 + 0.1 fee = -10.1
      expect(chain.balance_of('alice123456')).to eq(-10.1)

      # Bob received 10, sent 5 + 0.05 fee = +4.95
      expect(chain.balance_of('bob123456')).to eq(4.95)

      # Charlie received 5
      expect(chain.balance_of('charlie123456')).to eq(5.0)

      # Miner received rewards + fees
      # Block 1: 50 + 0.1 = 50.1
      # Block 2: 50 + 0.05 = 50.05
      expect(chain.balance_of('miner123456')).to eq(100.15)
    end
  end

  describe '#transaction_history' do
    before do
      chain.mempool.add_transaction(from: 'alice123456', to: 'bob123456', amount: 10, fee: 0)
      chain.mine_pending_transactions('miner123456', custom_difficulty: 1)

      chain.mempool.add_transaction(from: 'bob123456', to: 'alice123456', amount: 5, fee: 0)
      chain.mine_pending_transactions('miner123456', custom_difficulty: 1)
    end

    it 'returns transaction history for address' do
      history = chain.transaction_history('alice123456')

      expect(history.length).to eq(2)
      expect(history.any? { |tx| tx['from'] == 'alice123456' }).to be true
      expect(history.any? { |tx| tx['to'] == 'alice123456' }).to be true
    end

    it 'respects limit parameter' do
      history = chain.transaction_history('miner123456', limit: 1)
      expect(history.length).to eq(1)
    end
  end
end
```

**Archivo**: `spec/api/transactions_spec.rb`

```ruby
RSpec.describe 'Transactions API' do
  let!(:chain) { Blockchain.create }

  describe 'POST /api/v1/chain/:id/transaction' do
    it 'adds transaction to mempool' do
      post "/api/v1/chain/#{chain.id}/transaction", {
        from: 'alice123456',
        to: 'bob123456',
        amount: 10.0,
        fee: 0.1
      }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)

      expect(data['transaction']['tx_hash']).to be_present
      expect(data['mempool_size']).to eq(1)
    end

    it 'rejects invalid transaction' do
      post "/api/v1/chain/#{chain.id}/transaction", {
        from: 'alice',
        to: 'bob',
        amount: -10
      }

      expect(last_response.status).to eq(400)
    end
  end

  describe 'POST /api/v1/chain/:id/mine' do
    before do
      chain.mempool.add_transaction(
        from: 'alice123456',
        to: 'bob123456',
        amount: 10,
        fee: 0.1
      )
    end

    it 'mines pending transactions' do
      post "/api/v1/chain/#{chain.id}/mine", {
        miner_address: 'miner123456',
        difficulty: 1
      }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['transactions_count']).to eq(2)  # Coinbase + 1 tx
      expect(data['total_fees']).to eq(0.1)
      expect(data['miner_reward']).to eq(50.1)
    end

    it 'requires miner address' do
      post "/api/v1/chain/#{chain.id}/mine"

      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /api/v1/chain/:id/mempool' do
    it 'returns mempool status' do
      chain.mempool.add_transaction(
        from: 'alice123456',
        to: 'bob123456',
        amount: 10,
        fee: 0.1
      )

      get "/api/v1/chain/#{chain.id}/mempool"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['pending_transactions'].length).to eq(1)
      expect(data['stats']['total_fees']).to eq(0.1)
    end
  end

  describe 'GET /api/v1/chain/:id/balance/:address' do
    before do
      chain.mempool.add_transaction(from: 'alice123456', to: 'bob123456', amount: 10, fee: 0.1)
      chain.mine_pending_transactions('miner123456', custom_difficulty: 1)
    end

    it 'returns balance for address' do
      get "/api/v1/chain/#{chain.id}/balance/alice123456"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['balance']).to eq(-10.1)
    end
  end
end
```

## Gemfile Updates

```ruby
# Gemfile
gem 'dry-validation', '~> 1.10'  # Transaction validation
```

## Migration Script

**Archivo**: `scripts/migrate_to_structured_transactions.rb`

```ruby
#!/usr/bin/env ruby

require_relative '../config/mongoid'

puts "Migrating to structured transactions..."

Blockchain.all.each do |chain|
  # Create mempool if doesn't exist
  chain.create_mempool unless chain.mempool

  chain.blocks.each do |block|
    block.transactions.map! do |tx|
      # Skip if already structured
      next tx if tx.is_a?(Hash) && tx['from'] && tx['to']

      # Convert old format to structured
      {
        from: 'LEGACY',
        to: 'LEGACY',
        amount: 0,
        data: tx.is_a?(String) ? tx : tx['data'],
        timestamp: block.timestamp,
        fee: 0,
        tx_hash: Digest::SHA256.hexdigest(tx.to_s)
      }
    end

    block.save!
  end

  chain.save!
end

puts "✓ Migration complete"
puts "  - Updated #{Blockchain.count} chains"
```

## OpenAPI Spec Updates

```yaml
paths:
  /chain/{chainId}/transaction:
    post:
      summary: Add transaction to mempool
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TransactionRequest'

  /chain/{chainId}/mine:
    post:
      summary: Mine pending transactions
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                miner_address:
                  type: string
                difficulty:
                  type: integer

  /chain/{chainId}/mempool:
    get:
      summary: Get mempool status

  /chain/{chainId}/balance/{address}:
    get:
      summary: Get balance for address

components:
  schemas:
    TransactionRequest:
      type: object
      required: [from, to, amount]
      properties:
        from:
          type: string
          minLength: 10
        to:
          type: string
          minLength: 10
        amount:
          type: number
          minimum: 0
        fee:
          type: number
          minimum: 0
        data:
          type: string
```

## Criterios de Aceptación

- [ ] Transaction model implementado con validaciones
- [ ] Mempool funciona correctamente
- [ ] POST /api/v1/chain/:id/transaction agrega tx a mempool
- [ ] POST /api/v1/chain/:id/mine mina pending transactions
- [ ] Coinbase transaction (mining reward) se agrega correctamente
- [ ] Balance calculation funciona
- [ ] Transaction history funciona
- [ ] Tests completos (>90% coverage)
- [ ] Migration script funciona
- [ ] OpenAPI spec actualizado
- [ ] Backward compatibility mantenida

## Educational Value

Este task enseña:
1. **Transaction model** - Estructura de transactions en blockchain real
2. **Mempool** - Pool de transactions pendientes (Bitcoin/Ethereum)
3. **Coinbase transaction** - Mining rewards
4. **Transaction fees** - Incentivos para miners
5. **Balance tracking** - UTXO vs Account model (simplified)
6. **Transaction validation** - Dry-validation patterns

## Referencias

- [Bitcoin Transaction Structure](https://en.bitcoin.it/wiki/Transaction)
- [Ethereum Transactions](https://ethereum.org/en/developers/docs/transactions/)
- [Mempool Explained](https://academy.binance.com/en/glossary/mempool)
- [Mining Rewards](https://en.bitcoin.it/wiki/Mining)
