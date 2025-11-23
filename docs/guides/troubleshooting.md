# Troubleshooting Guide

Solutions to common problems encountered when developing with or deploying ChainForge.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [MongoDB Issues](#mongodb-issues)
3. [Ruby Issues](#ruby-issues)
4. [Application Issues](#application-issues)
5. [API Issues](#api-issues)
6. [Testing Issues](#testing-issues)
7. [Docker Issues](#docker-issues)
8. [Performance Issues](#performance-issues)

## Installation Issues

### Problem: bundle install fails

**Symptoms:**
```
An error occurred while installing <gem-name>
```

**Solutions:**

**1. Update RubyGems and Bundler:**
```bash
gem update --system
gem install bundler
bundle install
```

**2. Clear bundle cache:**
```bash
bundle clean --force
rm -rf vendor/bundle
bundle install
```

**3. Install build dependencies:**
```bash
# macOS
xcode-select --install

# Ubuntu/Debian
sudo apt-get install build-essential

# Fedora/RHEL
sudo yum install gcc make
```

**4. Install specific gem manually:**
```bash
gem install <problematic-gem>
bundle install
```

### Problem: Wrong Ruby version

**Symptoms:**
```
Your Ruby version is X.X.X, but your Gemfile specified 3.2.2
```

**Solution:**
```bash
# Using rbenv
rbenv install 3.2.2
rbenv local 3.2.2

# Using rvm
rvm install 3.2.2
rvm use 3.2.2

# Verify
ruby -v  # Should show: ruby 3.2.2
```

### Problem: rbenv not found

**Symptoms:**
```
rbenv: command not found
```

**Solution:**
```bash
# Add to ~/.zshrc or ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.zshrc
source ~/.zshrc

# Or install rbenv
brew install rbenv  # macOS
```

## MongoDB Issues

### Problem: MongoDB connection refused

**Symptoms:**
```
Error connecting to MongoDB: Connection refused
Mongoid::Errors::NoSessionsAvailable
```

**Solutions:**

**1. Check if MongoDB is running:**
```bash
# Check status
mongosh --eval "db.version()"

# If not running, start it:
# macOS
brew services start mongodb-community

# Linux
sudo systemctl start mongod

# Docker
docker-compose up -d db
```

**2. Verify port:**
```bash
# Check if MongoDB listening on 27017
sudo lsof -iTCP -sTCP:LISTEN -n -P | grep 27017

# Or
sudo netstat -tuln | grep 27017
```

**3. Check .env configuration:**
```bash
cat .env
# Should have:
MONGO_DB_HOST=localhost
MONGO_DB_PORT=27017

# For Docker:
MONGO_DB_HOST=mongodb
```

**4. Test connection directly:**
```bash
mongosh "mongodb://localhost:27017"
```

### Problem: MongoDB authentication failed

**Symptoms:**
```
Authentication failed
```

**Solution:**
```bash
# Check if authentication is enabled
mongosh --eval "db.getMongo()"

# If auth enabled, update connection string:
# config/mongoid.yml
uri: mongodb://username:password@localhost:27017/chain_forge
```

### Problem: Database not found

**Symptoms:**
```
Database 'chain_forge' not found
```

**Solution:**
```bash
# MongoDB creates databases automatically on first use
# Just run the app and make a request:

ruby main.rb -p 1910

# In another terminal:
curl -X POST http://localhost:1910/api/v1/chain

# Database will be created
```

### Problem: Collections empty after restart

**Symptoms:**
- Data disappears after MongoDB restart

**Solution:**
```bash
# Check MongoDB data directory
mongosh
use chain_forge
db.blockchains.find()

# If empty, data was lost. Ensure MongoDB is persisting:
# Check mongod.conf for dbPath setting

# For Docker, ensure volume is mounted:
docker-compose.yml should have:
volumes:
  - mongodb_data:/data/db
```

## Ruby Issues

### Problem: LoadError - cannot load such file

**Symptoms:**
```
LoadError: cannot load such file -- sinatra
```

**Solution:**
```bash
# Install dependencies
bundle install

# Or install specific gem
gem install sinatra

# Verify gem installed
bundle list | grep sinatra
```

### Problem: Gem::Ext::BuildError

**Symptoms:**
```
Gem::Ext::BuildError: ERROR: Failed to build gem native extension
```

**Solution:**
```bash
# Install build tools
# macOS
xcode-select --install

# Ubuntu
sudo apt-get install build-essential

# Then retry
bundle install
```

### Problem: Permission denied (gem install)

**Symptoms:**
```
ERROR:  While executing gem ... (Errno::EACCES)
    Permission denied
```

**Solution:**
```bash
# DON'T use sudo with gems!

# Instead, configure bundler for local install
bundle config set --local path 'vendor/bundle'
bundle install

# Gems installed to vendor/bundle/
```

## Application Issues

### Problem: Port already in use

**Symptoms:**
```
Address already in use - bind(2) for "0.0.0.0" port 1910 (Errno::EADDRINUSE)
```

**Solutions:**

**1. Find and kill process:**
```bash
# Find process using port 1910
lsof -ti:1910

# Kill process
kill -9 $(lsof -ti:1910)

# Restart application
ruby main.rb -p 1910
```

**2. Use different port:**
```bash
ruby main.rb -p 3000
```

### Problem: undefined method `id' for nil:NilClass

**Symptoms:**
```
NoMethodError: undefined method `id' for nil:NilClass
```

**Cause:** Trying to access blockchain that doesn't exist

**Solution:**
```bash
# Verify blockchain exists
mongosh chain_forge
db.blockchains.find()

# If not found, create new blockchain
curl -X POST http://localhost:1910/api/v1/chain
```

### Problem: Blockchain is not valid error

**Symptoms:**
```
RuntimeError: Blockchain is not valid
```

**Cause:** Chain integrity compromised (tampered blocks)

**Solution:**
```bash
# Check chain integrity in MongoDB
mongosh chain_forge
db.blocks.find({blockchain_id: ObjectId("...")})

# Look for:
# - Mismatched previous_hash values
# - Invalid hash values
# - Blocks with invalid PoW

# Fix: Delete corrupted blockchain and create new one
db.blockchains.deleteOne({_id: ObjectId("...")})
db.blocks.deleteMany({blockchain_id: ObjectId("...")})
```

### Problem: Application doesn't reload after code changes

**Symptoms:**
- Code changes not reflected in running app

**Solution:**
```bash
# Stop server (Ctrl+C)
# Restart server
ruby main.rb -p 1910

# Or use rerun for auto-reload:
gem install rerun
rerun --pattern "**/*.rb" ruby main.rb -p 1910
```

## API Issues

### Problem: 429 Rate limit exceeded

**Symptoms:**
```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```

**Solution:**
```bash
# Wait 60 seconds for rate limit to reset
sleep 60

# Or restart server to reset in-memory limits
# (Development only - not recommended for production)

# For testing, disable rate limiting:
# .env
ENVIRONMENT=test
```

### Problem: 400 Validation error

**Symptoms:**
```json
{
  "errors": {
    "data": ["must be filled"],
    "difficulty": ["must be between 1 and 10"]
  }
}
```

**Solution:**
```bash
# Ensure required fields are provided
curl -X POST http://localhost:1910/api/v1/chain/:id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Your data here", "difficulty": 3}'

# Check difficulty is 1-10
```

### Problem: 404 Not found

**Symptoms:**
```
404 Not Found
```

**Solutions:**

**1. Check endpoint URL:**
```bash
# Correct endpoints:
POST http://localhost:1910/api/v1/chain
POST http://localhost:1910/api/v1/chain/:id/block
GET  http://localhost:1910/api/v1/chain/:id/block/:block_id
POST http://localhost:1910/api/v1/chain/:id/block/:block_id/valid

# Common mistakes:
# - Missing /api/v1 prefix
# - Wrong ID format
# - GET instead of POST (or vice versa)
```

**2. Verify IDs are valid:**
```bash
# IDs must be valid MongoDB ObjectIds
# Format: 24 hexadecimal characters
# Example: 674c8a1b2e4f5a0012345678
```

### Problem: Empty response body

**Symptoms:**
- API returns 200 but empty body

**Solution:**
```bash
# Check Content-Type header
curl -v http://localhost:1910/api/v1/chain/:id/block/:block_id

# Should include:
# Content-Type: application/json

# Check Sinatra is setting content type:
# main.rb should have:
before do
  content_type :json
end
```

## Testing Issues

### Problem: Tests fail with MongoDB errors

**Symptoms:**
```
Mongoid::Errors::NoSessionsAvailable
```

**Solution:**
```bash
# Ensure MongoDB is running
mongosh --eval "db.version()"

# Check .env.test
cat .env.test
# Should have:
MONGO_DB_NAME=chain_forge_test
MONGO_DB_HOST=localhost

# Clear test database
mongosh chain_forge_test --eval "db.dropDatabase()"

# Run tests again
bundle exec rspec
```

### Problem: Tests fail randomly (flaky)

**Symptoms:**
- Tests pass sometimes, fail other times

**Solutions:**

**1. Ensure database is cleaned:**
```ruby
# spec/spec_helper.rb
config.before(:each) do
  Mongoid.purge!
end
```

**2. Check for shared state:**
```ruby
# Bad - shared state
let(:blockchain) { Blockchain.create }

it 'test 1' do
  blockchain.add_block('data')
  expect(blockchain.blocks.count).to eq(2)
end

it 'test 2' do
  # Fails if test 1 ran first!
  expect(blockchain.blocks.count).to eq(1)
end

# Good - isolated
it 'test 1' do
  blockchain = Blockchain.create
  blockchain.add_block('data')
  expect(blockchain.blocks.count).to eq(2)
end

it 'test 2' do
  blockchain = Blockchain.create
  expect(blockchain.blocks.count).to eq(1)
end
```

**3. Use let! for setup that must run:**
```ruby
let!(:existing_blockchain) { Blockchain.create }

it 'counts blockchains' do
  expect(Blockchain.count).to eq(1)
end
```

### Problem: Tests timeout

**Symptoms:**
```
Timeout::Error
```

**Solution:**
```bash
# Use low difficulty in tests
# spec/block_spec.rb
let(:block) { blockchain.blocks.build(difficulty: 1) }

# NOT difficulty 5+
```

### Problem: Coverage not generated

**Symptoms:**
- No coverage/ directory after tests

**Solution:**
```bash
# Run with COVERAGE environment variable
COVERAGE=true bundle exec rspec

# Verify SimpleCov installed
bundle list | grep simplecov

# Check spec/spec_helper.rb has:
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end
```

## Docker Issues

### Problem: Docker containers won't start

**Symptoms:**
```
ERROR: Cannot start service app: ...
```

**Solutions:**

**1. Check Docker is running:**
```bash
docker ps

# If error, start Docker Desktop (macOS/Windows)
# Or start Docker daemon (Linux)
sudo systemctl start docker
```

**2. Check for port conflicts:**
```bash
# Check if port 1910 is already used
lsof -i:1910

# Kill process or change port in docker-compose.yml
```

**3. Rebuild containers:**
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up
```

### Problem: MongoDB container crashes

**Symptoms:**
```
mongodb exited with code 1
```

**Solutions:**

**1. Check logs:**
```bash
docker-compose logs mongodb
```

**2. Remove old volumes:**
```bash
docker-compose down -v
docker-compose up
```

**3. Check disk space:**
```bash
df -h
# Ensure sufficient space for MongoDB data
```

### Problem: Can't connect to MongoDB in Docker

**Symptoms:**
- App can't reach MongoDB container

**Solution:**
```bash
# Ensure using correct hostname
# In Docker, use service name 'mongodb', not 'localhost'

# docker-compose.yml should have:
environment:
  MONGO_DB_HOST: mongodb  # NOT localhost

# Verify network:
docker-compose exec app ping mongodb
```

## Performance Issues

### Problem: Mining takes forever

**Symptoms:**
- Block creation hangs for minutes

**Solutions:**

**1. Check difficulty:**
```bash
# Difficulty 7+ can take hours!
# Use difficulty 1-4 for development

curl -X POST http://localhost:1910/api/v1/chain/:id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "test", "difficulty": 2}'

# Set default difficulty:
# .env
DEFAULT_DIFFICULTY=2
```

**2. Monitor mining:**
```bash
# Add logging to see progress
# src/block.rb (for debugging only):
def mine_block
  target = '0' * difficulty
  attempts = 0

  loop do
    attempts += 1
    puts "Attempt #{attempts}" if attempts % 1000 == 0

    calculate_hash
    break if _hash.start_with?(target)

    self.nonce += 1
  end

  puts "Mined in #{attempts} attempts"
  _hash
end
```

**3. Expected times:**
```
Difficulty 1-2: < 1 second
Difficulty 3-4: 1-10 seconds
Difficulty 5-6: 1-5 minutes
Difficulty 7+: Hours
```

### Problem: Application is slow

**Symptoms:**
- API responses take seconds

**Solutions:**

**1. Check MongoDB indexes:**
```bash
mongosh chain_forge
db.blocks.getIndexes()
# Should include index on blockchain_id
```

**2. Check for rate limiting delays:**
```bash
# Rate limiting can slow responses
# Disable for development:
# main.rb
use Rack::Attack unless ENV['ENVIRONMENT'] == 'development'
```

**3. Check for N+1 queries:**
```ruby
# Bad - N+1 query
blockchain.blocks.each do |block|
  puts block.blockchain.id  # Extra query per block!
end

# Good - eager loading
blocks = blockchain.blocks.to_a
blocks.each do |block|
  puts block.blockchain_id  # No extra query
end
```

## Getting Help

### Check Logs

```bash
# Application logs
tail -f log/development.log

# MongoDB logs
# macOS
tail -f /usr/local/var/log/mongodb/mongo.log

# Linux
sudo tail -f /var/log/mongodb/mongod.log

# Docker
docker-compose logs -f
```

### Debug Mode

```bash
# Run with verbose output
ruby main.rb -p 1910 -v

# Or add debugging:
# main.rb
set :logging, Logger::DEBUG
```

### Check System Status

```bash
# Check Ruby version
ruby -v

# Check MongoDB status
mongosh --eval "db.version()"

# Check listening ports
sudo lsof -iTCP -sTCP:LISTEN -n -P | grep -E '(1910|27017)'

# Check environment
cat .env
env | grep MONGO
```

### Still Stuck?

1. **Search existing issues:** https://github.com/Perafan18/chain_forge/issues
2. **Open new issue:** Include:
   - Operating System
   - Ruby version (`ruby -v`)
   - MongoDB version (`mongosh --eval "db.version()"`)
   - Error message (full stack trace)
   - Steps to reproduce
3. **Check documentation:**
   - [Development Setup](development-setup.md)
   - [Testing Guide](testing-guide.md)
   - [Deployment Guide](deployment-guide.md)

## Quick Reference

### Essential Commands

```bash
# Start application
ruby main.rb -p 1910

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Start MongoDB
brew services start mongodb-community  # macOS
sudo systemctl start mongod  # Linux

# View MongoDB data
mongosh chain_forge
db.blockchains.find()
db.blocks.find()

# Clean database
mongosh chain_forge --eval "db.dropDatabase()"

# Docker
docker-compose up
docker-compose down
docker-compose logs -f
```

### Common Fixes

```bash
# Reset everything
docker-compose down -v
mongosh chain_forge --eval "db.dropDatabase()"
mongosh chain_forge_test --eval "db.dropDatabase()"
bundle install
ruby main.rb -p 1910

# Clear gems and reinstall
bundle clean --force
rm -rf vendor/bundle
bundle install

# Kill process on port
kill -9 $(lsof -ti:1910)
```

## Next Steps

- [Development Setup](development-setup.md) - Complete setup guide
- [Testing Guide](testing-guide.md) - Testing best practices
- [API Reference](../api/reference.md) - API documentation
- [CONTRIBUTING](../CONTRIBUTING.md) - How to contribute

---

**Found a solution not listed here?** Contribute via [CONTRIBUTING](../CONTRIBUTING.md)!
