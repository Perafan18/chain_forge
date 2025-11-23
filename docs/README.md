# ChainForge Documentation

Welcome to the complete documentation for ChainForge, an educational blockchain implementation built with Ruby, Sinatra, and MongoDB.

## Quick Navigation

### Getting Started
- [Installation Guide](getting-started/installation.md) - Set up your development environment
- [Quick Start Tutorial](getting-started/quick-start.md) - Get your first blockchain running in 5 minutes
- [First Blockchain Tutorial](getting-started/first-blockchain-tutorial.md) - Complete walkthrough with mining examples

### Architecture & Design
- [System Overview](architecture/overview.md) - High-level architecture and data flow
- [Proof of Work Deep Dive](architecture/proof-of-work.md) - Understanding the mining algorithm
- [Data Models](architecture/data-models.md) - MongoDB schema and relationships
- [Security Design](architecture/security-design.md) - Rate limiting, validation, and security layers

### API Documentation
- [API Reference](api/reference.md) - Complete endpoint documentation with examples
- [Code Examples](api/examples.md) - Integration examples in multiple languages
- [Rate Limiting](api/rate-limiting.md) - Understanding rate limits and quotas

### Developer Guides
- [Development Setup](guides/development-setup.md) - Complete development environment guide
- [Testing Guide](guides/testing-guide.md) - RSpec, coverage, and CI/CD
- [Deployment Guide](guides/deployment-guide.md) - Docker and production deployment
- [Troubleshooting](guides/troubleshooting.md) - Common issues and solutions

### Project Information
- [CHANGELOG](CHANGELOG.md) - Version history and release notes
- [CONTRIBUTING](CONTRIBUTING.md) - How to contribute to the project
- [SECURITY](SECURITY.md) - Security policies and vulnerability reporting
- [CLAUDE](CLAUDE.md) - Claude Code development guidance

## What is ChainForge?

ChainForge is an **educational blockchain implementation** designed to help developers understand core blockchain concepts through hands-on implementation. It demonstrates:

- **Cryptographic Hashing**: SHA256-based block linking
- **Proof of Work**: Mining algorithm with configurable difficulty
- **Chain Integrity**: Validation and immutability
- **API Security**: Rate limiting and input validation
- **Modern Development**: Testing, linting, and CI/CD

### Current Version: 2.0.0

ChainForge v2 includes:
- ✅ Proof of Work (PoW) mining with difficulty 1-10
- ✅ Versioned REST API (`/api/v1`)
- ✅ Rate limiting (Rack::Attack)
- ✅ Input validation (dry-validation)
- ✅ Environment configuration
- ✅ GitHub Actions CI/CD
- ✅ Comprehensive test coverage

## Educational Project Notice

> **Important**: ChainForge is a learning-focused project and is NOT intended for production use. It demonstrates blockchain fundamentals but lacks many features required for production systems (authentication, encryption, distributed consensus, P2P networking, etc.).

Use ChainForge to:
- ✅ Learn blockchain fundamentals
- ✅ Understand Proof of Work
- ✅ Experiment with mining algorithms
- ✅ Study API security patterns
- ✅ Practice Ruby development

Do NOT use ChainForge for:
- ❌ Production applications
- ❌ Cryptocurrency implementation
- ❌ Storing valuable data
- ❌ Distributed systems

## Quick Links

### For New Users
1. [Installation Guide](getting-started/installation.md) - Install prerequisites and dependencies
2. [Quick Start](getting-started/quick-start.md) - Run your first blockchain in 5 minutes
3. [API Reference](api/reference.md) - Start making API calls

### For Developers
1. [Development Setup](guides/development-setup.md) - Configure your dev environment
2. [Testing Guide](guides/testing-guide.md) - Write and run tests
3. [Architecture Overview](architecture/overview.md) - Understand the system design

### For Contributors
1. [CONTRIBUTING](CONTRIBUTING.md) - Contribution guidelines
2. [Development Setup](guides/development-setup.md) - Set up your fork
3. [Testing Guide](guides/testing-guide.md) - Ensure quality

## Core Concepts

### Blockchain Basics
A **blockchain** is a distributed ledger of transactions organized into blocks. Each block contains:
- Data (transactions or information)
- A cryptographic hash of the previous block
- A timestamp
- A nonce (number used once)

Blocks are linked together through their hashes, creating an immutable chain where altering any block invalidates all subsequent blocks.

### Proof of Work
**Proof of Work (PoW)** is a consensus mechanism that requires computational work to add blocks to the chain. Miners must find a nonce value that, when hashed with the block data, produces a hash meeting specific criteria (e.g., starting with a certain number of zeros).

This makes it computationally expensive to modify the blockchain, providing security against tampering.

### Chain Integrity
ChainForge validates chain integrity by checking:
1. Each block's hash matches its calculated hash
2. Each block's hash meets its difficulty requirement (PoW)
3. Each block's `previous_hash` matches the prior block's hash

If any check fails, the chain is invalid.

## Technology Stack

- **Language**: Ruby 3.2.2
- **Web Framework**: Sinatra 4.0
- **Database**: MongoDB (via Mongoid ODM)
- **Testing**: RSpec 3.10 + SimpleCov
- **Code Quality**: RuboCop 1.57
- **Security**: Rack::Attack (rate limiting), dry-validation (input validation)
- **CI/CD**: GitHub Actions

## Documentation Structure

This documentation is organized into four main sections:

### 1. Getting Started
Step-by-step tutorials for new users to install, configure, and run ChainForge.

### 2. Architecture & Design
In-depth explanations of system design, data models, algorithms, and security.

### 3. API Documentation
Complete API reference with endpoints, request/response formats, and integration examples.

### 4. Developer Guides
Guides for developers contributing to or deploying ChainForge.

## Getting Help

- **Installation Issues**: See [Troubleshooting Guide](guides/troubleshooting.md)
- **API Questions**: Check [API Reference](api/reference.md)
- **Contributing**: Read [CONTRIBUTING](CONTRIBUTING.md)
- **Security Issues**: Report via [SECURITY](SECURITY.md)

## License

MIT License - See LICENSE file for details.

## Acknowledgments

Built as a learning exercise to understand blockchain technology. Special thanks to the blockchain community for educational resources and inspiration.

---

**Ready to start?** Head to the [Quick Start Tutorial](getting-started/quick-start.md) to create your first blockchain in 5 minutes!
