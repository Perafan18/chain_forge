# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

**This is an educational side project** - ChainForge is a learning-focused blockchain implementation NOT intended for production use. The goal is to understand blockchain fundamentals through hands-on implementation.

### Project Goals
- Demonstrate core blockchain concepts (hashing, chain validation, immutability)
- Provide a clean, well-tested Ruby codebase for learning
- Gradually add professional features (PoW, security, testing) as learning exercises
- Maintain simplicity while improving code quality

## Project Overview

ChainForge is a blockchain implementation built with Ruby, Sinatra, and MongoDB. It provides a RESTful API for creating blockchain instances, adding blocks, and validating block data integrity.

## Development Environment

- Ruby version: 3.2.2 (managed via rbenv)
- Database: MongoDB (via Mongoid ODM)
- Web framework: Sinatra 4.0
- Testing: RSpec 3.10

## Essential Commands

### Setup
```bash
# Install Ruby version
rbenv install 3.2.2
rbenv local 3.2.2

# Install dependencies
bundle install
```

### Running the Application
```bash
# Local development
ruby main.rb -p 1910

# Docker (includes MongoDB)
docker-compose up
```

### Testing
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/blockchain_spec.rb
bundle exec rspec spec/block_spec.rb

# Run specific test by line number
bundle exec rspec spec/blockchain_spec.rb:10
```

## Architecture

### Core Data Models

The application uses Mongoid ODM with a parent-child relationship between Blockchain and Block:

**Blockchain** (`src/blockchain.rb`)
- Contains a collection of blocks (has_many :blocks)
- Automatically creates a genesis block on initialization (after_create hook)
- Validates chain integrity by checking hash consistency between consecutive blocks
- Prevents adding blocks if chain integrity is compromised

**Block** (`src/block.rb`)
- Belongs to a blockchain (belongs_to :blockchain)
- Contains: index, data, previous_hash, and calculated _hash
- Hash is calculated before validation using SHA256 of: index + timestamp + data + previous_hash
- Provides data validation by recalculating hash and comparing with stored _hash

### API Endpoints

The Sinatra application (`main.rb`) exposes three endpoints:

1. `POST /chain` - Creates a new blockchain with genesis block
2. `POST /chain/:id/block` - Adds a block with provided data to specified chain
3. `POST /chain/:id/block/:block_id/valid` - Validates if provided data matches the block's stored hash

### Database Configuration

MongoDB connection is configured via `config/mongoid.yml` and uses environment variables:
- `MONGO_DB_NAME` - Database name
- `MONGO_DB_HOST` - MongoDB host
- `MONGO_DB_PORT` - MongoDB port
- `ENVIRONMENT` - Rails environment (development/test)

Environment variables should be defined in `.env` for development and `.env.test` for testing.

### Key Implementation Details

- Blocks automatically calculate their hash on validation (before_validation callback)
- The genesis block always has index 0, data "Genesis Block", and previous_hash "0"
- Chain integrity validation checks that each block's previous_hash matches the prior block's hash AND that the current block's stored hash matches its calculated hash
- The Block model uses `field :_hash, type: String, as: :hash` to avoid conflicts with Ruby's hash method
- Adding a block fails if the blockchain's integrity is invalid

## Development Guidelines

When contributing to this project:

1. **Maintain Educational Value**: Keep code readable and well-commented for learning purposes
2. **Test Coverage**: All new features must include RSpec tests
3. **Simplicity First**: Prefer clear, simple implementations over complex optimizations
4. **Documentation**: Update README.md and CLAUDE.md when adding features
5. **No Production Shortcuts**: Even though this is educational, implement features correctly (no mocking security, etc.)
