# Testing Guide

Comprehensive guide to testing ChainForge, including unit tests, integration tests, coverage, and CI/CD.

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Framework (RSpec)](#test-framework-rspec)
3. [Running Tests](#running-tests)
4. [Test Structure](#test-structure)
5. [Writing Tests](#writing-tests)
6. [Code Coverage](#code-coverage)
7. [Continuous Integration](#continuous-integration)
8. [Best Practices](#best-practices)
9. [Troubleshooting Tests](#troubleshooting-tests)

## Testing Philosophy

ChainForge follows these testing principles:

- **Comprehensive Coverage**: Aim for >90% code coverage
- **Test Behavior, Not Implementation**: Focus on what code does, not how
- **Fast Tests**: Keep test suite under 10 seconds
- **Descriptive Names**: Tests document expected behavior
- **Isolation**: Each test is independent and can run alone
- **No Flakiness**: Tests always produce same result

## Test Framework (RSpec)

ChainForge uses **RSpec 3.10** for behavior-driven testing.

### Installation

```bash
# Already included in Gemfile
bundle install

# Verify RSpec installed
bundle exec rspec --version
# RSpec 3.10
```

### Test Organization

```
spec/
├── spec_helper.rb        # RSpec configuration
├── block_spec.rb         # Block model tests
├── blockchain_spec.rb    # Blockchain model tests
└── api_spec.rb           # API integration tests
```

## Running Tests

### Run All Tests

```bash
# Run entire test suite
bundle exec rspec

# Example output:
# Block
#   #calculate_hash
#     ✓ calculates SHA256 hash
#     ✓ changes when data changes
#   #mine_block
#     ✓ finds valid hash with difficulty 1
#     ✓ increments nonce until valid
#
# 17 examples, 0 failures
#
# Finished in 3.5 seconds
```

### Run Specific Tests

```bash
# Run specific file
bundle exec rspec spec/block_spec.rb

# Run specific describe block (by line number)
bundle exec rspec spec/block_spec.rb:10

# Run tests matching description
bundle exec rspec -e "mines a block"

# Run failed tests from last run
bundle exec rspec --only-failures
```

### Run with Options

```bash
# Detailed output
bundle exec rspec --format documentation

# Show 10 slowest tests
bundle exec rspec --profile 10

# Stop on first failure
bundle exec rspec --fail-fast

# Run tests in random order
bundle exec rspec --order random

# Run tests in parallel (not yet configured)
bundle exec parallel_rspec spec/
```

### Run with Coverage

```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# View coverage report
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
```

## Test Structure

### spec_helper.rb

Configuration file for RSpec and test environment.

```ruby
# spec/spec_helper.rb
require 'rack/test'
require 'json'
require 'mongoid'
require 'dotenv/load'

# Load test environment
ENV['ENVIRONMENT'] = 'test'

# Load application
require_relative '../main'

# Configure Mongoid for tests
Mongoid.load!('./config/mongoid.yml', :test)

# Configure SimpleCov (if COVERAGE=true)
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    minimum_coverage 90
  end
end

RSpec.configure do |config|
  # Use Rack::Test for API tests
  config.include Rack::Test::Methods

  # Clean database before each test
  config.before(:each) do
    Mongoid.purge!
  end

  # Output format
  config.formatter = :documentation

  # Show failures immediately
  config.fail_fast = false
end
```

### Test File Structure

```ruby
# spec/block_spec.rb
require 'spec_helper'

RSpec.describe Block do
  describe '#calculate_hash' do
    it 'calculates SHA256 hash from block data' do
      # Test implementation
    end

    it 'produces different hash when data changes' do
      # Test implementation
    end
  end

  describe '#mine_block' do
    it 'finds hash with required leading zeros' do
      # Test implementation
    end

    it 'increments nonce until valid hash found' do
      # Test implementation
    end
  end
end
```

## Writing Tests

### Unit Tests (Block Model)

**Example: Hash Calculation**

```ruby
# spec/block_spec.rb
RSpec.describe Block do
  describe '#calculate_hash' do
    let(:blockchain) { Blockchain.create }
    let(:block) do
      blockchain.blocks.build(
        index: 1,
        data: 'test data',
        previous_hash: 'abc123',
        nonce: 0
      )
    end

    it 'calculates SHA256 hash from block data' do
      hash = block.calculate_hash

      expect(hash).to be_a(String)
      expect(hash.length).to eq(64)  # SHA256 hex length
      expect(hash).to match(/^[a-f0-9]{64}$/)
    end

    it 'produces same hash for same input' do
      hash1 = block.calculate_hash
      hash2 = block.calculate_hash

      expect(hash1).to eq(hash2)
    end

    it 'produces different hash when data changes' do
      hash1 = block.calculate_hash

      block.data = 'different data'
      hash2 = block.calculate_hash

      expect(hash1).not_to eq(hash2)
    end

    it 'produces different hash when nonce changes' do
      hash1 = block.calculate_hash

      block.nonce = 1
      hash2 = block.calculate_hash

      expect(hash1).not_to eq(hash2)
    end
  end
end
```

**Example: Mining (Proof of Work)**

```ruby
RSpec.describe Block do
  describe '#mine_block' do
    let(:blockchain) { Blockchain.create }
    let(:block) do
      blockchain.blocks.build(
        index: 1,
        data: 'test',
        previous_hash: blockchain.blocks.last._hash,
        difficulty: 2
      )
    end

    it 'finds hash with required leading zeros' do
      block.mine_block

      expect(block._hash).to start_with('00')  # Difficulty 2
    end

    it 'increments nonce until valid hash found' do
      expect {
        block.mine_block
      }.to change { block.nonce }.from(0)
    end

    it 'returns valid hash' do
      hash = block.mine_block

      expect(hash).to eq(block._hash)
      expect(block.valid_hash?).to be true
    end

    it 'works with different difficulty levels' do
      [1, 2, 3].each do |diff|
        block.difficulty = diff
        block.nonce = 0  # Reset
        block.mine_block

        expect(block._hash).to start_with('0' * diff)
      end
    end
  end
end
```

### Unit Tests (Blockchain Model)

**Example: Chain Integrity**

```ruby
# spec/blockchain_spec.rb
RSpec.describe Blockchain do
  describe '#integrity_valid?' do
    let(:blockchain) { Blockchain.create }

    context 'with valid chain' do
      before do
        blockchain.add_block('Block 1', difficulty: 1)
        blockchain.add_block('Block 2', difficulty: 1)
      end

      it 'returns true for valid chain' do
        expect(blockchain.integrity_valid?).to be true
      end
    end

    context 'with tampered block' do
      before do
        blockchain.add_block('Block 1', difficulty: 1)
        blockchain.add_block('Block 2', difficulty: 1)

        # Tamper with middle block
        block = blockchain.blocks[1]
        block.data = 'Tampered!'
        block.save
      end

      it 'returns false for invalid chain' do
        expect(blockchain.integrity_valid?).to be false
      end
    end

    context 'with broken hash link' do
      before do
        blockchain.add_block('Block 1', difficulty: 1)
        blockchain.add_block('Block 2', difficulty: 1)

        # Break hash link
        block = blockchain.blocks.last
        block.previous_hash = 'invalid'
        block.save
      end

      it 'returns false' do
        expect(blockchain.integrity_valid?).to be false
      end
    end
  end
end
```

### Integration Tests (API)

**Example: API Endpoints**

```ruby
# spec/api_spec.rb
require 'spec_helper'

RSpec.describe 'ChainForge API' do
  def app
    Sinatra::Application
  end

  describe 'POST /api/v1/chain' do
    it 'creates a new blockchain' do
      post '/api/v1/chain'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      data = JSON.parse(last_response.body)
      expect(data).to have_key('id')
      expect(data['id']).to be_a(String)
    end

    it 'creates genesis block automatically' do
      post '/api/v1/chain'
      data = JSON.parse(last_response.body)

      blockchain = Blockchain.find(data['id'])
      expect(blockchain.blocks.count).to eq(1)
      expect(blockchain.blocks.first.index).to eq(0)
      expect(blockchain.blocks.first.data).to eq('Genesis Block')
    end
  end

  describe 'POST /api/v1/chain/:id/block' do
    let(:blockchain) { Blockchain.create }

    context 'with valid input' do
      it 'mines and adds block to chain' do
        post "/api/v1/chain/#{blockchain.id}/block",
          { data: 'Test data', difficulty: 1 }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)

        data = JSON.parse(last_response.body)
        expect(data['chain_id']).to eq(blockchain.id.to_s)
        expect(data['block_hash']).to start_with('0')  # Difficulty 1
        expect(data).to have_key('nonce')
      end

      it 'uses default difficulty when not specified' do
        post "/api/v1/chain/#{blockchain.id}/block",
          { data: 'Test data' }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)

        data = JSON.parse(last_response.body)
        expect(data['difficulty']).to eq(ENV.fetch('DEFAULT_DIFFICULTY', '2').to_i)
      end
    end

    context 'with invalid input' do
      it 'returns 400 when data is missing' do
        post "/api/v1/chain/#{blockchain.id}/block",
          { difficulty: 2 }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)

        data = JSON.parse(last_response.body)
        expect(data['errors']).to have_key('data')
      end

      it 'returns 400 when difficulty is invalid' do
        post "/api/v1/chain/#{blockchain.id}/block",
          { data: 'Test', difficulty: 15 }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)

        data = JSON.parse(last_response.body)
        expect(data['errors']).to have_key('difficulty')
      end
    end

    context 'with non-existent blockchain' do
      it 'returns error' do
        post "/api/v1/chain/invalid_id/block",
          { data: 'Test', difficulty: 2 }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(500)
      end
    end
  end

  describe 'GET /api/v1/chain/:id/block/:block_id' do
    let(:blockchain) { Blockchain.create }
    let(:block) { blockchain.add_block('Test data', difficulty: 2) }

    it 'returns block details' do
      get "/api/v1/chain/#{blockchain.id}/block/#{block.id}"

      expect(last_response.status).to eq(200)

      data = JSON.parse(last_response.body)
      expect(data['block']['id']).to eq(block.id.to_s)
      expect(data['block']['data']).to eq('Test data')
      expect(data['block']['hash']).to eq(block._hash)
      expect(data['block']['valid_hash']).to be true
    end
  end

  describe 'POST /api/v1/chain/:id/block/:block_id/valid' do
    let(:blockchain) { Blockchain.create }
    let(:block) { blockchain.add_block('Original data', difficulty: 1) }

    context 'with correct data' do
      it 'returns valid: true' do
        post "/api/v1/chain/#{blockchain.id}/block/#{block.id}/valid",
          { data: 'Original data' }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)

        data = JSON.parse(last_response.body)
        expect(data['valid']).to be true
      end
    end

    context 'with tampered data' do
      it 'returns valid: false' do
        post "/api/v1/chain/#{blockchain.id}/block/#{block.id}/valid",
          { data: 'Tampered data' }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)

        data = JSON.parse(last_response.body)
        expect(data['valid']).to be false
      end
    end
  end
end
```

## Code Coverage

### SimpleCov Configuration

ChainForge uses **SimpleCov** to track code coverage.

**Enable Coverage:**
```bash
COVERAGE=true bundle exec rspec
```

**View Report:**
```bash
open coverage/index.html
```

### Coverage Requirements

- **Minimum**: 90% coverage
- **Target**: 95%+ coverage
- **CI Enforcement**: PR fails if coverage drops below 90%

### Coverage Report

```
COVERAGE: 94.23% -- 147/156 lines in 5 files

File                      | % Coverage | Lines | Relevant Lines | Lines Missed
--------------------------|------------|-------|----------------|--------------
src/block.rb             |     96.15% |    78 |             52 |            2
src/blockchain.rb        |     95.45% |    62 |             44 |            2
src/validators.rb        |    100.00% |    12 |              8 |            0
main.rb                  |     88.89% |   117 |             45 |            5
config/rack_attack.rb    |     85.71% |    35 |              7 |            1
```

### Improving Coverage

**Identify Untested Code:**
```bash
COVERAGE=true bundle exec rspec
open coverage/index.html

# Click on files with <100% coverage
# Red lines = not tested
```

**Add Tests:**
```ruby
# Find uncovered edge case
it 'handles edge case X' do
  # Test implementation
end
```

## Continuous Integration

### GitHub Actions

ChainForge uses **GitHub Actions** for automated testing.

**Workflow:** `.github/workflows/ci.yml`

```yaml
name: CI

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2.2
          bundler-cache: true
      - name: Run RuboCop
        run: bundle exec rubocop

  test:
    runs-on: ubuntu-latest
    services:
      mongodb:
        image: mongo:latest
        ports:
          - 27017:27017
    steps:
      - uses: actions/checkout@v3
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2.2
          bundler-cache: true
      - name: Run tests
        run: COVERAGE=true bundle exec rspec
      - name: Check coverage
        run: |
          coverage=$(cat coverage/.last_run.json | jq '.result.line')
          if (( $(echo "$coverage < 90" | bc -l) )); then
            echo "Coverage $coverage% is below 90%"
            exit 1
          fi
```

### Local CI Simulation

```bash
# Run same checks as CI
bundle exec rubocop && COVERAGE=true bundle exec rspec

# If this passes, CI will pass
```

## Best Practices

### 1. Descriptive Test Names

**Bad:**
```ruby
it 'works' do
  # ...
end
```

**Good:**
```ruby
it 'calculates SHA256 hash from block data' do
  # ...
end
```

### 2. Use let and let!

**Use let for lazy evaluation:**
```ruby
let(:blockchain) { Blockchain.create }
let(:block) { blockchain.add_block('data') }

it 'tests something' do
  # blockchain and block created here
end
```

**Use let! for eager evaluation:**
```ruby
let!(:existing_block) { blockchain.add_block('data') }

it 'counts existing blocks' do
  # existing_block created before test runs
  expect(blockchain.blocks.count).to eq(2)  # genesis + existing
end
```

### 3. Test Edge Cases

```ruby
describe '#add_block' do
  it 'handles empty data' do
    expect { blockchain.add_block('') }.to raise_error
  end

  it 'handles very long data' do
    long_data = 'a' * 10_000
    expect { blockchain.add_block(long_data) }.not_to raise_error
  end

  it 'handles special characters' do
    expect { blockchain.add_block('Test: 你好 🎉') }.not_to raise_error
  end
end
```

### 4. Keep Tests Fast

```ruby
# Use low difficulty for mining tests
let(:block) { blockchain.blocks.build(difficulty: 1) }  # Fast
# Don't use difficulty 5+ in tests (too slow)
```

### 5. Clean Database Between Tests

```ruby
# spec_helper.rb
config.before(:each) do
  Mongoid.purge!  # Clean database before each test
end
```

### 6. Test Behavior, Not Implementation

**Bad (testing implementation):**
```ruby
it 'increments nonce exactly 142 times' do
  expect(block.nonce).to eq(142)  # Fragile!
end
```

**Good (testing behavior):**
```ruby
it 'finds valid hash' do
  block.mine_block
  expect(block.valid_hash?).to be true
end
```

## Troubleshooting Tests

### Tests Fail Randomly

**Problem:** Flaky tests due to shared state

**Solution:**
```ruby
# Ensure database is cleaned
config.before(:each) do
  Mongoid.purge!
end

# Ensure tests are isolated
it 'test 1' do
  blockchain = Blockchain.create  # Create fresh instance
  # ...
end

it 'test 2' do
  blockchain = Blockchain.create  # Don't reuse from test 1
  # ...
end
```

### Tests Timeout

**Problem:** Mining tests take too long

**Solution:**
```ruby
# Use low difficulty
let(:block) { blockchain.blocks.build(difficulty: 1) }  # Fast

# Or mock mining for integration tests
allow(block).to receive(:mine_block).and_return('0' * 64)
```

### MongoDB Connection Issues

**Problem:** Can't connect to test database

**Solution:**
```bash
# Ensure MongoDB is running
mongosh --eval "db.version()"

# Check .env.test
cat .env.test

# Should have:
MONGO_DB_HOST=localhost
MONGO_DB_PORT=27017
```

### Coverage Not Generated

**Problem:** No coverage/ directory

**Solution:**
```bash
# Run with COVERAGE=true
COVERAGE=true bundle exec rspec

# Verify SimpleCov is installed
bundle list | grep simplecov
```

## Next Steps

- [Development Setup](development-setup.md) - Set up environment
- [Deployment Guide](deployment-guide.md) - Production deployment
- [Troubleshooting](troubleshooting.md) - Common issues

---

**Found a bug in tests?** Report it or fix it via [CONTRIBUTING](../CONTRIBUTING.md)!
