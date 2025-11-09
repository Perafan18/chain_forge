# ChainForge

> **Educational Side Project**: ChainForge is a learning-focused blockchain implementation built to understand core blockchain concepts like cryptographic hashing, chain validation, and distributed ledger fundamentals. This is NOT intended for production use.

[![Ruby](https://img.shields.io/badge/Ruby-3.2.2-red.svg)](https://www.ruby-lang.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-Latest-green.svg)](https://www.mongodb.com/)
[![Sinatra](https://img.shields.io/badge/Sinatra-4.0-blue.svg)](http://sinatrarb.com/)

A simple blockchain implementation with REST API built using Ruby, Sinatra, and MongoDB. Explore how blocks are linked through cryptographic hashes and how chain integrity is maintained.

## Features

- ✅ Create independent blockchain instances
- ✅ Add blocks with custom data
- ✅ SHA256 cryptographic hashing
- ✅ Chain integrity validation
- ✅ Genesis block auto-generation
- ✅ RESTful API
- 🚧 Advanced features (planned for v2)

## Setup

### Install ruby 3.2.2

```bash
rbenv install 3.2.2
rbenv local 3.2.2
```

### Install dependencies

```bash
bundle install
```

### Using Docker (Recommended)

```bash
docker-compose up
```

This will start both the application and MongoDB.

## Development

### Run Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/blockchain_spec.rb
```

### Run Application

```bash
# Local development (requires MongoDB running)
ruby main.rb -p 1910

# With Docker
docker-compose up
```

## API Reference

### Create a New Blockchain

```bash
curl -X POST http://localhost:1910/chain
```

**Response:**
```json
{"id": "507f1f77bcf86cd799439011"}
```

### Add a Block to Chain

```bash
curl -X POST http://localhost:1910/chain/:chain_id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "your_data"}'
```

**Response:**
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "block_id": "507f191e810c19729de860ea",
  "block_hash": "a1b2c3d4..."
}
```

### Validate Block Data

```bash
curl -X POST http://localhost:1910/chain/:chain_id/block/:block_id/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "your_data"}'
```

**Response:**
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "block_id": "507f191e810c19729de860ea",
  "valid": true
}
```

## Architecture

### Core Models

**Blockchain** (`src/blockchain.rb`)
- Contains a collection of blocks (MongoDB: `has_many :blocks`)
- Automatically creates genesis block on initialization
- Validates chain integrity by checking hash links between consecutive blocks

**Block** (`src/block.rb`)
- Contains: index, data, previous_hash, and calculated SHA256 hash
- Hash is computed from: `index + timestamp + data + previous_hash`
- Immutable once created (hash verification prevents tampering)

### How It Works

1. **Genesis Block**: Each blockchain starts with block index 0
2. **Adding Blocks**: New blocks reference the previous block's hash
3. **Chain Validation**: System verifies each block's hash matches its calculated hash AND links to previous block
4. **Data Integrity**: Changing any block invalidates all subsequent blocks

## Contributing

This is a personal learning project, but suggestions and improvements are welcome! Feel free to open an issue or PR.

## License

MIT License - see LICENSE file for details

## Acknowledgments

Built as a learning exercise to understand blockchain technology fundamentals.
