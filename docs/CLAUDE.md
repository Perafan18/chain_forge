# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

**This is an educational side project** - ChainForge is a learning-focused blockchain implementation NOT intended for production use. The goal is to understand blockchain fundamentals through hands-on implementation.

### Project Goals
- Demonstrate core blockchain concepts (hashing, chain validation, immutability, Proof of Work)
- Provide a clean, well-tested Ruby codebase for learning
- Implement professional features (PoW, API security, testing, CI/CD) as learning exercises
- Maintain simplicity and educational value while improving code quality
- Follow software engineering best practices (testing, linting, documentation)

## Project Overview

ChainForge is a blockchain implementation built with Ruby, Sinatra, and MongoDB. It provides a versioned RESTful API (`/api/v1`) for creating blockchain instances, mining blocks with Proof of Work, and validating block data integrity. Version 2 adds professional features like rate limiting, input validation, CI/CD, and comprehensive testing infrastructure.

## Development Environment

### Core Dependencies
- **Ruby version**: 3.2.2 (managed via rbenv)
- **Database**: MongoDB (via Mongoid ODM 7.0.5)
- **Web framework**: Sinatra 4.0 with sinatra-contrib (namespace support)
- **Testing**: RSpec 3.10 with SimpleCov coverage reporting
- **Code Quality**: RuboCop 1.57 with rubocop-rspec
- **Security**: Rack::Attack 6.7 for rate limiting
- **Validation**: dry-validation 1.10 for input validation
- **Environment**: dotenv 2.7 for configuration management
- **CI/CD**: GitHub Actions

### Version 2 Features
- ✅ **Proof of Work (PoW)**: Mining algorithm with configurable difficulty (1-10)
- ✅ **API Versioning**: All endpoints under `/api/v1` namespace
- ✅ **Rate Limiting**: Rack::Attack protection (60 req/min, configurable per endpoint)
- ✅ **Input Validation**: dry-validation with detailed error messages
- ✅ **Environment Configuration**: DEFAULT_DIFFICULTY and other env vars
- ✅ **CI/CD Pipeline**: GitHub Actions with RuboCop + RSpec
- ✅ **Code Quality Tools**: RuboCop linting, SimpleCov coverage (>90%)

## Essential Commands

### Setup
```bash
# Install Ruby version
rbenv install 3.2.2
rbenv local 3.2.2

# Install dependencies
bundle install

# Configure environment
cp .env.example .env
# Edit .env and set DEFAULT_DIFFICULTY, MongoDB config, etc.
```

### Running the Application
```bash
# Local development (requires MongoDB running)
ruby main.rb -p 1910

# Docker (includes MongoDB with proper networking)
docker-compose up

# Docker (detached mode)
docker-compose up -d
```

### Testing
```bash
# Run all tests
bundle exec rspec

# Run with coverage report
COVERAGE=true bundle exec rspec

# View coverage report
open coverage/index.html

# Run specific test file
bundle exec rspec spec/blockchain_spec.rb
bundle exec rspec spec/block_spec.rb
bundle exec rspec spec/api_spec.rb

# Run specific test by line number
bundle exec rspec spec/blockchain_spec.rb:10
```

### Code Quality
```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix RuboCop violations
bundle exec rubocop -a

# Check specific files
bundle exec rubocop main.rb src/

# Full CI pipeline (locally)
bundle exec rubocop && COVERAGE=true bundle exec rspec
```

## Architecture

### Core Data Models

The application uses Mongoid ODM with a parent-child relationship between Blockchain and Block:

**Blockchain** (`src/blockchain.rb`)
- Contains a collection of blocks (`has_many :blocks`)
- Automatically creates a genesis block on initialization (`after_create` hook)
- Genesis block is NOT mined (to speed up blockchain creation)
- Validates chain integrity by checking:
  1. Hash links between consecutive blocks (previous_hash matches)
  2. Each block's calculated hash matches its stored hash
  3. Each block's hash meets its difficulty requirement (`valid_hash?`)
- Prevents adding blocks if chain integrity is compromised
- `add_block` method mines blocks using Proof of Work before saving

**Block** (`src/block.rb`)
- Belongs to a blockchain (`belongs_to :blockchain`)
- **Fields**: index, data, previous_hash, _hash, nonce, difficulty, timestamps
- **Hash Calculation**: SHA256 of `index + timestamp + data + previous_hash + nonce`
- **Mining** (`mine_block`): Increments nonce until hash starts with N zeros (N = difficulty)
- **Validation** (`valid_hash?`): Verifies hash meets difficulty requirement
- **Data Validation** (`valid_data?`): Recalculates hash and compares with stored _hash
- Hash is calculated before validation using `before_validation` callback
- Default difficulty read from `ENV['DEFAULT_DIFFICULTY']` (defaults to 2)
- Immutable once created (hash + PoW verification prevents tampering)

### API Endpoints

The Sinatra application (`main.rb`) exposes versioned endpoints under `/api/v1` namespace:

**All endpoints are protected by:**
- Rate limiting (Rack::Attack) - Returns 429 when exceeded
- Input validation (dry-validation) - Returns 400 with detailed errors on failure
- Content type enforcement (JSON)

**Endpoints:**

1. **POST /api/v1/chain** - Creates a new blockchain with genesis block
   - Rate limit: 10 requests/minute per IP
   - Returns: `{"id": "blockchain_id"}`

2. **POST /api/v1/chain/:id/block** - Mines and adds a block to the chain
   - Rate limit: 30 requests/minute per IP
   - Request body: `{"data": "string", "difficulty": integer (optional, 1-10)}`
   - Validates input via `BlockDataContract`
   - Uses `DEFAULT_DIFFICULTY` env var if difficulty not provided
   - Mines block (PoW) before saving
   - Returns: `{"chain_id", "block_id", "block_hash", "nonce", "difficulty"}`

3. **GET /api/v1/chain/:id/block/:block_id** - Retrieves block details
   - No rate limit beyond global 60 req/min
   - Returns: Complete block info including mining data (nonce, difficulty, valid_hash)

4. **POST /api/v1/chain/:id/block/:block_id/valid** - Validates block data
   - Request body: `{"data": "string"}`
   - Returns: `{"chain_id", "block_id", "valid": boolean}`

**Root endpoint:**
- `GET /` - Returns "Hello to ChainForge!" (HTML, not JSON)

### Security & Validation

**Rate Limiting** (`config/rack_attack.rb`)
- Implemented via Rack::Attack middleware
- Disabled in test environment (`ENV['ENVIRONMENT'] == 'test'`)
- Three throttles:
  1. Global: 60 requests/minute per IP (all endpoints)
  2. Chain creation: 10 requests/minute per IP (POST /api/v1/chain)
  3. Block creation: 30 requests/minute per IP (POST /api/v1/chain/:id/block)
- Returns 429 status with JSON error on limit exceeded
- Memory-based (resets on restart) - not suitable for distributed systems

**Input Validation** (`src/validators.rb`)
- Uses dry-validation for schema validation
- `BlockDataContract`:
  - `data`: required, must be filled string
  - `difficulty`: optional, must be integer between 1 and 10
- Returns 400 status with structured errors: `{"errors": {"field": ["message"]}}`
- Validation happens before mining (saves CPU if invalid)

### Database Configuration

MongoDB connection is configured via `config/mongoid.yml` and uses environment variables:
- `MONGO_DB_NAME` - Database name (chain_forge / chain_forge_test)
- `MONGO_DB_HOST` - MongoDB host (localhost / mongodb service in Docker)
- `MONGO_DB_PORT` - MongoDB port (27017)
- `ENVIRONMENT` - Runtime environment (development / test / production)
- `DEFAULT_DIFFICULTY` - Default mining difficulty 1-10 (defaults to 2)

Environment variables:
- Development: `.env` file (NOT tracked in git, use `.env.example` as template)
- Test: `.env.test` file (tracked in git)
- Production: Set environment variables directly (Docker, Heroku, etc.)

### Key Implementation Details

**Proof of Work:**
- Blocks are mined by incrementing nonce until hash meets difficulty target
- Target: Hash must start with N leading zeros (N = difficulty)
- Mining is computationally expensive (difficulty 5+ can take minutes)
- Genesis blocks are NOT mined (difficulty ignored for index 0)
- Difficulty can be:
  1. Specified per-block via API (validated 1-10)
  2. Uses DEFAULT_DIFFICULTY env var if not specified
  3. Defaults to 2 if env var not set

**Chain Integrity:**
- Validation now includes three checks:
  1. `previous_hash` matches prior block's `_hash`
  2. Current block's `_hash` matches its calculated hash
  3. Current block's `_hash` meets difficulty requirement (`valid_hash?`)
- Adding a block fails if any integrity check fails

**Block Model:**
- Uses `field :_hash, type: String, as: :hash` to avoid conflicts with Ruby's hash method
- Accesses hash via `block._hash` in code, `block.hash` in MongoDB
- Uses `field :difficulty, default: -> { ENV.fetch('DEFAULT_DIFFICULTY', '2').to_i }`
- Lambda ensures environment is read at runtime, not parse time

**API Response Formats:**
- Success (200): JSON with requested data
- Validation Error (400): `{"errors": {"field": ["message", ...]}}`
- Not Found (404): Default Sinatra error handling
- Unprocessable (422): Used for difficulty validation (deprecated in v2, now uses 400)
- Rate Limit (429): `{"error": "Rate limit exceeded. Please try again later."}`
- Server Error (500): Default Sinatra error handling

**Helpers:**
- `parse_json_body`: Parses request body as JSON
- `find_block_chain`: Finds blockchain by ID, raises if not found

## Development Guidelines

When contributing to this project:

1. **Maintain Educational Value**:
   - Keep code readable and well-commented for learning purposes
   - Explain "why" in comments, not just "what"
   - Demonstrate concepts clearly
   - Prioritize clarity over performance optimizations

2. **Test Coverage**:
   - All new features MUST include RSpec tests
   - Maintain >90% test coverage (tracked by SimpleCov)
   - Test happy paths AND error cases
   - Run `COVERAGE=true bundle exec rspec` before committing
   - Current: 17 examples, 0 failures

3. **Code Quality**:
   - Follow RuboCop style guidelines (`.rubocop.yml`)
   - Run `bundle exec rubocop` before committing
   - Auto-fix when possible: `bundle exec rubocop -a`
   - All PRs must pass RuboCop checks (enforced by CI)

4. **Simplicity First**:
   - Prefer clear, simple implementations over complex optimizations
   - This is a learning project, not a performance benchmark
   - Document any complex algorithms (e.g., Proof of Work)

5. **Documentation**:
   - Update README.md when adding user-facing features
   - Update CLAUDE.md when changing architecture/development workflow
   - Update CHANGELOG.md for all changes
   - Add inline code comments for complex logic

6. **No Production Shortcuts**:
   - Even though this is educational, implement features correctly
   - No mocking security features (rate limiting, validation)
   - Use real MongoDB (not in-memory)
   - Proper error handling

7. **API Versioning**:
   - ALL new endpoints must be under `/api/v1` namespace
   - Use Sinatra `namespace '/api/v1'` blocks
   - Never add endpoints to root path (except GET /)

8. **Environment Configuration**:
   - Use environment variables for ALL configuration
   - Never hardcode values (ports, database names, difficulty, etc.)
   - Provide sensible defaults with `ENV.fetch('VAR', 'default')`
   - Document new env vars in README.md and .env.example

9. **Security & Validation**:
   - All public endpoints must have rate limiting
   - All user inputs must be validated (dry-validation contracts)
   - Return proper HTTP status codes (400, 422, 429, etc.)
   - Include detailed error messages for debugging

10. **CI/CD**:
    - All PRs must pass GitHub Actions checks
    - Pipeline runs: RuboCop + RSpec with MongoDB service
    - No merging without green CI
    - Fix linting issues, don't disable cops (unless justified)

## Testing Strategy

### Test Organization
- `spec/block_spec.rb` - Block model unit tests (hashing, mining, validation)
- `spec/blockchain_spec.rb` - Blockchain model tests (integrity, add_block, genesis)
- `spec/api_spec.rb` - API integration tests (all endpoints, error cases)

### Test Environment
- Uses `.env.test` configuration
- Separate test database: `chain_forge_test`
- Rate limiting DISABLED in tests (for speed and reliability)
- SimpleCov tracks coverage (aim for >90%)

### Testing Best Practices
- Test behavior, not implementation
- Use descriptive test names
- Test edge cases (empty data, invalid difficulty, etc.)
- Test error handling (404, 400, 429)
- Mock/stub external dependencies only when necessary
- Keep tests fast (use difficulty 1-2 for mining tests)

## CI/CD Pipeline

### GitHub Actions Workflow
Location: `.github/workflows/ci.yml`

**Triggers:**
- Every push to any branch
- Every pull request

**Jobs:**
1. **Lint**: Runs RuboCop style checks
2. **Test**: Runs RSpec test suite with MongoDB service

**MongoDB Service:**
- Runs in Docker container
- Configured for test environment
- Matches `.env.test` configuration

**Failure Handling:**
- PR cannot be merged if CI fails
- Fix linting issues or tests before merge
- Check GitHub Actions logs for details

## Common Development Tasks

### Adding a New Endpoint
1. Add route in `namespace '/api/v1'` block in `main.rb`
2. Add rate limiting rule in `config/rack_attack.rb`
3. Create validation contract in `src/validators.rb` (if needed)
4. Add tests in `spec/api_spec.rb`
5. Update README.md API Reference
6. Update API_DOCUMENTATION.md
7. Run tests and RuboCop

### Modifying Block/Blockchain Models
1. Update model in `src/block.rb` or `src/blockchain.rb`
2. Update tests in `spec/block_spec.rb` or `spec/blockchain_spec.rb`
3. Consider migration impact (MongoDB schema changes)
4. Update documentation (README.md Architecture section)
5. Run tests to ensure backward compatibility

### Changing Environment Variables
1. Update `.env.example` with new var and comment
2. Update `.env.test` if test-specific
3. Update `README.md` Configuration section
4. Update `CLAUDE.md` (this file)
5. Update code to use `ENV.fetch('VAR', 'default')`

### Adjusting Rate Limits
1. Edit `config/rack_attack.rb`
2. Update README.md Rate Limiting table
3. Update API_DOCUMENTATION.md
4. Consider impact on user experience
5. Test with actual API calls

## Troubleshooting

### Common Issues

**MongoDB Connection Errors**
- Ensure MongoDB is running: `docker-compose up -d mongodb`
- Check `.env` has correct MONGO_DB_HOST, PORT, NAME
- For Docker: use `host: mongodb` not `localhost`

**Rate Limiting in Tests**
- Ensure `.env.test` has `ENVIRONMENT=test`
- Check `main.rb` has: `use Rack::Attack unless ENV['ENVIRONMENT'] == 'test'`
- Rate limiting should be disabled in test environment

**RuboCop Failures**
- Run `bundle exec rubocop -a` to auto-fix
- Check `.rubocop.yml` for project-specific rules
- Don't disable cops without good reason
- Add `# rubocop:disable CopName` comment only when necessary

**Mining Takes Too Long**
- Use lower difficulty in development (1-3)
- Set `DEFAULT_DIFFICULTY=2` in `.env`
- Avoid difficulty >5 in tests
- Consider mocking `mine_block` in tests (with caution)

**SimpleCov Not Generating Report**
- Run with: `COVERAGE=true bundle exec rspec`
- Check `coverage/` directory is created
- Check `.gitignore` includes `/coverage`
- Coverage only generated when explicitly enabled

## Project Structure

```
chain_forge/
├── .env.example          # Environment variable template
├── .env.test            # Test environment configuration
├── .rubocop.yml         # RuboCop linting rules
├── Gemfile              # Ruby dependencies
├── docker-compose.yml   # Docker configuration
├── main.rb              # Sinatra application (API endpoints)
├── config/
│   ├── mongoid.yml      # MongoDB configuration
│   └── rack_attack.rb   # Rate limiting rules
├── src/
│   ├── blockchain.rb    # Blockchain model
│   ├── block.rb         # Block model with PoW
│   └── validators.rb    # dry-validation contracts
├── spec/
│   ├── api_spec.rb      # API integration tests
│   ├── blockchain_spec.rb # Blockchain model tests
│   ├── block_spec.rb    # Block model tests
│   └── spec_helper.rb   # RSpec configuration
├── .github/
│   └── workflows/
│       └── ci.yml       # GitHub Actions CI pipeline
└── docs/
    ├── README.md        # Main user documentation
    ├── CLAUDE.md        # This file (Claude Code guidance)
    ├── CHANGELOG.md     # Version history
    ├── CONTRIBUTING.md  # Contribution guidelines
    ├── SECURITY.md      # Security policies
    ├── API_DOCUMENTATION.md  # Complete API reference
    └── DEPLOYMENT.md    # Production deployment guide
```

## Educational Objectives

This project demonstrates:
1. **Blockchain Fundamentals**: Hash linking, chain validation, immutability
2. **Proof of Work**: Mining algorithm, difficulty adjustment, computational security
3. **Cryptographic Hashing**: SHA256, hash collisions (practical impossibility)
4. **API Design**: RESTful principles, versioning, error handling
5. **Security**: Rate limiting, input validation, attack prevention
6. **Testing**: Unit tests, integration tests, coverage reporting
7. **Code Quality**: Linting, style enforcement, maintainability
8. **CI/CD**: Automated testing, continuous integration
9. **Ruby/Sinatra**: Web framework, routing, middleware
10. **MongoDB/Mongoid**: NoSQL databases, ODM patterns, document modeling

## Differences from Production Blockchains

ChainForge is educational and differs from production blockchains in:

**Simplified:**
- No peer-to-peer networking (single server)
- No distributed consensus (no other nodes)
- Fixed difficulty (no dynamic adjustment)
- Single SHA256 (Bitcoin uses double SHA256)
- No merkle trees (transactions not grouped)
- No block rewards or mining incentives
- No transaction signing or public/private keys
- No mempool or transaction queuing

**Educational Focus:**
- Demonstrates core concepts clearly
- Keeps code readable and understandable
- Prioritizes learning over performance
- Well-documented and tested
- Suitable for studying blockchain fundamentals

**Not Suitable For:**
- Production use
- Cryptocurrency implementation
- High-value data storage
- Distributed systems
- Public blockchain networks

Use this project to learn blockchain concepts, then study real implementations (Bitcoin, Ethereum) to understand production complexity.
