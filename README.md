# ChainForge

> **Educational Blockchain Implementation** - Learn blockchain fundamentals through hands-on development with Ruby, Sinatra, and MongoDB.

[![Ruby](https://img.shields.io/badge/Ruby-3.2.2-red.svg)](https://www.ruby-lang.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-Latest-green.svg)](https://www.mongodb.com/)
[![Sinatra](https://img.shields.io/badge/Sinatra-4.0-blue.svg)](http://sinatrarb.com/)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-brightgreen.svg)](https://github.com/Perafan18/chain_forge/actions)

A blockchain implementation with Proof of Work mining, REST API, and comprehensive security features. ChainForge demonstrates core blockchain concepts including cryptographic hashing, chain validation, and immutability through a clean, well-tested Ruby codebase.

## Features

- ✅ **Proof of Work Mining** - Configurable difficulty (1-10)
- ✅ **RESTful API** - Versioned endpoints (`/api/v1`)
- ✅ **Chain Integrity** - SHA256 hashing and validation
- ✅ **Security** - Rate limiting, input validation
- ✅ **Well-Tested** - RSpec tests with >90% coverage
- ✅ **CI/CD** - Automated testing and linting

## Quick Start

### Prerequisites

- Ruby 3.2.2
- MongoDB
- Docker (optional)

### Installation

```bash
# Clone repository
git clone https://github.com/Perafan18/chain_forge.git
cd chain_forge

# Install dependencies
bundle install

# Configure environment
cp .env.example .env

# Start MongoDB (or use Docker)
brew services start mongodb-community  # macOS
# Or: docker-compose up -d db

# Run application
ruby main.rb -p 1910
```

### Using Docker (Recommended)

```bash
docker-compose up
```

Application will be available at <http://localhost:1910>

### Your First Blockchain

```bash
# Create blockchain
curl -X POST http://localhost:1910/api/v1/chain
# Returns: {"id":"674c8a1b2e4f5a0012345678"}

# Mine a block
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Hello, Blockchain!", "difficulty": 2}'

# Returns: {
#   "chain_id": "674c8a1b2e4f5a0012345678",
#   "block_id": "674c8b2c3e5f6a0012345679",
#   "block_hash": "00a1b2c3d4e5f6789...",
#   "nonce": 142,
#   "difficulty": 2
# }
```

## Documentation

Comprehensive documentation is available in the [`docs/`](docs/) folder:

### Getting Started
- **[Installation Guide](docs/getting-started/installation.md)** - Detailed setup instructions
- **[Quick Start Tutorial](docs/getting-started/quick-start.md)** - Create your first blockchain in 5 minutes
- **[First Blockchain Tutorial](docs/getting-started/first-blockchain-tutorial.md)** - Complete walkthrough with mining

### Architecture & Design
- **[System Overview](docs/architecture/overview.md)** - High-level architecture and data flow
- **[Proof of Work Deep Dive](docs/architecture/proof-of-work.md)** - Mining algorithm explained
- **[Data Models](docs/architecture/data-models.md)** - MongoDB schema and relationships
- **[Security Design](docs/architecture/security-design.md)** - Security layers and threat model

### API Documentation
- **[API Reference](docs/api/reference.md)** - Complete endpoint documentation
- **[Code Examples](docs/api/examples.md)** - Integration examples (Python, JavaScript, Ruby, curl)
- **[Rate Limiting](docs/api/rate-limiting.md)** - Understanding and handling rate limits

### Developer Guides
- **[Development Setup](docs/guides/development-setup.md)** - Complete development environment guide
- **[Testing Guide](docs/guides/testing-guide.md)** - RSpec, coverage, and CI/CD
- **[Deployment Guide](docs/guides/deployment-guide.md)** - Production deployment
- **[Troubleshooting](docs/guides/troubleshooting.md)** - Common issues and solutions

### Project Information
- **[CHANGELOG](docs/CHANGELOG.md)** - Version history
- **[CONTRIBUTING](docs/CONTRIBUTING.md)** - How to contribute
- **[SECURITY](docs/SECURITY.md)** - Security policies
- **[CLAUDE](docs/CLAUDE.md)** - Claude Code development guide

## API Endpoints

All endpoints are prefixed with `/api/v1`:

| Endpoint | Method | Description | Rate Limit |
|----------|--------|-------------|-----------|
| `/chain` | POST | Create new blockchain | 10/min |
| `/chain/:id/block` | POST | Mine and add block | 30/min |
| `/chain/:id/block/:block_id` | GET | Get block details | 60/min |
| `/chain/:id/block/:block_id/valid` | POST | Validate block data | 60/min |

See [API Reference](docs/api/reference.md) for complete documentation.

## Development

### Run Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec

# View coverage report
open coverage/index.html
```

### Code Quality

```bash
# Run linter
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a
```

### CI/CD

GitHub Actions runs automatically on push and PR:
- ✅ RuboCop linting
- ✅ RSpec test suite
- ✅ Coverage reporting

## Educational Project

ChainForge is designed for learning blockchain fundamentals and is **NOT intended for production use**.

**Learn:**
- ✅ Blockchain concepts (hashing, chain validation, immutability)
- ✅ Proof of Work mining algorithm
- ✅ API security (rate limiting, input validation)
- ✅ Ruby/Sinatra development
- ✅ MongoDB/Mongoid ODM
- ✅ Testing and CI/CD best practices

**Do NOT use for:**
- ❌ Production applications
- ❌ Cryptocurrency implementation
- ❌ Storing valuable data
- ❌ Distributed systems

For production blockchains, study Bitcoin or Ethereum implementations.

## Contributing

Contributions are welcome! This is a learning project focused on understanding blockchain fundamentals.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Write tests for your changes
4. Ensure tests pass (`bundle exec rspec`)
5. Ensure code quality (`bundle exec rubocop`)
6. Commit your changes (`git commit -m 'feat: Add my feature'`)
7. Push to the branch (`git push origin feature/my-feature`)
8. Open a Pull Request

See [CONTRIBUTING](docs/CONTRIBUTING.md) for detailed guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Built as a learning exercise to understand blockchain technology fundamentals. Special thanks to the blockchain community for educational resources and inspiration.

## Version

**Current Version:** 2.0.0

See [CHANGELOG](docs/CHANGELOG.md) for version history.

---

**Ready to start?** Check out the [Quick Start Tutorial](docs/getting-started/quick-start.md)!
