# Task 07: Merkle Tree Implementation

**PR**: #15
**Fase**: 3 - Blockchain Avanzado
**Complejidad**: Medium
**Estimación**: 6-7 días
**Prioridad**: P1
**Dependencias**: Task 08 (recommended) - works better with structured transactions

## Objetivo

Implementar Merkle trees para organizar múltiples transactions en un block de forma eficiente, permitiendo proofs de inclusión sin transferir todo el block.

## Motivación

**Problema actual**: Blocks contienen un solo string de `data`. En blockchains reales, cada block contiene cientos/miles de transactions.

**Solución**: Merkle trees permiten:
1. Agrupar múltiples transactions en un solo hash (merkle root)
2. Probar que una transaction está en un block sin enviar todas las transactions (SPV - Simplified Payment Verification)
3. Estructura de datos fundamental en Bitcoin, Ethereum, etc.

**Educational value**: Core data structure en blockchain. Enseña cómo Bitcoin permite light clients.

## Conceptos Clave

### Merkle Tree Structure

```
                 Root Hash (goes in block header)
                      |
           +----------+----------+
           |                     |
        H(H0+H1)              H(H2+H3)
           |                     |
      +----+----+           +----+----+
      |         |           |         |
     H0        H1          H2        H3
     |         |           |         |
    TX0       TX1         TX2       TX3
```

### Merkle Proof (Inclusión)

Para probar que TX1 está en el block, solo necesito:
- TX1 itself
- H0 (sibling)
- H(H2+H3) (uncle)
- Root hash

Verificar: `H(H(H0+H(TX1)) + H(H2+H3)) == Root`

## Cambios Técnicos

### 1. Merkle Tree Library

**Archivo**: `lib/merkle_tree.rb`

```ruby
require 'digest'

module ChainForge
  class MerkleTree
    attr_reader :leaves, :root

    def initialize(data_array)
      @leaves = data_array.map { |data| hash_data(data) }
      @root = build_tree(@leaves)
    end

    # Build tree bottom-up
    def build_tree(nodes)
      return nil if nodes.empty?
      return nodes.first if nodes.length == 1

      # If odd number of nodes, duplicate last one
      nodes = nodes.dup
      nodes << nodes.last if nodes.length.odd?

      # Build parent level
      parents = []
      nodes.each_slice(2) do |left, right|
        parents << hash_pair(left, right)
      end

      # Recurse up
      build_tree(parents)
    end

    # Generate proof for data at index
    def proof(index)
      return nil if index >= @leaves.length

      proof_hashes = []
      nodes = @leaves.dup
      current_index = index

      # Traverse up the tree
      while nodes.length > 1
        # Duplicate last if odd
        nodes << nodes.last if nodes.length.odd?

        # Find sibling
        if current_index.even?
          sibling_index = current_index + 1
        else
          sibling_index = current_index - 1
        end

        proof_hashes << {
          hash: nodes[sibling_index],
          position: current_index.even? ? :right : :left
        }

        # Build parent level
        parents = []
        nodes.each_slice(2) do |left, right|
          parents << hash_pair(left, right)
        end

        nodes = parents
        current_index /= 2
      end

      {
        leaf_index: index,
        leaf_hash: @leaves[index],
        proof: proof_hashes,
        root: @root
      }
    end

    # Verify proof
    def self.verify_proof(leaf_data, proof, root)
      current_hash = hash_data(leaf_data)

      proof[:proof].each do |step|
        if step[:position] == :right
          current_hash = hash_pair(current_hash, step[:hash])
        else
          current_hash = hash_pair(step[:hash], current_hash)
        end
      end

      current_hash == root
    end

    private

    def hash_data(data)
      case data
      when String
        Digest::SHA256.hexdigest(data)
      when Hash
        Digest::SHA256.hexdigest(data.to_json)
      else
        Digest::SHA256.hexdigest(data.to_s)
      end
    end

    def hash_pair(left, right)
      Digest::SHA256.hexdigest(left + right)
    end

    def self.hash_data(data)
      case data
      when String
        Digest::SHA256.hexdigest(data)
      when Hash
        Digest::SHA256.hexdigest(data.to_json)
      else
        Digest::SHA256.hexdigest(data.to_s)
      end
    end

    def self.hash_pair(left, right)
      Digest::SHA256.hexdigest(left + right)
    end
  end
end
```

### 2. Actualizar Block Model

**Archivo**: `src/models/block.rb`

```ruby
require_relative '../../lib/merkle_tree'

class Block
  include Mongoid::Document
  include Mongoid::Timestamps

  field :index, type: Integer
  field :transactions, type: Array, default: []  # CHANGED from :data
  field :merkle_root, type: String  # NEW
  field :hash, type: String
  field :previous_hash, type: String
  field :nonce, type: Integer, default: 0
  field :difficulty, type: Integer, default: 2
  field :timestamp, type: Integer
  field :mining_duration, type: Float

  embedded_in :blockchain

  validates :index, presence: true
  validates :transactions, presence: true
  validate :transactions_not_empty

  # Backward compatibility: allow single data string
  attr_accessor :data

  before_validation :convert_data_to_transactions
  before_save :calculate_merkle_root

  def mine_block
    @mining_started_at = Time.now

    self.nonce = 0
    self.timestamp = Time.now.to_i
    self.merkle_root = calculate_merkle_root
    target = '0' * difficulty

    until hash.start_with?(target)
      self.nonce += 1
      self.hash = calculate_hash
    end

    self.mining_duration = Time.now - @mining_started_at

    LOGGER.info "Block mined",
      index: index,
      nonce: nonce,
      difficulty: difficulty,
      transactions_count: transactions.length,
      merkle_root: merkle_root[0..15],
      mining_duration: mining_duration
  end

  def calculate_hash
    # Hash includes merkle root instead of individual transactions
    content = "#{index}#{merkle_root}#{previous_hash}#{nonce}#{difficulty}#{timestamp}"
    Digest::SHA256.hexdigest(content)
  end

  def calculate_merkle_root
    return Digest::SHA256.hexdigest('') if transactions.empty?

    tree = ChainForge::MerkleTree.new(transactions)
    self.merkle_root = tree.root
  end

  def merkle_tree
    @merkle_tree ||= ChainForge::MerkleTree.new(transactions)
  end

  # Generate proof for transaction at index
  def merkle_proof(tx_index)
    merkle_tree.proof(tx_index)
  end

  # Verify a transaction is in this block
  def verify_transaction(tx_data, proof)
    ChainForge::MerkleTree.verify_proof(tx_data, proof, merkle_root)
  end

  def valid_hash?
    hash.start_with?('0' * difficulty) && hash == calculate_hash
  end

  def valid_merkle_root?
    calculate_merkle_root == merkle_root
  end

  private

  def transactions_not_empty
    errors.add(:transactions, "must have at least one transaction") if transactions.empty?
  end

  def convert_data_to_transactions
    # Backward compatibility: convert old data string to transaction
    if @data && transactions.empty?
      self.transactions = [{ data: @data, timestamp: Time.now.to_i }]
    end
  end
end
```

### 3. Actualizar Blockchain Model

**Archivo**: `src/models/blockchain.rb`

```ruby
class Blockchain
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :blocks

  field :current_difficulty, type: Integer, default: 2
  field :last_adjustment_at, type: Integer

  validates :blocks, presence: true

  def initialize(attributes = {})
    super
    self.current_difficulty ||= 2
    self.last_adjustment_at ||= 0
    create_genesis_block if blocks.empty?
  end

  # Updated to accept transactions array
  def add_block(transactions, custom_difficulty: nil)
    # Support both array and single transaction/string
    transactions = Array(transactions)

    previous_block = blocks.last
    new_index = previous_block.index + 1

    difficulty = custom_difficulty || calculate_next_difficulty(new_index)

    new_block = blocks.build(
      index: new_index,
      transactions: transactions,
      previous_hash: previous_block.hash,
      difficulty: difficulty
    )

    new_block.mine_block
    save!

    self.current_difficulty = difficulty if should_adjust?(new_index)

    LOGGER.info "Block added to chain",
      chain_id: id.to_s,
      block_index: new_index,
      transactions_count: transactions.length,
      difficulty: difficulty

    new_block
  end

  def valid_chain?
    blocks.each_cons(2) do |prev_block, current_block|
      # Validate hash
      return false unless current_block.valid_hash?

      # Validate merkle root
      return false unless current_block.valid_merkle_root?

      # Validate chain link
      return false unless current_block.previous_hash == prev_block.hash

      # Validate index sequence
      return false unless current_block.index == prev_block.index + 1
    end
    true
  end

  # Search for transaction across all blocks
  def find_transaction(tx_data)
    blocks.each do |block|
      block.transactions.each_with_index do |tx, index|
        if tx == tx_data || tx[:data] == tx_data
          return {
            block_index: block.index,
            block_hash: block.hash,
            tx_index: index,
            tx: tx,
            proof: block.merkle_proof(index)
          }
        end
      end
    end
    nil
  end

  private

  def create_genesis_block
    genesis = blocks.build(
      index: 0,
      transactions: [{ data: 'Genesis Block', timestamp: Time.now.to_i }],
      previous_hash: '0',
      difficulty: current_difficulty
    )
    genesis.mine_block
  end

  def should_adjust?(block_index)
    block_index > 0 && (block_index % ChainForge::DifficultyConfig::ADJUSTMENT_INTERVAL).zero?
  end

  # ... calculate_next_difficulty from Task 06 ...
end
```

### 4. API Endpoints

**Archivo**: `main.rb`

```ruby
# Mine block with multiple transactions
post '/api/v1/chain/:id/block' do
  content_type :json

  # Validate transactions
  transactions = params[:transactions] || [params]
  transactions = Array(transactions)

  halt 400, { error: 'At least one transaction required' }.to_json if transactions.empty?

  # Validate each transaction has data
  transactions.each_with_index do |tx, i|
    tx_data = tx.is_a?(Hash) ? tx[:data] || tx['data'] : tx
    halt 400, { error: "Transaction #{i} missing data" }.to_json unless tx_data
  end

  chain = Blockchain.find(params[:id])
  new_block = chain.add_block(
    transactions,
    custom_difficulty: params[:difficulty]&.to_i
  )

  {
    chain_id: chain.id.to_s,
    block_id: new_block.id.to_s,
    block_hash: new_block.hash,
    merkle_root: new_block.merkle_root,
    transactions_count: new_block.transactions.length,
    nonce: new_block.nonce,
    difficulty: new_block.difficulty,
    mining_duration: new_block.mining_duration.round(2)
  }.to_json
end

# Get block with transactions
get '/api/v1/chain/:id/block/:block_id' do
  content_type :json

  chain = Blockchain.find(params[:id])
  block = chain.blocks.find(params[:block_id])

  {
    chain_id: chain.id.to_s,
    block: {
      id: block.id.to_s,
      index: block.index,
      transactions: block.transactions,
      transaction_count: block.transactions.length,
      merkle_root: block.merkle_root,
      hash: block.hash,
      previous_hash: block.previous_hash,
      nonce: block.nonce,
      difficulty: block.difficulty,
      timestamp: block.timestamp,
      valid_hash: block.valid_hash?,
      valid_merkle: block.valid_merkle_root?
    }
  }.to_json
end

# Get merkle proof for transaction
get '/api/v1/chain/:id/block/:block_id/transaction/:tx_index/proof' do
  content_type :json

  chain = Blockchain.find(params[:id])
  block = chain.blocks.find(params[:block_id])
  tx_index = params[:tx_index].to_i

  halt 400, { error: 'Invalid transaction index' }.to_json if tx_index >= block.transactions.length

  proof = block.merkle_proof(tx_index)

  {
    block_id: block.id.to_s,
    block_hash: block.hash,
    merkle_root: block.merkle_root,
    transaction_index: tx_index,
    transaction: block.transactions[tx_index],
    proof: proof
  }.to_json
end

# Verify merkle proof
post '/api/v1/chain/:id/block/:block_id/verify_proof' do
  content_type :json

  # Validate input
  required_params = %w[transaction proof]
  missing = required_params.reject { |p| params[p] }
  halt 400, { error: "Missing required parameters: #{missing.join(', ')}" }.to_json unless missing.empty?

  chain = Blockchain.find(params[:id])
  block = chain.blocks.find(params[:block_id])

  tx_data = params[:transaction]
  proof = JSON.parse(params[:proof], symbolize_names: true)

  valid = block.verify_transaction(tx_data, proof)

  {
    block_id: block.id.to_s,
    merkle_root: block.merkle_root,
    valid: valid,
    transaction: tx_data
  }.to_json
end

# Search for transaction across chain
get '/api/v1/chain/:id/transaction/search' do
  content_type :json

  halt 400, { error: 'Query parameter "q" required' }.to_json unless params[:q]

  chain = Blockchain.find(params[:id])
  result = chain.find_transaction(params[:q])

  if result
    result.merge(found: true).to_json
  else
    { found: false, query: params[:q] }.to_json
  end
end
```

## Tests

**Archivo**: `spec/lib/merkle_tree_spec.rb`

```ruby
require 'spec_helper'
require_relative '../../lib/merkle_tree'

RSpec.describe ChainForge::MerkleTree do
  describe '#initialize and build_tree' do
    it 'builds tree with power of 2 leaves' do
      tree = ChainForge::MerkleTree.new(['A', 'B', 'C', 'D'])

      expect(tree.leaves.length).to eq(4)
      expect(tree.root).to be_a(String)
      expect(tree.root.length).to eq(64)  # SHA256 hex length
    end

    it 'builds tree with odd number of leaves' do
      tree = ChainForge::MerkleTree.new(['A', 'B', 'C'])

      expect(tree.leaves.length).to eq(3)
      expect(tree.root).to be_a(String)
    end

    it 'builds tree with single leaf' do
      tree = ChainForge::MerkleTree.new(['A'])

      expect(tree.root).to eq(tree.leaves.first)
    end

    it 'builds deterministic tree' do
      tree1 = ChainForge::MerkleTree.new(['A', 'B', 'C'])
      tree2 = ChainForge::MerkleTree.new(['A', 'B', 'C'])

      expect(tree1.root).to eq(tree2.root)
    end

    it 'produces different root for different data' do
      tree1 = ChainForge::MerkleTree.new(['A', 'B', 'C'])
      tree2 = ChainForge::MerkleTree.new(['A', 'B', 'D'])

      expect(tree1.root).not_to eq(tree2.root)
    end
  end

  describe '#proof' do
    let(:tree) { ChainForge::MerkleTree.new(['TX0', 'TX1', 'TX2', 'TX3']) }

    it 'generates proof for first transaction' do
      proof = tree.proof(0)

      expect(proof[:leaf_index]).to eq(0)
      expect(proof[:proof]).to be_an(Array)
      expect(proof[:proof].length).to eq(2)  # log2(4) = 2 levels
      expect(proof[:root]).to eq(tree.root)
    end

    it 'generates proof for middle transaction' do
      proof = tree.proof(1)

      expect(proof[:leaf_index]).to eq(1)
      expect(proof[:proof].all? { |p| p[:hash] && p[:position] }).to be true
    end

    it 'returns nil for invalid index' do
      proof = tree.proof(10)
      expect(proof).to be_nil
    end
  end

  describe '.verify_proof' do
    let(:tree) { ChainForge::MerkleTree.new(['TX0', 'TX1', 'TX2', 'TX3']) }

    it 'verifies valid proof' do
      proof = tree.proof(1)
      valid = ChainForge::MerkleTree.verify_proof('TX1', proof, tree.root)

      expect(valid).to be true
    end

    it 'rejects invalid proof with wrong data' do
      proof = tree.proof(1)
      valid = ChainForge::MerkleTree.verify_proof('WRONG', proof, tree.root)

      expect(valid).to be false
    end

    it 'rejects tampered proof' do
      proof = tree.proof(1)
      proof[:proof].first[:hash] = 'tampered_hash'
      valid = ChainForge::MerkleTree.verify_proof('TX1', proof, tree.root)

      expect(valid).to be false
    end
  end

  describe 'integration with hash objects' do
    it 'works with transaction hashes' do
      transactions = [
        { from: 'Alice', to: 'Bob', amount: 10 },
        { from: 'Bob', to: 'Charlie', amount: 5 }
      ]

      tree = ChainForge::MerkleTree.new(transactions)
      proof = tree.proof(0)

      valid = ChainForge::MerkleTree.verify_proof(
        transactions[0],
        proof,
        tree.root
      )

      expect(valid).to be true
    end
  end
end
```

**Archivo**: `spec/models/block_merkle_spec.rb`

```ruby
RSpec.describe 'Block with Merkle Trees' do
  let(:chain) { Blockchain.create }

  describe 'merkle_root calculation' do
    it 'calculates merkle root for multiple transactions' do
      block = chain.add_block([
        { data: 'TX1', amount: 10 },
        { data: 'TX2', amount: 20 },
        { data: 'TX3', amount: 30 }
      ], custom_difficulty: 1)

      expect(block.merkle_root).to be_present
      expect(block.merkle_root.length).to eq(64)
    end

    it 'includes merkle root in hash calculation' do
      block = chain.add_block([{ data: 'TX1' }], custom_difficulty: 1)

      # Changing merkle root should invalidate hash
      old_hash = block.hash
      block.merkle_root = 'different_root'
      block.hash = block.calculate_hash

      expect(block.hash).not_to eq(old_hash)
    end

    it 'validates merkle root matches transactions' do
      block = chain.blocks.last
      expect(block.valid_merkle_root?).to be true

      # Tamper with transactions
      block.transactions << { data: 'Fake TX' }
      expect(block.valid_merkle_root?).to be false
    end
  end

  describe '#merkle_proof' do
    it 'generates proof for transaction in block' do
      block = chain.add_block([
        'TX0', 'TX1', 'TX2', 'TX3'
      ], custom_difficulty: 1)

      proof = block.merkle_proof(1)

      expect(proof[:leaf_index]).to eq(1)
      expect(proof[:root]).to eq(block.merkle_root)
      expect(proof[:proof]).to be_an(Array)
    end
  end

  describe '#verify_transaction' do
    it 'verifies transaction is in block' do
      transactions = ['TX0', 'TX1', 'TX2']
      block = chain.add_block(transactions, custom_difficulty: 1)

      proof = block.merkle_proof(1)
      valid = block.verify_transaction('TX1', proof)

      expect(valid).to be true
    end

    it 'rejects transaction not in block' do
      transactions = ['TX0', 'TX1', 'TX2']
      block = chain.add_block(transactions, custom_difficulty: 1)

      proof = block.merkle_proof(1)
      valid = block.verify_transaction('FAKE', proof)

      expect(valid).to be false
    end
  end

  describe 'backward compatibility' do
    it 'accepts single data string' do
      block = chain.blocks.build(
        index: 1,
        data: 'Old style data',
        previous_hash: chain.blocks.last.hash,
        difficulty: 2
      )

      expect { block.save! }.not_to raise_error
      expect(block.transactions.length).to eq(1)
      expect(block.transactions.first[:data]).to eq('Old style data')
    end
  end
end
```

**Archivo**: `spec/api/merkle_spec.rb`

```ruby
RSpec.describe 'Merkle API' do
  let!(:chain) { Blockchain.create }
  let!(:block) do
    chain.add_block([
      { data: 'TX0', amount: 10 },
      { data: 'TX1', amount: 20 },
      { data: 'TX2', amount: 30 }
    ], custom_difficulty: 1)
  end

  describe 'POST /api/v1/chain/:id/block with transactions' do
    it 'accepts array of transactions' do
      post "/api/v1/chain/#{chain.id}/block", {
        transactions: [
          { data: 'Payment 1', amount: 100 },
          { data: 'Payment 2', amount: 200 }
        ]
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['transactions_count']).to eq(2)
      expect(data['merkle_root']).to be_present
    end

    it 'accepts single transaction for backward compatibility' do
      post "/api/v1/chain/#{chain.id}/block", { data: 'Single TX' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['transactions_count']).to eq(1)
    end
  end

  describe 'GET /api/v1/chain/:id/block/:block_id/transaction/:tx_index/proof' do
    it 'returns merkle proof for transaction' do
      get "/api/v1/chain/#{chain.id}/block/#{block.id}/transaction/1/proof"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['transaction_index']).to eq(1)
      expect(data['proof']).to be_present
      expect(data['merkle_root']).to eq(block.merkle_root)
    end

    it 'returns 400 for invalid index' do
      get "/api/v1/chain/#{chain.id}/block/#{block.id}/transaction/999/proof"

      expect(last_response.status).to eq(400)
    end
  end

  describe 'POST /api/v1/chain/:id/block/:block_id/verify_proof' do
    let(:proof) { block.merkle_proof(1) }

    it 'verifies valid proof' do
      post "/api/v1/chain/#{chain.id}/block/#{block.id}/verify_proof", {
        transaction: block.transactions[1],
        proof: proof.to_json
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['valid']).to be true
    end

    it 'rejects invalid proof' do
      post "/api/v1/chain/#{chain.id}/block/#{block.id}/verify_proof", {
        transaction: { data: 'FAKE' },
        proof: proof.to_json
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['valid']).to be false
    end
  end

  describe 'GET /api/v1/chain/:id/transaction/search' do
    it 'finds transaction across blocks' do
      get "/api/v1/chain/#{chain.id}/transaction/search?q=TX1"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['found']).to be true
      expect(data['block_index']).to eq(block.index)
      expect(data['proof']).to be_present
    end

    it 'returns not found for missing transaction' do
      get "/api/v1/chain/#{chain.id}/transaction/search?q=NONEXISTENT"

      data = JSON.parse(last_response.body)
      expect(data['found']).to be false
    end
  end
end
```

## Migration Script

**Archivo**: `scripts/migrate_to_merkle_trees.rb`

```ruby
#!/usr/bin/env ruby

require_relative '../config/mongoid'

puts "Migrating blocks to use Merkle trees..."

migrated_count = 0
error_count = 0

Blockchain.all.each do |chain|
  chain.blocks.each do |block|
    begin
      # Skip if already has transactions array
      next if block.transactions.is_a?(Array) && !block.transactions.empty?

      # Convert old 'data' field to transactions array
      if block['data'].present?
        block.transactions = [{ data: block['data'], timestamp: block.timestamp }]
        block.unset(:data)  # Remove old field
      elsif block.transactions.empty?
        block.transactions = [{ data: 'Legacy block', timestamp: block.timestamp }]
      end

      # Recalculate merkle root
      block.merkle_root = block.calculate_merkle_root

      # Recalculate hash (since it now includes merkle_root)
      # Note: This will break the chain! Only for development/testing
      # In production, you'd need a more sophisticated migration
      block.hash = block.calculate_hash

      block.save!
      migrated_count += 1
    rescue => e
      puts "Error migrating block #{block.id}: #{e.message}"
      error_count += 1
    end
  end
end

puts "\n✓ Migration complete"
puts "  - Migrated: #{migrated_count} blocks"
puts "  - Errors: #{error_count} blocks"
puts "\n⚠️  WARNING: Block hashes have changed. This breaks chain validation."
puts "   Only use this migration for development/testing environments."
puts "   In production, consider creating a new chain with the updated structure."
```

## OpenAPI Spec Updates

```yaml
paths:
  /chain/{chainId}/block:
    post:
      summary: Mine a new block with transactions
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                transactions:
                  type: array
                  items:
                    type: object
                    properties:
                      data:
                        type: string
                difficulty:
                  type: integer

  /chain/{chainId}/block/{blockId}/transaction/{txIndex}/proof:
    get:
      summary: Get Merkle proof for transaction
      parameters:
        - name: txIndex
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Merkle proof
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MerkleProofResponse'

  /chain/{chainId}/block/{blockId}/verify_proof:
    post:
      summary: Verify Merkle proof
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                transaction:
                  type: object
                proof:
                  type: string

components:
  schemas:
    BlockDetailResponse:
      properties:
        merkle_root:
          type: string
        transactions:
          type: array
          items:
            type: object
        transaction_count:
          type: integer

    MerkleProofResponse:
      type: object
      properties:
        block_id:
          type: string
        merkle_root:
          type: string
        transaction_index:
          type: integer
        transaction:
          type: object
        proof:
          type: object
```

## Educational Value

Este task enseña:

1. **Merkle Trees** - Estructura de datos fundamental en blockchain
2. **Simplified Payment Verification (SPV)** - Cómo Bitcoin permite light wallets
3. **Cryptographic Proofs** - Probar inclusión sin revelar todo el dataset
4. **Tree Algorithms** - Construcción bottom-up, traversal
5. **Hash Chaining** - Combining hashes securely

## Comparación con Bitcoin

| Aspecto | Bitcoin | ChainForge Private |
|---------|---------|---------------------|
| Transactions per block | ~2000-3000 | Ilimitado (configurable) |
| Merkle tree depth | ~11-12 levels | Depends on tx count |
| Proof size | ~400 bytes | Similar |
| Use case | SPV wallets, light clients | Educational |

## Criterios de Aceptación

- [ ] `MerkleTree` class implementada y testeada
- [ ] Block usa `transactions` array en lugar de `data` string
- [ ] Block calcula `merkle_root` correctamente
- [ ] `Block#merkle_proof(index)` genera proofs válidos
- [ ] `Block#verify_transaction` valida proofs
- [ ] API endpoints para proofs funcionan
- [ ] Tests completos (>90% coverage)
- [ ] Backward compatibility con blocks existentes
- [ ] Migration script funciona
- [ ] OpenAPI spec actualizado
- [ ] Documentación explicando Merkle trees
- [ ] `Blockchain#valid_chain?` valida merkle roots

## Breaking Changes

**IMPORTANTE**: Este cambio es backward-incompatible:
- Blocks ahora usan `transactions:` en lugar de `data:`
- Hash calculation incluye `merkle_root`
- Chains existentes necesitarán migración o recreación

**Recomendación**: Para producción, crear nueva chain con la estructura actualizada en lugar de migrar.

## Referencias

- [Bitcoin Merkle Trees](https://en.bitcoin.it/wiki/Protocol_documentation#Merkle_Trees)
- [Merkle Tree Explained](https://brilliant.org/wiki/merkle-tree/)
- [SPV - Simplified Payment Verification](https://bitcoin.org/en/operating-modes-guide#simplified-payment-verification-spv)
- [Merkle Proof Visualization](https://nakamoto.com/merkle-trees/)
