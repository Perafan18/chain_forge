# Data Models

Comprehensive documentation of ChainForge's data models, MongoDB schema, and relationships.

## Table of Contents

1. [Overview](#overview)
2. [Blockchain Model](#blockchain-model)
3. [Block Model](#block-model)
4. [Model Relationships](#model-relationships)
5. [MongoDB Schema](#mongodb-schema)
6. [Lifecycle and Callbacks](#lifecycle-and-callbacks)
7. [Validation Rules](#validation-rules)
8. [Querying Patterns](#querying-patterns)

## Overview

ChainForge uses **Mongoid 7.0.5** as its Object-Document Mapper (ODM) to interact with MongoDB. The data model consists of two primary entities:

- **Blockchain**: Parent model representing a blockchain instance
- **Block**: Child model representing individual blocks in the chain

**Relationship:** One-to-Many (Blockchain has many Blocks)

## Blockchain Model

### Source Location

`src/blockchain.rb`

### Class Definition

```ruby
class Blockchain
  include Mongoid::Document

  has_many :blocks

  after_create :add_genesis_block
end
```

### Attributes

| Field | Type | Description | Auto-Generated |
|-------|------|-------------|---------------|
| `_id` | BSON::ObjectId | MongoDB primary key | Yes |
| `created_at` | DateTime | Creation timestamp | Yes (Mongoid) |
| `updated_at` | DateTime | Last update timestamp | Yes (Mongoid) |

**Note:** Blockchain has no user-defined fields, only relationships and timestamps.

### Relationships

**has_many :blocks**
- One Blockchain can have many Blocks
- Blocks are dependent (if Blockchain deleted, blocks deleted)
- Accessed via: `blockchain.blocks`

### Methods

#### add_block(data, difficulty: 2)

Adds a new block to the blockchain.

**Parameters:**
- `data` (String, required): Data to store in block
- `difficulty` (Integer, optional): Mining difficulty 1-10 (default: 2)

**Returns:**
- `Block`: The newly created and mined block

**Raises:**
- `RuntimeError`: If blockchain integrity is invalid

**Process:**
1. Validates chain integrity
2. Gets last block
3. Builds new block with incremented index
4. Mines block (Proof of Work)
5. Saves block to database
6. Returns block

**Example:**
```ruby
blockchain = Blockchain.create
block = blockchain.add_block("Transaction data", difficulty: 3)
# => #<Block _id: 674c..., index: 1, hash: "000abc...">
```

**Source:** `src/blockchain.rb:22-34`

#### integrity_valid?

Validates the integrity of the entire blockchain.

**Returns:**
- `true`: All blocks are valid and properly linked
- `false`: Chain integrity is compromised

**Validation Checks:**
1. Each block's `previous_hash` matches prior block's `hash`
2. Each block's stored hash matches its calculated hash
3. Each block's hash meets its difficulty requirement

**Example:**
```ruby
blockchain.integrity_valid?
# => true

# If block data is tampered:
# => false
```

**Source:** `src/blockchain.rb:47-53`

#### last_block

Returns the most recent block in the chain.

**Returns:**
- `Block`: The last block

**Raises:**
- `RuntimeError`: If no blocks exist (shouldn't happen due to genesis block)

**Example:**
```ruby
last = blockchain.last_block
# => #<Block index: 5, ...>
```

**Source:** `src/blockchain.rb:40-42`

### Callbacks

#### after_create :add_genesis_block

Automatically creates genesis block when blockchain is instantiated.

**Genesis Block Properties:**
- `index`: 0
- `data`: "Genesis Block"
- `previous_hash`: "0"
- `nonce`: 0 (not mined)
- `difficulty`: 0

**Triggered:** Immediately after `Blockchain.create` or `Blockchain.new.save`

**Source:** `src/blockchain.rb:15` (callback), `src/blockchain.rb:59-61` (implementation)

## Block Model

### Source Location

`src/block.rb`

### Class Definition

```ruby
class Block
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :index, type: Integer
  field :data, type: String
  field :previous_hash, type: String
  field :_hash, type: String, as: :hash
  field :nonce, type: Integer, default: 0
  field :difficulty, type: Integer, default: -> { ENV.fetch('DEFAULT_DIFFICULTY', '2').to_i }

  # Relationships
  belongs_to :blockchain

  # Callbacks
  before_validation :calculate_hash
end
```

### Attributes

| Field | Type | Default | Description | Mutable |
|-------|------|---------|-------------|---------|
| `_id` | BSON::ObjectId | Auto | MongoDB primary key | No |
| `blockchain_id` | BSON::ObjectId | Required | Foreign key to Blockchain | No |
| `index` | Integer | Required | Position in chain (0, 1, 2, ...) | No |
| `data` | String | Required | Stored data/information | No* |
| `previous_hash` | String | Required | Previous block's hash | No |
| `_hash` | String | Auto | Block's SHA256 hash | No |
| `nonce` | Integer | 0 | Proof of Work nonce | No |
| `difficulty` | Integer | ENV or 2 | Mining difficulty (1-10) | No |
| `created_at` | DateTime | Auto | Block creation timestamp | No |
| `updated_at` | DateTime | Auto | Last update timestamp | Yes |

**Note:** *Data is technically mutable in DB, but should never be changed (breaks immutability).

### Special Field: _hash

**Why `_hash` instead of `hash`?**

Ruby objects have a built-in `hash` method:

```ruby
object.hash  # => Ruby's internal hash code (integer)
```

To avoid conflicts, Mongoid uses **field aliasing**:

```ruby
field :_hash, type: String, as: :hash
```

**Usage:**
- **In Ruby code:** `block._hash`
- **In MongoDB:** Stored as `hash` field
- **In JSON responses:** Returned as `hash`

**Example:**
```ruby
block._hash
# => "00abc123def456..."

block.attributes['hash']
# => "00abc123def456..." (MongoDB field name)
```

### Default Difficulty Lambda

```ruby
field :difficulty, type: Integer, default: -> { ENV.fetch('DEFAULT_DIFFICULTY', '2').to_i }
```

**Why lambda?**
- Environment variables are read at **runtime**, not parse time
- Allows different defaults per environment (dev, test, production)
- Falls back to 2 if `DEFAULT_DIFFICULTY` not set

**Example:**
```bash
# .env
DEFAULT_DIFFICULTY=3

# Ruby
Block.new.difficulty  # => 3 (from ENV)

# If DEFAULT_DIFFICULTY not set:
Block.new.difficulty  # => 2 (fallback)
```

### Relationships

**belongs_to :blockchain**
- Each Block belongs to one Blockchain
- Foreign key: `blockchain_id` (BSON::ObjectId)
- Required: Cannot create block without blockchain
- Accessed via: `block.blockchain`

### Methods

#### calculate_hash

Calculates the SHA256 hash of the block.

**Returns:**
- `String`: 64-character hexadecimal hash

**Hash Input:**
```ruby
"#{index}#{created_at.to_i}#{data}#{previous_hash}#{nonce}"
```

**Example:**
```ruby
block.index = 1
block.created_at = Time.at(1699564821)
block.data = "Hello"
block.previous_hash = "abc123"
block.nonce = 7

block.calculate_hash
# => "0a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef012345678"
```

**Source:** `src/block.rb:43-46`

#### mine_block

Performs Proof of Work mining to find valid nonce.

**Returns:**
- `String`: Valid hash meeting difficulty requirement

**Process:**
1. Generate target string (e.g., "000" for difficulty 3)
2. Loop:
   - Calculate hash with current nonce
   - Check if hash starts with target
   - If yes: break (success)
   - If no: increment nonce and retry

**Example:**
```ruby
block.difficulty = 3
block.mine_block
# => "000abc123def456..." (after ~4000 attempts)

block.nonce
# => 4832 (number of attempts)
```

**Source:** `src/block.rb:60-69`

#### valid_hash?

Checks if block's hash meets difficulty requirement.

**Returns:**
- `true`: Hash has required leading zeros
- `false`: Hash doesn't meet difficulty

**Example:**
```ruby
block._hash = "000abc..."
block.difficulty = 3
block.valid_hash?
# => true (starts with "000")

block.difficulty = 4
block.valid_hash?
# => false (doesn't start with "0000")
```

**Source:** `src/block.rb:74-77`

#### valid_data?(data)

Validates that provided data matches block's stored data.

**Parameters:**
- `data` (String): Data to validate

**Returns:**
- `true`: Data matches (hash verification succeeds)
- `false`: Data doesn't match (tampered)

**Process:**
1. Recalculate hash using provided data
2. Compare with stored hash
3. Return true if match, false otherwise

**Example:**
```ruby
block.data = "Original data"
block._hash = "abc123..."  # Hash of original data

block.valid_data?("Original data")
# => true (matches)

block.valid_data?("Tampered data")
# => false (hash mismatch)
```

**Source:** `src/block.rb:50-52`

### Callbacks

#### before_validation :calculate_hash

Automatically calculates hash before validation.

**Triggered:**
- Before `block.valid?`
- Before `block.save` (validation runs before save)

**Purpose:**
- Ensures hash is always calculated before saving
- Developer doesn't need to manually call `calculate_hash`

**Example:**
```ruby
block = Block.new(index: 1, data: "test", previous_hash: "abc")
block._hash
# => nil (not calculated yet)

block.valid?  # Triggers before_validation
block._hash
# => "a1b2c3..." (calculated automatically)
```

**Source:** `src/block.rb:35`

## Model Relationships

### Entity Relationship Diagram

```
┌─────────────────────────────────┐
│         Blockchain              │
│  ┌───────────────────────────┐  │
│  │ _id: ObjectId             │  │
│  │ created_at: DateTime      │  │
│  │ updated_at: DateTime      │  │
│  └───────────────────────────┘  │
└──────────────┬──────────────────┘
               │ 1
               │
               │ has_many :blocks
               │
               │ *
       ┌───────┴──────────────────────┐
       │                              │
┌──────▼───────────────┐  ┌───────────▼──────────┐
│  Block (Genesis)     │  │  Block 1             │  ...
│ ┌──────────────────┐ │  │ ┌──────────────────┐ │
│ │ index: 0         │ │  │ │ index: 1         │ │
│ │ data: "Genesis"  │ │  │ │ data: "..."      │ │
│ │ previous_hash: 0 │ │  │ │ previous_hash:   │ │
│ │ hash: abc123...  │ │  │ │   abc123... ──────┼──┐
│ │ nonce: 0         │ │  │ │ hash: 00def4...  │ │ │
│ │ difficulty: 0    │ │  │ │ nonce: 142       │ │ │
│ └──────────────────┘ │  │ │ difficulty: 2    │ │ │
└──────────────────────┘  │ └──────────────────┘ │ │
                          └──────────────────────┘ │
                                         Hash Link ◄┘
```

### Relationship Details

**Blockchain → Blocks (One-to-Many)**

```ruby
# Create blockchain
blockchain = Blockchain.create

# Access blocks
blockchain.blocks
# => [#<Block index: 0, data: "Genesis Block">]

# Add block
blockchain.add_block("New data")

blockchain.blocks.count
# => 2

# Query blocks
blockchain.blocks.where(difficulty: 3)
blockchain.blocks.order(index: :asc)
```

**Block → Blockchain (Belongs-to)**

```ruby
# Access parent blockchain
block = Block.first
block.blockchain
# => #<Blockchain _id: 674c...>

# Create block (requires blockchain)
blockchain = Blockchain.create
block = blockchain.blocks.create(
  index: 1,
  data: "test",
  previous_hash: "abc"
)

# Orphan blocks not allowed
Block.create(index: 1, data: "test")  # Error: blockchain must exist
```

## MongoDB Schema

### Database Structure

ChainForge uses two collections in MongoDB:

#### blockchains Collection

```javascript
{
  "_id": ObjectId("674c8a1b2e4f5a0012345678"),
  "created_at": ISODate("2025-11-09T12:34:56.789Z"),
  "updated_at": ISODate("2025-11-09T12:34:56.789Z")
}
```

**Indexes:**
- `_id`: Primary key (auto-created, unique)

**Size:** ~100 bytes per document

#### blocks Collection

```javascript
{
  "_id": ObjectId("674c8b2c3e5f6a0012345679"),
  "blockchain_id": ObjectId("674c8a1b2e4f5a0012345678"),
  "index": 1,
  "data": "Hello, Blockchain!",
  "previous_hash": "abc123def456...",
  "hash": "00a1b2c3d4e5f6789abcdef...",
  "nonce": 142,
  "difficulty": 2,
  "created_at": ISODate("2025-11-09T12:35:23.456Z"),
  "updated_at": ISODate("2025-11-09T12:35:23.456Z")
}
```

**Indexes:**
- `_id`: Primary key (auto-created, unique)
- `blockchain_id`: Foreign key (auto-indexed by Mongoid)

**Size:** ~500 bytes per document (depends on data field)

### Data Types in MongoDB

| Ruby Type | MongoDB BSON Type | Example |
|-----------|-------------------|---------|
| Integer | Int32/Int64 | `index: 1` |
| String | String (UTF-8) | `data: "Hello"` |
| BSON::ObjectId | ObjectId | `_id: ObjectId("...")` |
| DateTime | Date | `created_at: ISODate("...")` |

### Querying Examples

**Find blockchain by ID:**
```ruby
Blockchain.find("674c8a1b2e4f5a0012345678")
```

**Get all blocks in chain:**
```ruby
blockchain.blocks.to_a
```

**Find specific block:**
```ruby
blockchain.blocks.find("674c8b2c3e5f6a0012345679")
blockchain.blocks.where(index: 1).first
```

**Count blocks:**
```ruby
blockchain.blocks.count
```

**Get blocks by difficulty:**
```ruby
blockchain.blocks.where(difficulty: 3).to_a
```

**Order blocks by index:**
```ruby
blockchain.blocks.order(index: :asc).to_a
```

## Lifecycle and Callbacks

### Blockchain Lifecycle

```
1. Creation
   Blockchain.create
   ↓
2. Callback: after_create
   add_genesis_block
   ↓
3. Genesis Block Created
   Block(index: 0, data: "Genesis Block")
   ↓
4. Blockchain Ready
   Can add blocks via add_block()
```

### Block Lifecycle

```
1. Build Block
   blockchain.blocks.build(index: 1, data: "test", ...)
   ↓
2. Mining (if via add_block)
   block.mine_block
   ├─ Loop: increment nonce
   ├─ Calculate hash
   └─ Until valid hash found
   ↓
3. Validation
   block.valid?
   ├─ Callback: before_validation
   ├─ Calls: calculate_hash (if not mined)
   └─ Validates fields
   ↓
4. Save to MongoDB
   block.save!
   ├─ Sets created_at
   ├─ Sets updated_at
   └─ Writes to database
   ↓
5. Block Persisted
   Immutable in blockchain
```

## Validation Rules

### Blockchain Validation

**No explicit validations** - Blockchain model has no custom validators.

**Integrity Validation:**
- Manual via `integrity_valid?` method
- Called before adding new blocks

### Block Validation

**Mongoid Validations:**
- `blockchain`: Must be present (belongs_to relationship)
- All other validations implicit via field types

**Application-Level Validation:**
- Difficulty: 1-10 (enforced by API validator, not model)
- Data: Must be filled (enforced by API validator, not model)

**Hash Validation:**
- `valid_hash?`: Checks PoW requirement
- `valid_data?`: Checks data integrity

## Querying Patterns

### Common Queries

**Get last N blocks:**
```ruby
blockchain.blocks.order(index: :desc).limit(5)
```

**Find blocks with specific data:**
```ruby
blockchain.blocks.where(data: /transaction/i)  # Case-insensitive regex
```

**Get high-difficulty blocks:**
```ruby
blockchain.blocks.where(:difficulty.gte => 5)
```

**Count blocks by difficulty:**
```ruby
blockchain.blocks.where(difficulty: 3).count
```

**Get blocks created today:**
```ruby
blockchain.blocks.where(:created_at.gte => Time.now.beginning_of_day)
```

### Performance Considerations

**Indexed Queries (Fast):**
- Find by `_id`: O(1)
- Find by `blockchain_id`: O(1) (indexed)

**Non-Indexed Queries (Slower):**
- Find by `data`: O(n) (full collection scan)
- Find by `difficulty`: O(n)

**For Production:**
- Add indexes for frequently queried fields
- Use projections to limit returned fields
- Implement pagination for large result sets

## Next Steps

- [Architecture Overview](overview.md) - System design and data flow
- [Proof of Work](proof-of-work.md) - Mining algorithm
- [Security Design](security-design.md) - Security analysis
- [API Reference](../api/reference.md) - HTTP endpoints

---

**Questions?** See [CONTRIBUTING](../CONTRIBUTING.md) for how to ask questions or suggest improvements.
