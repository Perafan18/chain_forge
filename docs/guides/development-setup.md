# Development Setup Guide

Complete guide for setting up a ChainForge development environment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Clone Repository](#clone-repository)
3. [Ruby Setup](#ruby-setup)
4. [MongoDB Setup](#mongodb-setup)
5. [Install Dependencies](#install-dependencies)
6. [Environment Configuration](#environment-configuration)
7. [Database Setup](#database-setup)
8. [Running the Application](#running-the-application)
9. [Running Tests](#running-tests)
10. [Development Workflow](#development-workflow)
11. [IDE Setup](#ide-setup)
12. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

- **Git** - Version control
- **Ruby 3.2.2** - Programming language
- **MongoDB** - Database (latest version)
- **Bundler** - Ruby dependency manager

### Recommended Software

- **rbenv** or **rvm** - Ruby version management
- **Docker** & **Docker Compose** - Containerization (optional)
- **IDE** - RubyMine, VS Code, or Sublime Text
- **curl** or **Postman** - API testing

## Clone Repository

```bash
# Clone via HTTPS
git clone https://github.com/Perafan18/chain_forge.git
cd chain_forge

# Or clone via SSH
git clone git@github.com:Perafan18/chain_forge.git
cd chain_forge

# Create your feature branch
git checkout -b feature/your-feature-name
```

## Ruby Setup

### Using rbenv (Recommended)

**macOS:**
```bash
# Install rbenv
brew install rbenv ruby-build

# Add to shell profile (~/.zshrc or ~/.bash_profile)
echo 'eval "$(rbenv init -)"' >> ~/.zshrc
source ~/.zshrc

# Install Ruby 3.2.2
rbenv install 3.2.2

# Set as local version for project
cd chain_forge
rbenv local 3.2.2

# Verify
ruby -v  # Should show: ruby 3.2.2
```

**Linux:**
```bash
# Install rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# Add to shell profile
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby 3.2.2
rbenv install 3.2.2
rbenv local 3.2.2

# Verify
ruby -v
```

### Using rvm (Alternative)

```bash
# Install rvm
curl -sSL https://get.rvm.io | bash -s stable

# Load rvm
source ~/.rvm/scripts/rvm

# Install Ruby 3.2.2
rvm install 3.2.2
rvm use 3.2.2

# Verify
ruby -v
```

## MongoDB Setup

### macOS

```bash
# Install MongoDB Community Edition
brew tap mongodb/brew
brew install mongodb-community

# Start MongoDB service
brew services start mongodb-community

# Verify MongoDB is running
mongosh --eval "db.version()"

# Stop MongoDB (when needed)
brew services stop mongodb-community
```

### Linux (Ubuntu/Debian)

```bash
# Import MongoDB public key
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Update and install
sudo apt update
sudo apt install -y mongodb-org

# Start MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod  # Start on boot

# Verify
mongosh --eval "db.version()"
```

### Using Docker (Alternative)

```bash
# Start MongoDB only
docker-compose up -d db

# Verify
docker ps  # Should show mongodb container

# MongoDB will be available at localhost:27017
```

## Install Dependencies

```bash
# Install Bundler
gem install bundler

# Install project dependencies
bundle install

# This installs:
# - Sinatra (web framework)
# - Mongoid (MongoDB ODM)
# - RSpec (testing)
# - RuboCop (linting)
# - Rack::Attack (rate limiting)
# - dry-validation (input validation)
# - And more...
```

**Common Issues:**

```bash
# If bundle install fails
gem update --system
gem install bundler
bundle install

# If specific gem fails
bundle config build.<gem-name> --with-<option>
```

## Environment Configuration

### Create Environment File

```bash
# Copy example file
cp .env.example .env
```

### Edit .env File

```bash
# Open in your editor
nano .env  # or vim, code, etc.
```

**Development Configuration:**
```bash
# .env
MONGO_DB_NAME=chain_forge
MONGO_DB_HOST=localhost
MONGO_DB_PORT=27017
ENVIRONMENT=development
DEFAULT_DIFFICULTY=2
```

**Configuration Options:**

| Variable | Description | Development Value | Production Value |
|----------|-------------|------------------|------------------|
| `MONGO_DB_NAME` | Database name | chain_forge | chain_forge_prod |
| `MONGO_DB_HOST` | MongoDB hostname | localhost | mongodb (Docker) or IP |
| `MONGO_DB_PORT` | MongoDB port | 27017 | 27017 |
| `ENVIRONMENT` | Runtime environment | development | production |
| `DEFAULT_DIFFICULTY` | Mining difficulty | 2 | 3-5 |

### Test Environment

```bash
# .env.test already exists - DO NOT modify
cat .env.test

# Contents:
MONGO_DB_NAME=chain_forge_test
MONGO_DB_HOST=localhost
MONGO_DB_PORT=27017
ENVIRONMENT=test
DEFAULT_DIFFICULTY=2
```

## Database Setup

### Verify MongoDB Connection

```bash
# Connect to MongoDB
mongosh

# In MongoDB shell:
use chain_forge
db.stats()
exit
```

### Initialize Database (Optional)

ChainForge automatically creates collections when needed, but you can verify:

```bash
# Start the application
ruby main.rb -p 1910

# In another terminal, create a blockchain
curl -X POST http://localhost:1910/api/v1/chain

# Verify in MongoDB
mongosh
use chain_forge
db.blockchains.find()
db.blocks.find()
exit
```

## Running the Application

### Local Development

```bash
# Start the server
ruby main.rb -p 1910

# Server output:
# == Sinatra (v4.0.0) has taken the stage on 1910 for development
# Puma starting in single mode...
# * Listening on http://0.0.0.0:1910
```

**Options:**
```bash
# Custom port
ruby main.rb -p 3000

# Bind to localhost only
ruby main.rb -p 1910 -o 127.0.0.1

# Verbose mode
ruby main.rb -p 1910 -v
```

### Using Docker

```bash
# Start both app and MongoDB
docker-compose up

# Detached mode
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

### Verify Application

```bash
# Test basic connectivity
curl http://localhost:1910

# Expected: "Hello to ChainForge!"

# Create blockchain
curl -X POST http://localhost:1910/api/v1/chain

# Expected: {"id":"<blockchain_id>"}
```

## Running Tests

### Run All Tests

```bash
# Run entire test suite
bundle exec rspec

# Output:
# 17 examples, 0 failures
```

### Run with Coverage

```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# View report
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
```

### Run Specific Tests

```bash
# Run specific file
bundle exec rspec spec/block_spec.rb

# Run specific test by line number
bundle exec rspec spec/block_spec.rb:10

# Run tests matching description
bundle exec rspec -e "mines a block"
```

### Run Linter

```bash
# Check code style
bundle exec rubocop

# Auto-fix violations
bundle exec rubocop -a

# Check specific files
bundle exec rubocop main.rb src/
```

### Run Full CI Pipeline Locally

```bash
# Same as GitHub Actions
bundle exec rubocop && COVERAGE=true bundle exec rspec
```

## Development Workflow

### Daily Workflow

```bash
# 1. Pull latest changes
git checkout master
git pull origin master

# 2. Create feature branch
git checkout -b feature/my-feature

# 3. Make changes
# ... edit code ...

# 4. Run tests
bundle exec rspec

# 5. Run linter
bundle exec rubocop -a

# 6. Commit changes
git add .
git commit -m "feat: Add my feature"

# 7. Push to GitHub
git push origin feature/my-feature

# 8. Create Pull Request on GitHub
```

### Before Committing

**Checklist:**
- [ ] All tests pass: `bundle exec rspec`
- [ ] No linting errors: `bundle exec rubocop`
- [ ] Coverage maintained: `COVERAGE=true bundle exec rspec`
- [ ] Documentation updated (if needed)
- [ ] CHANGELOG.md updated (if applicable)

### Hot Reloading

Sinatra doesn't reload automatically. Install rerun for auto-reload:

```bash
# Install rerun gem
gem install rerun

# Run with auto-reload
rerun --pattern "**/*.rb" ruby main.rb -p 1910

# Now changes to Ruby files trigger automatic restart
```

## IDE Setup

### RubyMine

**Configuration:**
1. Open project: File → Open → chain_forge/
2. Set Ruby SDK: Preferences → Ruby SDK and Gems → Use rbenv: 3.2.2
3. Set test framework: Preferences → Tools → Test Frameworks → RSpec
4. Enable RuboCop: Preferences → Tools → RuboCop → Enable

**Run Configurations:**
```
Name: ChainForge Server
Script: main.rb
Arguments: -p 1910
Working Directory: /path/to/chain_forge
```

### VS Code

**Extensions:**
- Ruby (Peng Lv)
- Ruby Solargraph (Castwide)
- RuboCop (Misogi)
- MongoDB for VS Code

**Settings (.vscode/settings.json):**
```json
{
  "ruby.useLanguageServer": true,
  "ruby.lint": {
    "rubocop": true
  },
  "ruby.format": "rubocop",
  "[ruby]": {
    "editor.formatOnSave": true
  }
}
```

**Launch Configuration (.vscode/launch.json):**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "ChainForge Server",
      "type": "Ruby",
      "request": "launch",
      "program": "${workspaceRoot}/main.rb",
      "args": ["-p", "1910"]
    },
    {
      "name": "RSpec - all",
      "type": "Ruby",
      "request": "launch",
      "program": "${workspaceRoot}/bin/rspec",
      "args": ["--color", "--format", "documentation"]
    }
  ]
}
```

### Sublime Text

**Packages:**
- Package Control
- RSpec
- SublimeLinter
- SublimeLinter-rubocop

## Troubleshooting

### Ruby Version Issues

**Problem:** Wrong Ruby version

```bash
# Check current version
ruby -v

# If wrong version:
rbenv local 3.2.2
rbenv rehash

# Verify
ruby -v  # Should show 3.2.2
```

### MongoDB Connection Errors

**Problem:** Can't connect to MongoDB

```bash
# Check if MongoDB is running
mongosh --eval "db.version()"

# If not running:
# macOS
brew services start mongodb-community

# Linux
sudo systemctl start mongod

# Docker
docker-compose up -d db
```

**Problem:** Connection refused

```bash
# Check MongoDB port
sudo lsof -iTCP -sTCP:LISTEN -n -P | grep mongod

# Should show port 27017

# Check .env configuration
cat .env | grep MONGO
```

### Bundle Install Failures

**Problem:** gem installation fails

```bash
# Update RubyGems
gem update --system

# Update Bundler
gem install bundler

# Clear cache
bundle clean --force

# Retry
bundle install
```

**Problem:** Native extension build fails

```bash
# Install build tools
# macOS
xcode-select --install

# Linux
sudo apt install build-essential

# Retry
bundle install
```

### Port Already in Use

**Problem:** Port 1910 already taken

```bash
# Find process using port
lsof -ti:1910

# Kill process
kill -9 $(lsof -ti:1910)

# Or use different port
ruby main.rb -p 3000
```

### Test Failures

**Problem:** Tests fail unexpectedly

```bash
# Drop test database
mongosh chain_forge_test --eval "db.dropDatabase()"

# Run tests again
bundle exec rspec
```

### RuboCop Errors

**Problem:** Too many style violations

```bash
# Auto-fix what's possible
bundle exec rubocop -a

# Check remaining issues
bundle exec rubocop

# Fix manually or add exceptions to .rubocop.yml
```

## Next Steps

- [Testing Guide](testing-guide.md) - Comprehensive testing documentation
- [Deployment Guide](deployment-guide.md) - Production deployment
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Contributing](../CONTRIBUTING.md) - How to contribute

---

**Need help?** Open an issue on GitHub or check [Troubleshooting Guide](troubleshooting.md).
