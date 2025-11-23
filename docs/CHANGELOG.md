# Changelog

All notable changes to ChainForge will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Block explorer web interface
- Dynamic difficulty adjustment
- Advanced metrics and monitoring

## [2.0.0] - 2025-11-09

### Added

#### Proof of Work (PR #4)
- **Mining Algorithm**: Implemented PoW consensus mechanism
  - `nonce` field for mining iterations
  - `difficulty` field (1-10) for hash target configuration
  - `mine_block` method implements incremental nonce search
  - `valid_hash?` method verifies PoW compliance
- **API Support**: Optional `difficulty` parameter in block creation endpoint
- **Performance**: Mining time scales with difficulty (1-2: instant, 5+: minutes)

#### API Versioning (PR #5)
- **Namespace**: All endpoints moved to `/api/v1`
- **New Endpoint**: `GET /api/v1/chain/:id/block/:block_id` retrieves block details
- **Future-proof**: Enables API evolution without breaking changes
- **Responses**: Include PoW fields (nonce, difficulty, valid_hash)

#### API Security (PR #6)
- **Rate Limiting**: Rack::Attack middleware protection
  - Global: 60 requests/minute per IP
  - Chain creation: 10 requests/minute per IP
  - Block creation: 30 requests/minute per IP
  - Returns 429 status when exceeded
- **Input Validation**: dry-validation with detailed error messages
  - `data` field must be non-empty string
  - `difficulty` must be integer between 1-10
  - Returns 400 status with structured errors

#### Environment Configuration (PR #7)
- **Template**: `.env.example` file for easy setup
- **DEFAULT_DIFFICULTY**: Configurable mining difficulty via environment variable
- **Security**: Removed `.env` from git tracking
- **Documentation**: Environment variable reference in README

#### Testing Infrastructure (PR #2)
- **RuboCop**: Style enforcement with rubocop-rspec plugin
- **SimpleCov**: Test coverage reporting (>90% coverage)
- **Configuration**: `.rubocop.yml` with project-specific rules
- **Test Database**: Separate `chain_forge_test` database

#### CI/CD Pipeline (PR #3)
- **GitHub Actions**: Automated testing on every push and PR
- **Checks**: RuboCop linting + RSpec test suite
- **MongoDB**: Service container for integration tests
- **Quality Gates**: PRs cannot merge without passing CI

#### Documentation (PR #1 & #8)
- **README**: Complete v2 feature documentation with PoW explanation
- **CLAUDE.md**: Claude Code guidance with v2 architecture
- **CHANGELOG.md**: This file, version history tracking
- **CONTRIBUTING.md**: Contribution guidelines and workflow
- **SECURITY.md**: Security policies and best practices
- **docs/api/reference.md**: Complete API reference with examples
- **docs/guides/deployment-guide.md**: Production deployment guide

### Changed
- **Block Hash**: Now includes nonce in hash calculation
- **Chain Validation**: Added PoW verification (`valid_hash?` check)
- **Block Creation**: Mining process adds computational delay
- **API Responses**: Include mining information (nonce, difficulty, valid_hash)
- **Genesis Blocks**: Use DEFAULT_DIFFICULTY from environment

### Breaking Changes
- **API Namespace**: All endpoints moved from `/` to `/api/v1/`
  - Old: `POST /chain`
  - New: `POST /api/v1/chain`
- **Mining Delay**: Block creation now requires PoW mining (may take seconds/minutes)
- **Response Format**: Block responses include new fields (nonce, difficulty, valid_hash)
- **Environment**: DEFAULT_DIFFICULTY must be configured (defaults to 2)

### Migration Guide
1. Update all API calls to use `/api/v1` prefix
2. Copy `.env.example` to `.env` and configure DEFAULT_DIFFICULTY
3. Update client code to handle new response fields (nonce, difficulty)
4. Expect longer block creation times due to mining
5. Handle new error responses (400 validation, 429 rate limit)

## [1.0.0] - 2025-11-08

### Added
- **Blockchain Implementation**: Core blockchain data structure
- **Block Model**: SHA256 hashing with chain linking
- **REST API**: Sinatra-based HTTP API
  - `POST /chain` - Create blockchain
  - `POST /chain/:id/block` - Add block
  - `POST /chain/:id/block/:block_id/valid` - Validate block
- **MongoDB Persistence**: Mongoid ODM integration
- **Chain Validation**: Integrity checking via hash verification
- **Genesis Block**: Auto-generation on blockchain creation
- **Docker Support**: docker-compose configuration
- **Testing**: RSpec test suite
- **Documentation**: Basic README with setup instructions

### Core Features
- Cryptographic hashing (SHA256)
- Immutable chain structure
- Hash-based tamper detection
- RESTful API design
- MongoDB document storage

## Release Notes

### v2.0.0 - Major Update
This release transforms ChainForge from a basic blockchain implementation to a professional-grade educational project. Key highlights:

**🔨 Proof of Work**: Experience real blockchain mining with configurable difficulty
**🔒 Security**: Industry-standard rate limiting and input validation
**📦 API Versioning**: Future-proof API design with v1 namespace
**✅ Quality**: 90%+ test coverage with automated CI/CD
**📚 Documentation**: Comprehensive guides for users and contributors

**Upgrade Impact**: This is a breaking release. API endpoints have moved to `/api/v1` and block creation now requires mining. See Migration Guide above.

### v1.0.0 - Initial Release
First public release of ChainForge. Provides core blockchain functionality with REST API and MongoDB persistence. Educational implementation demonstrating blockchain fundamentals.

## Links

- [Repository](https://github.com/Perafan18/chain_forge)
- [Issues](https://github.com/Perafan18/chain_forge/issues)
- [Pull Requests](https://github.com/Perafan18/chain_forge/pulls)

## Versioning

We use [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes (API changes, behavior changes)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)
