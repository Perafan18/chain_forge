# Architecture Overview

This document provides a comprehensive overview of ChainForge's system architecture, data flow, and component interactions.

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Technology Stack](#technology-stack)
3. [Component Overview](#component-overview)
4. [Data Flow](#data-flow)
5. [Database Schema](#database-schema)
6. [Security Layers](#security-layers)
7. [Design Decisions](#design-decisions)

## High-Level Architecture

ChainForge follows a classic three-tier architecture:

```
┌─────────────────────────────────────────┐
│          Client Layer                    │
│  (HTTP Clients: curl, apps, browsers)   │
└───────────────┬─────────────────────────┘
                │ HTTP/JSON
                ↓
┌─────────────────────────────────────────┐
│      Application Layer (Sinatra)        │
│  ┌────────────────────────────────────┐ │
│  │  Rack::Attack (Rate Limiting)      │ │
│  └──────────────┬─────────────────────┘ │
│                 ↓                        │
│  ┌────────────────────────────────────┐ │
│  │  API Routes (/api/v1/*)            │ │
│  └──────────────┬─────────────────────┘ │
│                 ↓                        │
│  ┌────────────────────────────────────┐ │
│  │  Input Validation (dry-validation) │ │
│  └──────────────┬─────────────────────┘ │
│                 ↓                        │
│  ┌────────────────────────────────────┐ │
│  │  Business Logic (Models)           │ │
│  │  - Blockchain Model                │ │
│  │  - Block Model (with PoW)          │ │
│  └──────────────┬─────────────────────┘ │
└─────────────────┼─────────────────────────┘
                  │ Mongoid ODM
                  ↓
┌─────────────────────────────────────────┐
│       Data Layer (MongoDB)              │
│  ┌────────────────┐  ┌────────────────┐│
│  │  Blockchains   │  │    Blocks      ││
│  │  Collection    │  │  Collection    ││
│  └────────────────┘  └────────────────┘│
└─────────────────────────────────────────┘
```

## Technology Stack

### Core Technologies

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Language** | Ruby | 3.2.2 | Application logic |
| **Web Framework** | Sinatra | 4.0 | HTTP routing and request handling |
| **Database** | MongoDB | Latest | NoSQL document storage |
| **ODM** | Mongoid | 7.0.5 | Object-Document Mapping |
| **Server** | Puma | (via Sinatra) | HTTP server |

### Security & Validation

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Rate Limiting** | Rack::Attack | 6.7 | DoS protection |
| **Input Validation** | dry-validation | 1.10 | Schema validation |
| **Cryptography** | Digest (Ruby stdlib) | - | SHA256 hashing |

### Development & Quality

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Testing** | RSpec | 3.10 | Unit and integration tests |
| **Coverage** | SimpleCov | - | Code coverage reporting |
| **Linting** | RuboCop | 1.57 | Code style enforcement |
| **CI/CD** | GitHub Actions | - | Automated testing |

### Deployment

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Containerization** | Docker | Latest | Application containers |
| **Orchestration** | Docker Compose | Latest | Multi-container deployment |
| **Environment** | dotenv | 2.7 | Configuration management |

## Component Overview

### 1. Application Entry Point (`main.rb`)

The main Sinatra application that:
- Loads dependencies and configuration
- Initializes Mongoid connection
- Configures Rack::Attack middleware
- Defines API routes under `/api/v1` namespace
- Handles request parsing and error responses

**Key Responsibilities:**
- Request routing
- Middleware configuration
- JSON parsing and response formatting
- Error handling
- Helper methods for common operations

### 2. Blockchain Model (`src/blockchain.rb`)

The core blockchain model that manages collections of blocks.

**Attributes:**
- `id`: MongoDB ObjectId (auto-generated)
- `blocks`: Has-many relationship to Block model
- `created_at`, `updated_at`: Timestamps (Mongoid)

**Key Methods:**
- `add_block(data, difficulty)`: Mines and adds new block to chain
- `integrity_valid?`: Validates entire chain integrity
- `last_block`: Returns the most recent block
- `add_genesis_block` (private): Auto-creates genesis block on creation

**Callbacks:**
- `after_create :add_genesis_block`: Creates genesis block automatically

**Source:** `/src/blockchain.rb`

### 3. Block Model (`src/block.rb`)

Represents individual blocks in the blockchain.

**Attributes:**
- `index`: Integer - Block position in chain (0 = genesis)
- `data`: String - Stored information
- `previous_hash`: String - Hash of previous block
- `_hash`: String - Block's SHA256 hash (aliased as `hash`)
- `nonce`: Integer - Proof of Work nonce (default: 0)
- `difficulty`: Integer - Mining difficulty (default: from env)
- `created_at`, `updated_at`: Timestamps

**Key Methods:**
- `calculate_hash`: Generates SHA256 hash from block data
- `mine_block`: Performs Proof of Work mining
- `valid_hash?`: Checks if hash meets difficulty requirement
- `valid_data?(data)`: Validates data integrity

**Callbacks:**
- `before_validation :calculate_hash`: Auto-calculates hash before save

**Relationships:**
- `belongs_to :blockchain`: Each block belongs to one blockchain

**Source:** `/src/block.rb`

### 4. Validators (`src/validators.rb`)

Input validation using dry-validation schema contracts.

**BlockDataContract:**
```ruby
schema do
  required(:data).filled(:string)  # Must be present and non-empty
  optional(:difficulty).filled(:integer, gteq?: 1, lteq?: 10)  # 1-10 if present
end
```

**Source:** `/src/validators.rb`

### 5. Rate Limiting Configuration (`config/rack_attack.rb`)

Rack::Attack middleware configuration for API protection.

**Throttles:**
1. **Global Limit**: 60 requests/minute per IP (all endpoints)
2. **Chain Creation**: 10 requests/minute per IP (POST /api/v1/chain)
3. **Block Creation**: 30 requests/minute per IP (POST /api/v1/chain/:id/block)

**Custom Response:**
- Status: 429 (Too Many Requests)
- Body: `{"error": "Rate limit exceeded. Please try again later."}`

**Disabled in:** Test environment (`ENV['ENVIRONMENT'] == 'test'`)

**Source:** `/config/rack_attack.rb`

### 6. Database Configuration (`config/mongoid.yml`)

MongoDB connection configuration using environment variables.

**Environments:**
- `development`: Local development database
- `test`: Separate test database
- `production`: Production database

**Key Configuration:**
- Database name: `ENV['MONGO_DB_NAME']`
- Host: `ENV['MONGO_DB_HOST']`
- Port: `ENV['MONGO_DB_PORT']`

**Source:** `/config/mongoid.yml`

## Data Flow

### Creating a Blockchain

```
1. Client Request
   POST /api/v1/chain

2. Rate Limiting Check
   Rack::Attack: Check global + chain creation limits

3. Route Handler (main.rb:34)
   blockchain = Blockchain.create

4. Blockchain Model
   - Create new Blockchain instance
   - Trigger after_create callback

5. Genesis Block Creation
   - Create Block(index: 0, data: "Genesis Block", previous_hash: "0")
   - Calculate hash (no mining for genesis)
   - Save to database

6. Response
   {"id": "blockchain_id"}
```

### Mining a Block

```
1. Client Request
   POST /api/v1/chain/:id/block
   Body: {"data": "...", "difficulty": 3}

2. Rate Limiting Check
   Rack::Attack: Check global + block creation limits

3. Input Validation (main.rb:42)
   BlockDataContract.new.call(block_data)
   - Validate data is filled string
   - Validate difficulty is 1-10 (if present)
   - Return 400 if validation fails

4. Blockchain Retrieval (main.rb:47)
   blockchain = Blockchain.find(chain_id)
   - Raise error if not found

5. Add Block (blockchain.rb:22)
   blockchain.add_block(data, difficulty: 3)

6. Integrity Check (blockchain.rb:23)
   integrity_valid? or raise 'Blockchain is not valid'
   - Validate all existing blocks
   - Check hash links
   - Check hash validity
   - Check PoW requirements

7. Block Creation (blockchain.rb:25-30)
   - Build new block with:
     - index: last_block.index + 1
     - data: from request
     - previous_hash: last_block._hash
     - difficulty: from request or env

8. Mining Process (block.rb:60)
   block.mine_block

   Mining Algorithm:
   ┌─────────────────────────────────┐
   │ target = "000" (for difficulty 3)│
   │ nonce = 0                       │
   └─────────────────────────────────┘
          ↓
   ┌─────────────────────────────────┐
   │ Loop:                           │
   │   1. calculate_hash()           │
   │   2. if hash.start_with?(target)│
   │      → break (found!)           │
   │   3. else nonce++               │
   │   4. repeat                     │
   └─────────────────────────────────┘
          ↓
   ┌─────────────────────────────────┐
   │ Valid hash found!               │
   │ hash = "000abc123..."           │
   │ nonce = 4832                    │
   └─────────────────────────────────┘

9. Save Block (blockchain.rb:32)
   block.save!
   - Persists to MongoDB

10. Response (main.rb:51-57)
    {
      "chain_id": "...",
      "block_id": "...",
      "block_hash": "000abc...",
      "nonce": 4832,
      "difficulty": 3
    }
```

### Validating Block Data

```
1. Client Request
   POST /api/v1/chain/:id/block/:block_id/valid
   Body: {"data": "original data"}

2. Validation & Retrieval
   - Validate input
   - Find blockchain
   - Find block

3. Data Validation (block.rb:50)
   block.valid_data?(data)

   Validation Process:
   ┌──────────────────────────────────┐
   │ 1. Recalculate hash with data    │
   │    new_hash = SHA256(index +     │
   │               timestamp + data + │
   │               previous_hash +    │
   │               nonce)             │
   │                                  │
   │ 2. Compare with stored hash      │
   │    new_hash == block._hash?      │
   └──────────────────────────────────┘

4. Response
   {
     "chain_id": "...",
     "block_id": "...",
     "valid": true/false
   }
```

## Database Schema

### Collections

MongoDB stores two collections:

#### 1. `blockchains` Collection

```javascript
{
  _id: ObjectId("674c8a1b2e4f5a0012345678"),
  created_at: ISODate("2025-11-09T12:34:56.789Z"),
  updated_at: ISODate("2025-11-09T12:34:56.789Z")
}
```

**Indexes:**
- `_id`: Primary key (auto-indexed)

#### 2. `blocks` Collection

```javascript
{
  _id: ObjectId("674c8b2c3e5f6a0012345679"),
  blockchain_id: ObjectId("674c8a1b2e4f5a0012345678"),  // Foreign key
  index: 1,
  data: "Hello, Blockchain!",
  previous_hash: "abc123def456...",
  hash: "00abc123...",  // Stored as 'hash' but field is '_hash' in Ruby
  nonce: 142,
  difficulty: 2,
  created_at: ISODate("2025-11-09T12:35:23.456Z"),
  updated_at: ISODate("2025-11-09T12:35:23.456Z")
}
```

**Indexes:**
- `_id`: Primary key
- `blockchain_id`: Foreign key to blockchains collection

**Relationships:**
- Each block document has a `blockchain_id` field referencing its parent blockchain
- Mongoid manages this relationship via `belongs_to :blockchain`

### Data Size Considerations

**Block Size:**
- Typical block: ~500 bytes
- Hash: 64 characters (SHA256 hex)
- Data: Variable (user-provided)
- Overhead: ~200 bytes (metadata)

**Scalability:**
- MongoDB handles millions of documents efficiently
- ChainForge is educational (not optimized for production scale)
- For production: Consider sharding, indexing strategies, compression

## Security Layers

ChainForge implements multiple security layers:

### 1. Rate Limiting (Rack::Attack)

**Purpose:** Prevent abuse and DoS attacks

**Implementation:**
- IP-based throttling
- Per-endpoint limits
- Memory-based storage (resets on restart)

**Limitations:**
- Not suitable for distributed systems (single-server only)
- Can be bypassed with IP rotation
- Memory-only (no persistence)

### 2. Input Validation (dry-validation)

**Purpose:** Prevent malformed data and injection attacks

**Implementation:**
- Schema-based validation
- Type checking
- Range enforcement
- Required field validation

**Benefits:**
- Prevents NoSQL injection
- Ensures data integrity
- Returns detailed error messages

### 3. Proof of Work

**Purpose:** Make blockchain tampering computationally expensive

**Implementation:**
- SHA256 hashing
- Difficulty-based mining
- Nonce iteration

**Security Properties:**
- Changing block data invalidates hash
- Re-mining required to fix hash
- Cascade effect through chain

### 4. Chain Integrity Validation

**Purpose:** Detect tampering and ensure consistency

**Implementation:**
- Hash chaining validation
- PoW validation
- Block hash verification

**Validation Steps:**
1. Verify each block's hash matches calculated hash
2. Verify each block's hash meets difficulty requirement
3. Verify each block's previous_hash links correctly

## Design Decisions

### Why MongoDB?

**Chosen for:**
- ✅ Flexible schema (JSON-like documents)
- ✅ Easy to learn and use
- ✅ Good Ruby support (Mongoid)
- ✅ Suitable for educational projects

**Trade-offs:**
- ❌ Less ACID guarantees than SQL
- ❌ No built-in foreign key constraints
- ❌ Larger storage footprint

**Alternatives considered:** PostgreSQL (JSON columns), Redis (fast but in-memory)

### Why Sinatra?

**Chosen for:**
- ✅ Lightweight and simple
- ✅ Minimal boilerplate
- ✅ Easy to understand for learners
- ✅ Sufficient for REST API needs

**Trade-offs:**
- ❌ Less built-in features than Rails
- ❌ Manual configuration required
- ❌ Smaller ecosystem

**Alternatives considered:** Rails (too heavy), Grape (similar complexity)

### Why SHA256 (Single)?

**Chosen for:**
- ✅ Industry standard
- ✅ Sufficient for educational purposes
- ✅ Fast computation
- ✅ Built into Ruby stdlib

**Trade-offs:**
- ❌ Bitcoin uses double SHA256
- ❌ Quantum computing concerns (future)

**Alternatives considered:** Double SHA256 (overkill for education)

### Why In-Memory Rate Limiting?

**Chosen for:**
- ✅ Simple implementation
- ✅ No external dependencies
- ✅ Sufficient for single-server deployment

**Trade-offs:**
- ❌ Resets on restart
- ❌ Not suitable for distributed systems
- ❌ No persistence

**Alternatives considered:** Redis (adds complexity), persistent storage (overkill)

### Why No Authentication?

**Reasoning:**
- Educational focus (blockchain concepts, not auth)
- Simplifies API usage for learners
- Would add complexity without educational value
- NOT intended for production use

**Production Requirements:**
- ✅ JWT or session-based authentication
- ✅ API keys
- ✅ Role-based access control

### Why Fixed Difficulty Range (1-10)?

**Chosen for:**
- ✅ Predictable mining times
- ✅ Prevents excessive CPU usage
- ✅ Easier to demonstrate PoW concepts
- ✅ Safe for development machines

**Trade-offs:**
- ❌ Bitcoin's difficulty adjusts dynamically
- ❌ Not representative of production blockchains

**Production Alternative:** Dynamic difficulty adjustment based on block time

## Performance Characteristics

### Mining Time Estimates

| Difficulty | Avg Attempts | Time (typical CPU) |
|-----------|-------------|-------------------|
| 1 | 16 | < 0.1s |
| 2 | 256 | 0.1-1s |
| 3 | 4,096 | 1-5s |
| 4 | 65,536 | 10-30s |
| 5 | 1,048,576 | 2-5 min |
| 6+ | 16,777,216+ | 30+ min |

### API Response Times

| Endpoint | Typical Response Time |
|----------|---------------------|
| POST /chain | < 50ms (includes genesis block creation) |
| POST /chain/:id/block (difficulty 2) | 100ms - 1s (mining) |
| GET /chain/:id/block/:id | < 10ms |
| POST /chain/:id/block/:id/valid | < 10ms |

### Database Performance

- **Insert**: O(1) - Fast
- **Find by ID**: O(1) - Very fast (indexed)
- **Chain validation**: O(n) - Linear with chain length
- **Scalability**: Tested up to 10,000 blocks per chain

## Next Steps

For deeper dives into specific topics:

- [Proof of Work Deep Dive](proof-of-work.md) - Mining algorithm details
- [Data Models](data-models.md) - MongoDB schema and relationships
- [Security Design](security-design.md) - Comprehensive security analysis
- [API Reference](../api/reference.md) - Complete endpoint documentation

---

**Questions or improvements?** See [CONTRIBUTING](../CONTRIBUTING.md) for how to contribute to this documentation.
