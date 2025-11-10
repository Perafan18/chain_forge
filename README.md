# ChainForge

> **Educational Side Project**: ChainForge is a learning-focused blockchain implementation built to understand core blockchain concepts like cryptographic hashing, Proof of Work mining, chain validation, and distributed ledger fundamentals. This is NOT intended for production use.

[![Ruby](https://img.shields.io/badge/Ruby-3.2.2-red.svg)](https://www.ruby-lang.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-Latest-green.svg)](https://www.mongodb.com/)
[![Sinatra](https://img.shields.io/badge/Sinatra-4.0-blue.svg)](http://sinatrarb.com/)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-brightgreen.svg)](https://github.com/Perafan18/chain_forge/actions)

A blockchain implementation with REST API built using Ruby, Sinatra, and MongoDB. Explore how blocks are linked through cryptographic hashes, how Proof of Work mining secures the chain, and how API security works.

## Features

### Core Blockchain
- ✅ Create independent blockchain instances
- ✅ Add blocks with custom data
- ✅ SHA256 cryptographic hashing
- ✅ Chain integrity validation
- ✅ Genesis block auto-generation

### Version 2 Features
- ✅ **Proof of Work (PoW)** mining algorithm with configurable difficulty
- ✅ **API Versioning** - All endpoints under `/api/v1`
- ✅ **Rate Limiting** - Rack::Attack protection (60 req/min)
- ✅ **Input Validation** - dry-validation with detailed errors
- ✅ **Environment Configuration** - Configurable mining difficulty
- ✅ **CI/CD Pipeline** - GitHub Actions with automated testing
- ✅ **Code Quality** - RuboCop linting and SimpleCov coverage

## Quick Start

### Prerequisites

- Ruby 3.2.2
- MongoDB
- Docker (optional)

### Installation

1. **Install Ruby 3.2.2**

```bash
rbenv install 3.2.2
rbenv local 3.2.2
```

2. **Install Dependencies**

```bash
bundle install
```

3. **Configure Environment**

```bash
cp .env.example .env
```

Edit `.env` and configure:
- `MONGO_DB_NAME` - Database name (default: chain_forge)
- `MONGO_DB_HOST` - MongoDB host (default: localhost)
- `MONGO_DB_PORT` - MongoDB port (default: 27017)
- `DEFAULT_DIFFICULTY` - Mining difficulty 1-10 (default: 2)
- `ENVIRONMENT` - Runtime environment (development/test/production)

4. **Start MongoDB**

```bash
# Using Docker (recommended)
docker-compose up -d mongodb

# Or install locally
brew install mongodb-community
brew services start mongodb-community
```

5. **Run the Application**

```bash
ruby main.rb -p 1910
```

Visit http://localhost:1910 to verify it's running.

### Using Docker (Recommended)

```bash
docker-compose up
```

This starts both the application and MongoDB with proper networking.

## Development

### Run Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage report
COVERAGE=true bundle exec rspec

# View coverage
open coverage/index.html
```

### Code Quality

```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a
```

### Continuous Integration

This project uses GitHub Actions for automated testing. Each push and PR triggers:
- ✅ RuboCop style checks
- ✅ RSpec test suite (17 examples)
- ✅ SimpleCov coverage reporting
- ✅ MongoDB integration tests

See `.github/workflows/ci.yml` for pipeline configuration.

## API Reference

All endpoints are prefixed with `/api/v1` and protected by rate limiting.

### Rate Limiting

| Endpoint Pattern | Limit | Window |
|-----------------|-------|--------|
| All endpoints | 60 requests | 1 minute |
| POST /api/v1/chain | 10 requests | 1 minute |
| POST /api/v1/chain/:id/block | 30 requests | 1 minute |

When rate limit is exceeded:
```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```
**HTTP Status**: 429 (Too Many Requests)

### Create a New Blockchain

```bash
curl -X POST http://localhost:1910/api/v1/chain
```

**Response:**
```json
{"id": "507f1f77bcf86cd799439011"}
```

**Rate Limit:** 10 requests/minute per IP

---

### Add a Block to Chain (Mine)

```bash
curl -X POST http://localhost:1910/api/v1/chain/507f1f77bcf86cd799439011/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Transaction data here", "difficulty": 3}'
```

**Request Parameters:**
- `data` (required, string): The data to store in the block
- `difficulty` (optional, integer 1-10): Mining difficulty (default: uses `DEFAULT_DIFFICULTY` env var)

**Response:**
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "block_id": "507f191e810c19729de860ea",
  "block_hash": "000a1b2c3d4e5f...",
  "nonce": 1542,
  "difficulty": 3
}
```

**Validation Errors (400):**
```json
{
  "errors": {
    "data": ["must be filled"],
    "difficulty": ["must be between 1 and 10"]
  }
}
```

**Rate Limit:** 30 requests/minute per IP

**Note:** Mining can take time depending on difficulty:
- Difficulty 1-2: ~1 second
- Difficulty 3-4: Few seconds
- Difficulty 5+: Minutes or longer

---

### Get Block Details

```bash
curl http://localhost:1910/api/v1/chain/507f1f77bcf86cd799439011/block/507f191e810c19729de860ea
```

**Response:**
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "block": {
    "id": "507f191e810c19729de860ea",
    "index": 1,
    "data": "Transaction data here",
    "hash": "000a1b2c3d4e5f...",
    "previous_hash": "00f8a2b1c3d4...",
    "nonce": 1542,
    "difficulty": 3,
    "timestamp": 1699564821,
    "valid_hash": true
  }
}
```

---

### Validate Block Data

```bash
curl -X POST http://localhost:1910/api/v1/chain/507f1f77bcf86cd799439011/block/507f191e810c19729de860ea/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "Transaction data here"}'
```

**Response:**
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "block_id": "507f191e810c19729de860ea",
  "valid": true
}
```

---

For complete API documentation, see [API_DOCUMENTATION.md](API_DOCUMENTATION.md).

## Proof of Work (PoW)

ChainForge implements a simplified Proof of Work consensus mechanism similar to Bitcoin's mining process.

### How Mining Works

1. **Target Calculation**: Based on difficulty level (1-10), the system determines how many leading zeros the hash must have:
   - Difficulty 1: Hash must start with `0`
   - Difficulty 2: Hash must start with `00`
   - Difficulty 3: Hash must start with `000`
   - And so on...

2. **Mining Process**:
   ```
   Start with nonce = 0
   Loop:
     Calculate: hash = SHA256(index + timestamp + data + previous_hash + nonce)
     If hash starts with required zeros:
       Mining complete! ✓
     Else:
       nonce++
       Try again
   ```

3. **Mining Example**:
   ```
   Block: index=1, data="Hello World", difficulty=3
   Target: Hash must start with "000"

   Attempt 1: nonce=0   -> hash=a1b2c3d4... ✗ (invalid)
   Attempt 2: nonce=1   -> hash=9f8e7d6c... ✗ (invalid)
   Attempt 3: nonce=2   -> hash=3d4c5b6a... ✗ (invalid)
   ...
   Attempt 1542: nonce=1542 -> hash=000a1b2c... ✓ (valid!)
   ```

### Performance Impact

| Difficulty | Average Time | Leading Zeros |
|-----------|-------------|---------------|
| 1-2 | < 1 second | 0 or 00 |
| 3-4 | Few seconds | 000 or 0000 |
| 5-6 | Minutes | 00000 or 000000 |
| 7+ | Hours+ | 0000000+ |

**Recommendation**: Use difficulty 2-4 for development and testing.

### Configuring Difficulty

**Default (via environment):**
```bash
# .env file
DEFAULT_DIFFICULTY=2
```

**Per-block (via API):**
```bash
curl -X POST http://localhost:1910/api/v1/chain/:id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "your_data", "difficulty": 4}'
```

### Comparison with Bitcoin

ChainForge's PoW demonstrates the core concept but is simplified:

| Feature | ChainForge | Bitcoin |
|---------|-----------|---------|
| Hash Algorithm | Single SHA256 | Double SHA256 |
| Difficulty Range | 1-10 (fixed) | Dynamic (adjusts every 2016 blocks) |
| Current Difficulty | ~2-3 leading zeros | ~19 leading zeros (as of 2023) |
| Block Time | Variable | ~10 minutes (target) |
| Difficulty Adjustment | Manual/per-block | Automatic every 2 weeks |
| Merkle Trees | No | Yes |
| Block Rewards | No | Yes (currently 6.25 BTC) |

**Educational Note**: This implementation demonstrates PoW fundamentals. Real blockchains include additional complexity like dynamic difficulty adjustment, merkle trees for transaction verification, and sophisticated networking protocols.

## Architecture

### Core Models

**Blockchain** (`src/blockchain.rb`)
- Contains a collection of blocks (MongoDB: `has_many :blocks`)
- Automatically creates genesis block on initialization
- Validates chain integrity by checking:
  - Hash links between consecutive blocks
  - Each block's hash matches its calculated hash
  - Each block's hash meets its difficulty requirement (PoW)
- Genesis block is NOT mined (to speed up creation)

**Block** (`src/block.rb`)
- **Fields**: index, data, previous_hash, calculated SHA256 hash, nonce, difficulty, timestamp
- **Hash Calculation**: `SHA256(index + timestamp + data + previous_hash + nonce)`
- **Mining**: `mine_block` method increments nonce until valid hash found
- **Validation**: `valid_hash?` verifies hash meets difficulty requirement
- **Immutability**: Hash and PoW verification prevents tampering

### How It Works

1. **Genesis Block**: Each blockchain starts with block index 0 (no mining required)
2. **Adding Blocks**:
   - Client sends data and optional difficulty
   - System validates input (dry-validation)
   - Block is created with reference to previous block's hash
   - Mining process begins (PoW algorithm)
   - Block is saved once valid hash is found
3. **Mining Process**:
   - System tries different nonce values
   - Calculates hash for each nonce
   - Continues until hash starts with required leading zeros
   - Higher difficulty = more zeros = more attempts = more secure
4. **Chain Validation**:
   - Verifies each block's hash matches its calculated hash
   - Verifies each block's hash meets difficulty requirement (valid_hash?)
   - Verifies each block links to previous block's hash
   - If any check fails, chain is invalid
5. **Data Integrity**:
   - Changing any block invalidates its hash
   - Invalid hash breaks PoW requirement
   - Breaks link to next block
   - Invalidates entire chain from that point forward
6. **Security Layers**:
   - **PoW**: Computationally expensive to modify blocks
   - **Rate Limiting**: Prevents API abuse (Rack::Attack)
   - **Input Validation**: Prevents malformed data (dry-validation)
   - **Hash Chaining**: Each block depends on previous block

### Data Flow

```
Client Request
     ↓
Rate Limiting (Rack::Attack)
     ↓
Input Validation (dry-validation)
     ↓
Blockchain Integrity Check
     ↓
Block Creation
     ↓
Mining (Proof of Work)
     ↓
Block Saved to MongoDB
     ↓
JSON Response
```

## Security

### Rate Limiting

Implemented via Rack::Attack middleware:
- Protects against DoS attacks
- Prevents resource exhaustion
- Per-IP address enforcement
- Configurable limits per endpoint
- Disabled in test environment

### Input Validation

Implemented via dry-validation:
- Type checking (strings, integers)
- Range validation (difficulty 1-10)
- Required field enforcement
- Returns detailed error messages
- Prevents injection attacks

### Cryptographic Security

- SHA256 hashing for block integrity
- Proof of Work for block creation
- Immutable chain structure
- Hash-based tamper detection

### Known Limitations

This is an educational project and lacks production-grade security:
- ❌ No encryption for data at rest
- ❌ No authentication/authorization
- ❌ No HTTPS enforcement
- ❌ Simple in-memory rate limiting
- ❌ No distributed consensus
- ❌ No peer-to-peer networking

For security best practices, see [SECURITY.md](SECURITY.md).

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `MONGO_DB_NAME` | MongoDB database name | chain_forge | Yes |
| `MONGO_DB_HOST` | MongoDB hostname | localhost | Yes |
| `MONGO_DB_PORT` | MongoDB port | 27017 | Yes |
| `ENVIRONMENT` | Runtime environment | development | Yes |
| `DEFAULT_DIFFICULTY` | Default mining difficulty (1-10) | 2 | No |

### Docker Environment

When using Docker Compose, environment variables are configured automatically. Override in `docker-compose.yml` if needed.

### Test Environment

Test configuration is in `.env.test`:
- Uses separate database: `chain_forge_test`
- Rate limiting disabled
- Coverage reporting enabled with `COVERAGE=true`

## Contributing

Contributions are welcome! This is a learning project focused on understanding blockchain fundamentals.

For contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

### Development Guidelines

- Maintain educational value (readable, well-commented code)
- Include RSpec tests for all features (aim for >90% coverage)
- Follow RuboCop style guidelines
- Update documentation when adding features
- All PRs must pass CI checks

## Documentation

- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - Complete API reference
- [SECURITY.md](SECURITY.md) - Security policies and best practices
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [DEPLOYMENT.md](DEPLOYMENT.md) - Production deployment guide
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [CLAUDE.md](CLAUDE.md) - Claude Code guidance

## License

MIT License - see LICENSE file for details

## Acknowledgments

Built as a learning exercise to understand blockchain technology fundamentals, including:
- Cryptographic hashing (SHA256)
- Proof of Work consensus
- Chain integrity validation
- API security best practices
- RESTful API design

Special thanks to the blockchain community for educational resources and inspiration.

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

**Current Version**: 2.0.0
- ✅ Proof of Work mining
- ✅ API versioning
- ✅ Rate limiting and validation
- ✅ Environment configuration
- ✅ CI/CD pipeline
