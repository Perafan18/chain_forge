# Task 09: Digital Signatures (Ed25519)

**PR**: #17
**Fase**: 3 - Blockchain Avanzado
**Complejidad**: Medium
**Estimación**: 6-7 días
**Prioridad**: P1
**Dependencias**: Task 08 (Structured Transactions) - works together

## Objetivo

Implementar firma digital de transacciones usando criptografía de clave pública Ed25519 para autenticación y non-repudiation, permitiendo verificar que las transactions fueron creadas por el owner legítimo de los fondos.

## Motivación

**Problema actual**: Cualquiera puede crear una transaction con `from: "alice"` sin prueba de que Alice realmente autorizó la transacción.

**Solución**: Digital signatures con Ed25519 (elliptic curve cryptography):
- Solo el dueño de la private key puede firmar transactions
- Cualquiera puede verificar la signature usando la public key
- Imposible forjar signatures sin la private key

**Educational value**: Concepto fundamental en blockchain. Enseña public-key cryptography, el mismo sistema usado en Bitcoin (ECDSA) y moderno SSH.

## Ed25519 vs ECDSA

| Aspecto | Ed25519 | ECDSA (Bitcoin) |
|---------|---------|-----------------|
| Curve | Curve25519 | secp256k1 |
| Key size | 32 bytes | 32 bytes |
| Signature size | 64 bytes | ~71 bytes (DER) |
| Performance | Faster | Slower |
| Security | High | High |
| Adoption | Modern (SSH, Signal) | Legacy (Bitcoin) |

Usamos Ed25519 por su simplicidad y velocidad para propósitos educativos.

## Cambios Técnicos

### 1. Crypto Library Setup

**Gemfile**:
```ruby
gem 'rbnacl', '~> 7.1'  # Ruby binding for libsodium (Ed25519)
```

**Instalación de libsodium** (dependencia de rbnacl):
```bash
# macOS
brew install libsodium

# Ubuntu/Debian
sudo apt-get install libsodium-dev

# Docker
RUN apt-get update && apt-get install -y libsodium-dev
```

### 2. Keypair Management

**Archivo**: `lib/crypto/keypair.rb`

```ruby
require 'rbnacl'
require 'base64'
require 'json'

module ChainForge
  module Crypto
    class Keypair
      attr_reader :public_key, :private_key

      def initialize(private_key: nil)
        if private_key
          # Load from existing private key
          @private_key = private_key.is_a?(String) ?
            RbNaCl::SigningKey.new(decode_key(private_key)) :
            private_key
        else
          # Generate new keypair
          @private_key = RbNaCl::SigningKey.generate
        end

        @public_key = @private_key.verify_key
      end

      # Sign message
      def sign(message)
        signature = @private_key.sign(message)
        encode_signature(signature)
      end

      # Get public key as hex string (address)
      def address
        encode_key(@public_key.to_bytes)
      end

      # Get private key as hex string (for storage)
      def private_key_hex
        encode_key(@private_key.to_bytes)
      end

      # Export keypair to JSON
      def to_json
        {
          public_key: address,
          private_key: private_key_hex
        }.to_json
      end

      # Load keypair from JSON
      def self.from_json(json_str)
        data = JSON.parse(json_str, symbolize_names: true)
        new(private_key: data[:private_key])
      end

      # Verify signature
      def self.verify(message, signature, public_key_hex)
        public_key = RbNaCl::VerifyKey.new(decode_key(public_key_hex))
        signature_bytes = decode_signature(signature)

        public_key.verify(signature_bytes, message)
        true
      rescue RbNaCl::BadSignatureError, RbNaCl::LengthError
        false
      end

      private

      def encode_key(bytes)
        bytes.unpack1('H*')  # Convert to hex
      end

      def encode_signature(bytes)
        bytes.unpack1('H*')  # Convert to hex
      end

      def self.decode_key(hex)
        [hex].pack('H*')  # Convert from hex
      end

      def self.decode_signature(hex)
        [hex].pack('H*')  # Convert from hex
      end

      def decode_key(hex)
        self.class.decode_key(hex)
      end
    end
  end
end
```

### 3. Wallet Management

**Archivo**: `lib/crypto/wallet.rb`

```ruby
require 'fileutils'
require 'json'
require_relative 'keypair'

module ChainForge
  module Crypto
    class Wallet
      WALLET_DIR = File.expand_path('~/.chainforge')
      WALLET_FILE = File.join(WALLET_DIR, 'wallet.json')

      attr_reader :keypair

      def initialize(keypair = nil)
        @keypair = keypair || Keypair.new
      end

      # Save wallet to disk
      def save!
        FileUtils.mkdir_p(WALLET_DIR)

        # Set restrictive permissions (user read/write only)
        File.write(WALLET_FILE, @keypair.to_json)
        File.chmod(0600, WALLET_FILE)

        LOGGER.info "Wallet saved",
          address: @keypair.address[0..15] + "...",
          path: WALLET_FILE

        true
      end

      # Load wallet from disk
      def self.load
        unless File.exist?(WALLET_FILE)
          raise WalletError, "Wallet not found. Run 'chainforge keygen' first."
        end

        json = File.read(WALLET_FILE)
        keypair = Keypair.from_json(json)
        new(keypair)
      end

      # Check if wallet exists
      def self.exists?
        File.exist?(WALLET_FILE)
      end

      # Delete wallet
      def self.delete!
        return false unless exists?

        File.delete(WALLET_FILE)
        LOGGER.warn "Wallet deleted", path: WALLET_FILE
        true
      end

      # Sign transaction
      def sign_transaction(tx_data)
        # Create message to sign (exclude signature field)
        message = create_signable_message(tx_data)

        signature = @keypair.sign(message)

        tx_data.merge(
          from: @keypair.address,  # Set from address to wallet's public key
          signature: signature
        )
      end

      # Verify transaction signature
      def self.verify_transaction(tx_data)
        message = create_signable_message(tx_data)

        Keypair.verify(
          message,
          tx_data[:signature] || tx_data['signature'],
          tx_data[:from] || tx_data['from']
        )
      end

      private

      def create_signable_message(tx_data)
        self.class.create_signable_message(tx_data)
      end

      def self.create_signable_message(tx_data)
        # Create deterministic message from transaction data
        # Exclude signature itself
        data = {
          from: tx_data[:from] || tx_data['from'],
          to: tx_data[:to] || tx_data['to'],
          amount: tx_data[:amount] || tx_data['amount'],
          fee: tx_data[:fee] || tx_data['fee'] || 0,
          timestamp: tx_data[:timestamp] || tx_data['timestamp'],
          data: tx_data[:data] || tx_data['data']
        }

        # Sort keys for deterministic hashing
        data.to_json
      end
    end

    class WalletError < StandardError; end
  end
end
```

### 4. Actualizar Transaction Model

**Archivo**: `src/models/transaction.rb` (additions)

```ruby
class Transaction
  include Mongoid::Document
  include Mongoid::Timestamps

  # ... existing fields ...

  validates :signature, presence: true, length: { is: 128 }  # 64 bytes hex = 128 chars
  validate :valid_signature

  # Verify signature is valid
  def valid_signature?
    return false unless signature.present? && from.present?

    ChainForge::Crypto::Wallet.verify_transaction(
      as_json.symbolize_keys
    )
  end

  private

  def valid_signature
    unless valid_signature?
      errors.add(:signature, "is invalid or does not match transaction data")
    end
  end
end
```

### 5. Actualizar Mempool

**Archivo**: `src/models/mempool.rb` (additions)

```ruby
class Mempool
  # ... existing code ...

  def add_transaction(tx_data)
    # Validate transaction structure
    tx = Transaction.new(tx_data)

    unless tx.valid?
      raise ValidationError, "Invalid transaction: #{tx.errors.full_messages.join(', ')}"
    end

    # Verify signature
    unless tx.valid_signature?
      raise ValidationError, "Invalid signature"
    end

    # Check sender has sufficient balance (optional but recommended)
    sender_balance = blockchain.balance_of(tx.from)
    required_balance = tx.amount + tx.fee

    if sender_balance < required_balance
      raise ValidationError, "Insufficient balance. Have: #{sender_balance}, Need: #{required_balance}"
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
      amount: tx.amount,
      signature_valid: true

    tx
  end
end
```

### 6. CLI Commands

**Archivo**: `lib/chainforge/cli.rb` (additions)

```ruby
module ChainForge
  class CLI < Thor
    # ... existing commands ...

    desc 'keygen', 'Generate new keypair and save to wallet'
    option :force, type: :boolean, aliases: '-f', desc: 'Overwrite existing wallet'
    def keygen
      if ChainForge::Crypto::Wallet.exists? && !options[:force]
        puts paint.red("✗ Wallet already exists at #{ChainForge::Crypto::Wallet::WALLET_FILE}")
        puts "  Use --force to overwrite"
        exit 1
      end

      wallet = ChainForge::Crypto::Wallet.new
      wallet.save!

      puts paint.green("✓ New wallet created")
      puts ""
      puts "Public Address (share this):"
      puts paint.cyan("  #{wallet.keypair.address}")
      puts ""
      puts "Wallet location:"
      puts "  #{ChainForge::Crypto::Wallet::WALLET_FILE}"
      puts ""
      puts paint.yellow("⚠️  IMPORTANT: Keep your wallet file secure!")
      puts "   Anyone with access to this file can spend your funds."
    end

    desc 'address', 'Show your wallet address'
    def address
      wallet = ChainForge::Crypto::Wallet.load

      puts "Your wallet address:"
      puts paint.cyan(wallet.keypair.address)
    rescue ChainForge::Crypto::WalletError => e
      puts paint.red("✗ #{e.message}")
      exit 1
    end

    desc 'send CHAIN_ID TO AMOUNT', 'Send a transaction'
    option :fee, type: :numeric, default: 0.1, desc: 'Transaction fee'
    option :data, type: :string, desc: 'Optional transaction data/memo'
    def send(chain_id, to_address, amount)
      wallet = ChainForge::Crypto::Wallet.load

      # Create transaction
      tx_data = {
        to: to_address,
        amount: amount.to_f,
        fee: options[:fee],
        data: options[:data],
        timestamp: Time.now.to_i
      }

      # Sign transaction
      signed_tx = wallet.sign_transaction(tx_data)

      # Submit to API
      response = client.add_transaction(chain_id, signed_tx)

      puts paint.green("✓ Transaction sent successfully")
      puts ""
      puts "Transaction Hash: #{response['transaction']['tx_hash']}"
      puts "From:   #{signed_tx[:from][0..15]}..."
      puts "To:     #{to_address[0..15]}..."
      puts "Amount: #{amount}"
      puts "Fee:    #{options[:fee]}"
      puts ""
      puts "Status: Pending (waiting to be mined)"
    rescue ChainForge::Crypto::WalletError => e
      puts paint.red("✗ #{e.message}")
      exit 1
    rescue => e
      puts paint.red("✗ Error: #{e.message}")
      exit 1
    end

    desc 'balance CHAIN_ID [ADDRESS]', 'Get balance for address'
    def balance(chain_id, address = nil)
      # Use wallet address if not specified
      address ||= begin
        wallet = ChainForge::Crypto::Wallet.load
        wallet.keypair.address
      rescue ChainForge::Crypto::WalletError
        puts paint.red("✗ No wallet found and no address specified")
        exit 1
      end

      response = client.get_balance(chain_id, address)

      puts "Balance for #{address[0..15]}...:"
      puts paint.cyan("  #{response['balance']} coins")
    end
  end
end
```

### 7. API Endpoints

**Archivo**: `main.rb` (additions)

```ruby
# Existing POST /api/v1/chain/:id/transaction now requires valid signature
post '/api/v1/chain/:id/transaction' do
  content_type :json

  # Validate input
  validator = ChainForge::TransactionValidator.new
  result = validator.call(params)

  if result.failure?
    halt 400, { errors: result.errors.to_h }.to_json
  end

  # Verify signature
  unless ChainForge::Crypto::Wallet.verify_transaction(params)
    halt 401, { error: 'Invalid signature' }.to_json
  end

  chain = Blockchain.find(params[:id])

  # Add to mempool (will re-verify signature)
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

# New endpoint: Verify signature
post '/api/v1/verify_signature' do
  content_type :json

  required = %w[message signature public_key]
  missing = required.reject { |p| params[p] }
  halt 400, { error: "Missing: #{missing.join(', ')}" }.to_json unless missing.empty?

  valid = ChainForge::Crypto::Keypair.verify(
    params[:message],
    params[:signature],
    params[:public_key]
  )

  {
    valid: valid,
    public_key: params[:public_key],
    message: params[:message][0..50] + (params[:message].length > 50 ? '...' : '')
  }.to_json
end
```

## Tests

**Archivo**: `spec/lib/crypto/keypair_spec.rb`

```ruby
require 'spec_helper'
require_relative '../../../lib/crypto/keypair'

RSpec.describe ChainForge::Crypto::Keypair do
  describe '#initialize' do
    it 'generates new keypair' do
      keypair = ChainForge::Crypto::Keypair.new

      expect(keypair.address).to be_present
      expect(keypair.private_key_hex).to be_present
      expect(keypair.address.length).to eq(64)  # 32 bytes hex
    end

    it 'loads from existing private key' do
      keypair1 = ChainForge::Crypto::Keypair.new
      private_key = keypair1.private_key_hex

      keypair2 = ChainForge::Crypto::Keypair.new(private_key: private_key)

      expect(keypair2.address).to eq(keypair1.address)
    end
  end

  describe '#sign and .verify' do
    let(:keypair) { ChainForge::Crypto::Keypair.new }
    let(:message) { "Hello, blockchain!" }

    it 'signs and verifies message' do
      signature = keypair.sign(message)

      expect(signature).to be_present
      expect(signature.length).to eq(128)  # 64 bytes hex

      valid = ChainForge::Crypto::Keypair.verify(
        message,
        signature,
        keypair.address
      )

      expect(valid).to be true
    end

    it 'rejects tampered message' do
      signature = keypair.sign(message)

      valid = ChainForge::Crypto::Keypair.verify(
        "Tampered message",
        signature,
        keypair.address
      )

      expect(valid).to be false
    end

    it 'rejects tampered signature' do
      signature = keypair.sign(message)
      tampered_signature = signature[0..-3] + 'ff'

      valid = ChainForge::Crypto::Keypair.verify(
        message,
        tampered_signature,
        keypair.address
      )

      expect(valid).to be false
    end

    it 'rejects wrong public key' do
      signature = keypair.sign(message)
      other_keypair = ChainForge::Crypto::Keypair.new

      valid = ChainForge::Crypto::Keypair.verify(
        message,
        signature,
        other_keypair.address
      )

      expect(valid).to be false
    end
  end

  describe 'JSON serialization' do
    it 'exports and imports keypair' do
      keypair1 = ChainForge::Crypto::Keypair.new
      json = keypair1.to_json

      keypair2 = ChainForge::Crypto::Keypair.from_json(json)

      expect(keypair2.address).to eq(keypair1.address)
      expect(keypair2.private_key_hex).to eq(keypair1.private_key_hex)
    end
  end
end
```

**Archivo**: `spec/lib/crypto/wallet_spec.rb`

```ruby
RSpec.describe ChainForge::Crypto::Wallet do
  let(:temp_wallet_file) { '/tmp/test_wallet.json' }

  before do
    # Use temp file for testing
    stub_const('ChainForge::Crypto::Wallet::WALLET_FILE', temp_wallet_file)
  end

  after do
    File.delete(temp_wallet_file) if File.exist?(temp_wallet_file)
  end

  describe '#save! and .load' do
    it 'saves and loads wallet' do
      wallet1 = ChainForge::Crypto::Wallet.new
      wallet1.save!

      expect(File.exist?(temp_wallet_file)).to be true

      wallet2 = ChainForge::Crypto::Wallet.load

      expect(wallet2.keypair.address).to eq(wallet1.keypair.address)
    end

    it 'sets restrictive file permissions' do
      wallet = ChainForge::Crypto::Wallet.new
      wallet.save!

      permissions = File.stat(temp_wallet_file).mode & 0777
      expect(permissions).to eq(0600)
    end

    it 'raises error when loading non-existent wallet' do
      expect {
        ChainForge::Crypto::Wallet.load
      }.to raise_error(ChainForge::Crypto::WalletError)
    end
  end

  describe '#sign_transaction' do
    let(:wallet) { ChainForge::Crypto::Wallet.new }

    it 'signs transaction correctly' do
      tx_data = {
        to: 'recipient_address_1234567890',
        amount: 10.0,
        fee: 0.1,
        timestamp: Time.now.to_i
      }

      signed_tx = wallet.sign_transaction(tx_data)

      expect(signed_tx[:from]).to eq(wallet.keypair.address)
      expect(signed_tx[:signature]).to be_present
      expect(signed_tx[:signature].length).to eq(128)
    end
  end

  describe '.verify_transaction' do
    let(:wallet) { ChainForge::Crypto::Wallet.new }

    it 'verifies valid transaction' do
      tx_data = {
        to: 'recipient_address_1234567890',
        amount: 10.0,
        fee: 0.1,
        timestamp: 1234567890
      }

      signed_tx = wallet.sign_transaction(tx_data)

      valid = ChainForge::Crypto::Wallet.verify_transaction(signed_tx)
      expect(valid).to be true
    end

    it 'rejects tampered transaction' do
      tx_data = {
        to: 'recipient_address_1234567890',
        amount: 10.0,
        fee: 0.1,
        timestamp: 1234567890
      }

      signed_tx = wallet.sign_transaction(tx_data)

      # Tamper with amount
      signed_tx[:amount] = 1000.0

      valid = ChainForge::Crypto::Wallet.verify_transaction(signed_tx)
      expect(valid).to be false
    end
  end
end
```

**Archivo**: `spec/models/transaction_signature_spec.rb`

```ruby
RSpec.describe 'Transaction with Signatures' do
  let(:chain) { Blockchain.create }
  let(:wallet) { ChainForge::Crypto::Wallet.new }

  describe 'signature validation' do
    it 'accepts transaction with valid signature' do
      tx_data = wallet.sign_transaction(
        to: 'recipient_address_1234567890',
        amount: 10.0,
        fee: 0.1,
        timestamp: Time.now.to_i
      )

      expect {
        chain.mempool.add_transaction(tx_data)
      }.not_to raise_error

      expect(chain.mempool.pending_transactions.length).to eq(1)
    end

    it 'rejects transaction with invalid signature' do
      tx_data = wallet.sign_transaction(
        to: 'recipient_address_1234567890',
        amount: 10.0,
        fee: 0.1,
        timestamp: Time.now.to_i
      )

      # Tamper with signature
      tx_data[:signature] = 'f' * 128

      expect {
        chain.mempool.add_transaction(tx_data)
      }.to raise_error(ValidationError, /Invalid signature/)
    end

    it 'rejects transaction with missing signature' do
      tx_data = {
        from: wallet.keypair.address,
        to: 'recipient_address_1234567890',
        amount: 10.0,
        fee: 0.1,
        timestamp: Time.now.to_i
      }

      expect {
        chain.mempool.add_transaction(tx_data)
      }.to raise_error(ValidationError)
    end
  end

  describe 'insufficient balance' do
    it 'rejects transaction when sender has insufficient balance' do
      tx_data = wallet.sign_transaction(
        to: 'recipient_address_1234567890',
        amount: 1000.0,  # More than balance
        fee: 0.1,
        timestamp: Time.now.to_i
      )

      expect {
        chain.mempool.add_transaction(tx_data)
      }.to raise_error(ValidationError, /Insufficient balance/)
    end
  end
end
```

**Archivo**: `spec/api/signatures_spec.rb`

```ruby
RSpec.describe 'Signatures API' do
  let!(:chain) { Blockchain.create }
  let(:wallet) { ChainForge::Crypto::Wallet.new }

  describe 'POST /api/v1/chain/:id/transaction with signature' do
    it 'accepts transaction with valid signature' do
      tx_data = wallet.sign_transaction(
        to: 'recipient_address_1234567890',
        amount: 10.0,
        fee: 0.1,
        timestamp: Time.now.to_i
      )

      # Give sender some initial balance
      chain.mempool.add_transaction(
        from: 'COINBASE',
        to: wallet.keypair.address,
        amount: 100,
        fee: 0,
        timestamp: Time.now.to_i,
        signature: '0' * 128  # Coinbase doesn't need valid signature
      )
      chain.mine_pending_transactions('miner', custom_difficulty: 1)

      post "/api/v1/chain/#{chain.id}/transaction", tx_data.to_json,
        { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(201)
    end

    it 'rejects transaction with invalid signature' do
      tx_data = wallet.sign_transaction(
        to: 'recipient_address_1234567890',
        amount: 10.0,
        fee: 0.1,
        timestamp: Time.now.to_i
      )

      tx_data[:signature] = 'invalid'

      post "/api/v1/chain/#{chain.id}/transaction", tx_data.to_json,
        { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(401)
      expect(JSON.parse(last_response.body)['error']).to include('Invalid signature')
    end
  end

  describe 'POST /api/v1/verify_signature' do
    let(:message) { "Test message" }
    let(:signature) { wallet.keypair.sign(message) }

    it 'verifies valid signature' do
      post '/api/v1/verify_signature', {
        message: message,
        signature: signature,
        public_key: wallet.keypair.address
      }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['valid']).to be true
    end

    it 'rejects invalid signature' do
      post '/api/v1/verify_signature', {
        message: "Different message",
        signature: signature,
        public_key: wallet.keypair.address
      }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['valid']).to be false
    end
  end
end
```

## Security Considerations

### 1. Private Key Storage

```ruby
# ✓ GOOD: Restrictive permissions
File.chmod(0600, wallet_file)  # Only user can read/write

# ✗ BAD: World-readable
File.chmod(0644, wallet_file)  # Anyone can read private key!
```

### 2. Never Log Private Keys

```ruby
# ✓ GOOD: Log only public address
LOGGER.info "Wallet created", address: keypair.address[0..15] + "..."

# ✗ BAD: Logging private key
LOGGER.info "Private key: #{keypair.private_key_hex}"  # NEVER DO THIS!
```

### 3. Signature Replay Protection

```ruby
# Include timestamp in signed message
tx_data = {
  from: from,
  to: to,
  amount: amount,
  timestamp: Time.now.to_i,  # ✓ Makes each signature unique
  nonce: generate_nonce       # ✓ Even better: use nonce
}
```

## CLI Usage Examples

```bash
# Generate new wallet
$ chainforge keygen
✓ New wallet created

Public Address (share this):
  a4f3c8d9e2b1f7a6c5d4e3f2a1b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1

Wallet location:
  /Users/user/.chainforge/wallet.json

⚠️  IMPORTANT: Keep your wallet file secure!

# Show address
$ chainforge address
Your wallet address:
a4f3c8d9e2b1f7a6c5d4e3f2a1b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1

# Send transaction
$ chainforge send 507f1f77bcf86cd799439011 b4f3c8d9e2b1f7a6... 10 --fee 0.1
✓ Transaction sent successfully

Transaction Hash: 89a7b6c5d4e3f2a1...
From:   a4f3c8d9e2b1f7a6...
To:     b4f3c8d9e2b1f7a6...
Amount: 10.0
Fee:    0.1

Status: Pending (waiting to be mined)

# Check balance
$ chainforge balance 507f1f77bcf86cd799439011
Balance for a4f3c8d9e2b1f7a6...:
  89.9 coins
```

## OpenAPI Spec Updates

```yaml
paths:
  /chain/{chainId}/transaction:
    post:
      summary: Add signed transaction to mempool
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [from, to, amount, signature]
              properties:
                from:
                  type: string
                  description: Public key (address) of sender
                  pattern: '^[0-9a-f]{64}$'
                to:
                  type: string
                  pattern: '^[0-9a-f]{64}$'
                amount:
                  type: number
                fee:
                  type: number
                signature:
                  type: string
                  description: Ed25519 signature (hex)
                  pattern: '^[0-9a-f]{128}$'

  /verify_signature:
    post:
      summary: Verify Ed25519 signature
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [message, signature, public_key]
              properties:
                message:
                  type: string
                signature:
                  type: string
                  pattern: '^[0-9a-f]{128}$'
                public_key:
                  type: string
                  pattern: '^[0-9a-f]{64}$'
      responses:
        '200':
          description: Signature verification result
          content:
            application/json:
              schema:
                type: object
                properties:
                  valid:
                    type: boolean
```

## Criterios de Aceptación

- [ ] Keypair generation implementado con Ed25519
- [ ] Wallet save/load funciona con permisos seguros (0600)
- [ ] Transaction signing funciona correctamente
- [ ] Signature verification funciona
- [ ] CLI commands: keygen, address, send implementados
- [ ] Mempool rechaza transactions con signatures inválidos
- [ ] Mempool verifica balance suficiente antes de aceptar tx
- [ ] API endpoint POST /api/v1/verify_signature funciona
- [ ] Tests completos (>90% coverage)
- [ ] Security: private keys nunca se loggean
- [ ] OpenAPI spec actualizado
- [ ] Documentación sobre cryptography

## Educational Value

Este task enseña:
1. **Public-key cryptography** - Fundamento de la seguridad blockchain
2. **Digital signatures** - Non-repudiation y autenticación
3. **Ed25519** - Cryptografía de curva elíptica moderna
4. **Key management** - Secure storage de private keys
5. **Signature verification** - Cómo validar identidad sin secrets
6. **Security best practices** - File permissions, no logging secrets

## Referencias

- [Ed25519 High-Speed Signatures](https://ed25519.cr.yp.to/)
- [RbNaCl Documentation](https://github.com/RubyCrypto/rbnacl)
- [libsodium](https://libsodium.gitbook.io/)
- [Bitcoin ECDSA](https://en.bitcoin.it/wiki/Elliptic_Curve_Digital_Signature_Algorithm)
- [Public-key Cryptography](https://en.wikipedia.org/wiki/Public-key_cryptography)
