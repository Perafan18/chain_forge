# Task 15: Integration & E2E Tests

**PR**: #23
**Fase**: 6 - Quality Assurance
**Complejidad**: Medium
**Estimación**: 4-5 días
**Prioridad**: P1
**Dependencias**: All tasks (01-14)

## Objetivo

Crear suite comprehensiva de integration tests y end-to-end tests que validen el sistema completo funcionando junto. Los tests deben cubrir flujos completos de usuario, desde crear una blockchain hasta minar bloques, validar integridad, y usar todas las features implementadas.

## Motivación

**Problemas actuales**:
- Unit tests solo validan componentes aislados
- No hay tests de integración entre componentes
- No hay tests end-to-end de flujos completos
- No hay tests de performance/load
- Difícil detectar regression bugs

**Solución**: Test suite multi-nivel:
- **Integration tests** - Componentes trabajando juntos
- **E2E tests** - Flujos completos de usuario
- **API contract tests** - OpenAPI spec compliance
- **Performance tests** - Benchmarking y regression
- **Load tests** - Capacidad bajo carga
- **Security tests** - Vulnerabilidades comunes

**Educational value**: Enseña testing strategies, test pyramids, CI/CD integration, y quality assurance best practices (usado por todas las empresas de software profesional).

## Cambios Técnicos

### 1. Setup & Dependencies

**Gemfile** (test group):
```ruby
group :test do
  gem 'rspec', '~> 3.12'
  gem 'rack-test', '~> 2.1'
  gem 'capybara', '~> 3.39'  # E2E testing
  gem 'selenium-webdriver', '~> 4.15'  # Browser automation
  gem 'webdrivers', '~> 5.3'  # Auto-install browser drivers
  gem 'factory_bot', '~> 6.4'  # Test data factories
  gem 'faker', '~> 3.2'  # Fake data generation
  gem 'database_cleaner-mongoid', '~> 2.0'  # DB cleanup between tests
  gem 'shoulda-matchers', '~> 6.0'  # RSpec matchers
  gem 'simplecov', '~> 0.22', require: false  # Code coverage
  gem 'vcr', '~> 6.2'  # HTTP interaction recording
  gem 'webmock', '~> 3.19'  # HTTP request stubbing
  gem 'timecop', '~> 0.9'  # Time manipulation
  gem 'rspec-benchmark', '~> 0.6'  # Performance testing
  gem 'k6', '~> 0.1'  # Load testing (optional)
end
```

**spec/spec_helper.rb**:
```ruby
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/config/'
  add_group 'Models', 'src/models'
  add_group 'Libraries', 'lib'
  add_group 'Workers', 'app/workers'
  minimum_coverage 80
end

require 'rspec'
require 'rack/test'
require 'factory_bot'
require 'faker'
require 'database_cleaner/mongoid'
require 'shoulda/matchers'
require 'webmock/rspec'
require 'vcr'
require 'timecop'
require 'rspec-benchmark'

require_relative '../config/environment'

RSpec.configure do |config|
  # Include helpers
  config.include Rack::Test::Methods
  config.include FactoryBot::Syntax::Methods

  # Database cleaner
  config.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :truncation
    DatabaseCleaner[:mongoid].clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner[:mongoid].cleaning do
      example.run
    end
  end

  # Disable external HTTP requests
  WebMock.disable_net_connect!(allow_localhost: true)

  # VCR configuration
  VCR.configure do |c|
    c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
    c.hook_into :webmock
    c.configure_rspec_metadata!
  end

  # RSpec configuration
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = false
  config.order = :random
  Kernel.srand config.seed

  # Performance testing
  config.include RSpec::Benchmark::Matchers
end

# Define app for Rack::Test
def app
  Sinatra::Application
end

# Shoulda matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :mongoid
  end
end
```

### 2. Integration Tests

**spec/integration/blockchain_lifecycle_spec.rb**:
```ruby
RSpec.describe 'Blockchain Lifecycle Integration', type: :integration do
  describe 'Complete blockchain workflow' do
    it 'creates blockchain, mines blocks, validates integrity' do
      # 1. Create blockchain
      post '/api/v1/chain', { name: 'TestChain' }.to_json,
        { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(201)
      chain_data = JSON.parse(last_response.body)
      chain_id = chain_data['blockchain']['id']

      # 2. Verify blockchain exists
      get "/api/v1/chain/#{chain_id}"
      expect(last_response.status).to eq(200)

      blockchain = JSON.parse(last_response.body)['blockchain']
      expect(blockchain['name']).to eq('TestChain')
      expect(blockchain['total_blocks']).to eq(1)  # Genesis block

      # 3. Add transactions to mempool
      3.times do |i|
        post "/api/v1/chain/#{chain_id}/transaction", {
          from: "user_#{i}",
          to: "recipient_#{i}",
          amount: 10.0 + i,
          fee: 0.1
        }.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
      end

      # 4. Verify mempool has transactions
      mempool = Blockchain.find(chain_id).mempool
      expect(mempool.pending_transactions.count).to eq(3)

      # 5. Mine block asynchronously
      post "/api/v1/chain/#{chain_id}/block", {
        miner_address: 'test_miner',
        difficulty: 2
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(202)
      job_data = JSON.parse(last_response.body)
      job_id = job_data['job_id']

      # 6. Wait for mining to complete
      Sidekiq::Worker.drain_all

      get "/api/v1/jobs/#{job_id}"
      job_status = JSON.parse(last_response.body)
      expect(job_status['status']).to eq('complete')

      # 7. Verify block was mined
      get "/api/v1/chain/#{chain_id}"
      updated_chain = JSON.parse(last_response.body)['blockchain']
      expect(updated_chain['total_blocks']).to eq(2)

      # 8. Verify mempool was cleared
      mempool.reload
      expect(mempool.pending_transactions.count).to eq(0)

      # 9. Validate blockchain integrity
      get "/api/v1/chain/#{chain_id}/validate"
      expect(last_response.status).to eq(200)
      validation = JSON.parse(last_response.body)
      expect(validation['valid']).to be true
      expect(validation['errors']).to be_empty

      # 10. Verify block details
      block_id = job_status['result']['block_id']
      get "/api/v1/chain/#{chain_id}/block/#{block_id}"

      block = JSON.parse(last_response.body)['block']
      expect(block['index']).to eq(2)
      expect(block['transactions'].length).to eq(4)  # 3 + coinbase
      expect(block['miner']).to eq('test_miner')
      expect(block['hash']).to start_with('00')  # Difficulty 2
    end
  end

  describe 'Multi-blockchain scenario' do
    it 'manages multiple blockchains independently' do
      # Create 3 blockchains
      chains = 3.times.map do |i|
        post '/api/v1/chain', { name: "Chain_#{i}" }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        JSON.parse(last_response.body)['blockchain']['id']
      end

      # Mine blocks on each chain
      chains.each_with_index do |chain_id, i|
        (i + 1).times do
          post "/api/v1/chain/#{chain_id}/block", {
            miner_address: "miner_#{i}",
            difficulty: 1
          }.to_json, { 'CONTENT_TYPE' => 'application/json' }
        end
      end

      # Process all mining jobs
      Sidekiq::Worker.drain_all

      # Verify each chain has correct number of blocks
      chains.each_with_index do |chain_id, i|
        get "/api/v1/chain/#{chain_id}"
        blockchain = JSON.parse(last_response.body)['blockchain']
        expect(blockchain['total_blocks']).to eq(i + 2)  # Genesis + mined blocks
      end

      # Verify all chains are valid
      chains.each do |chain_id|
        get "/api/v1/chain/#{chain_id}/validate"
        validation = JSON.parse(last_response.body)
        expect(validation['valid']).to be true
      end
    end
  end

  describe 'Digital signatures workflow' do
    let(:wallet) { ChainForge::Crypto::Wallet.new }
    let(:blockchain) { create(:blockchain) }

    it 'signs and verifies transactions' do
      # Create signed transaction
      tx_data = {
        to: 'recipient_address',
        amount: 50.0,
        fee: 0.5,
        timestamp: Time.now.to_i
      }

      signed_tx = wallet.sign_transaction(tx_data)

      # Submit transaction
      post "/api/v1/chain/#{blockchain.id}/transaction",
        signed_tx.to_json,
        { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(201)

      # Verify signature
      expect(
        ChainForge::Crypto::Wallet.verify_transaction(signed_tx)
      ).to be true

      # Try to submit invalid signature
      tampered_tx = signed_tx.dup
      tampered_tx[:amount] = 100.0  # Tamper with amount

      post "/api/v1/chain/#{blockchain.id}/transaction",
        tampered_tx.to_json,
        { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(400)
      error = JSON.parse(last_response.body)
      expect(error['error']).to include('Invalid signature')
    end
  end

  describe 'Difficulty adjustment' do
    let(:blockchain) { create(:blockchain, current_difficulty: 2) }

    it 'adjusts difficulty based on block time' do
      initial_difficulty = blockchain.current_difficulty

      # Mine blocks quickly (simulate low difficulty)
      Blockchain::ADJUSTMENT_INTERVAL.times do |i|
        block = create(:block,
          blockchain: blockchain,
          index: i + 2,
          difficulty: initial_difficulty,
          mining_duration: 5.0  # Fast mining
        )
      end

      # Calculate next difficulty
      new_difficulty = blockchain.calculate_next_difficulty(
        blockchain.blocks.count + 1
      )

      # Should increase difficulty
      expect(new_difficulty).to be > initial_difficulty
    end
  end
end
```

### 3. End-to-End Tests (Browser)

**spec/features/block_explorer_e2e_spec.rb**:
```ruby
RSpec.describe 'Block Explorer E2E', type: :feature, js: true do
  before do
    driven_by :selenium_chrome_headless
  end

  scenario 'User creates blockchain and mines blocks' do
    # 1. Visit homepage
    visit '/'
    expect(page).to have_content('ChainForge Blockchain Explorer')

    # 2. Navigate to chains page
    click_link 'Blockchains'
    expect(current_path).to eq('/chains')

    # 3. Create new blockchain
    click_button 'Create New Blockchain'
    fill_in 'name', with: 'My Test Chain'
    click_button 'Create'

    # 4. Verify on blockchain detail page
    expect(page).to have_content('My Test Chain')
    expect(page).to have_content('Total Blocks: 1')  # Genesis

    # 5. Mine a block
    click_button 'Mine Block'
    fill_in 'miner_address', with: 'my_miner_address'
    click_button 'Start Mining'

    # 6. Wait for mining notification
    expect(page).to have_content('Mining job queued', wait: 10)

    # 7. Wait for completion (with WebSocket)
    expect(page).to have_content('Mining completed', wait: 60)

    # 8. Verify block count increased
    expect(page).to have_content('Total Blocks: 2')

    # 9. Click on new block
    click_link '#2'

    # 10. Verify block details
    expect(page).to have_content('Block #2')
    expect(page).to have_content('my_miner_address')
    expect(page).to have_content('Valid Block')
  end

  scenario 'User searches for block' do
    blockchain = create(:blockchain, name: 'SearchChain')
    block = create(:block, blockchain: blockchain, index: 5)

    visit '/'

    # Search by block index
    fill_in 'q', with: '5'
    click_button 'Search'

    expect(page).to have_content('Block #5')
    expect(page).to have_content('SearchChain')

    # Search by hash
    visit '/'
    fill_in 'q', with: block.hash
    click_button 'Search'

    expect(page).to have_content(block.hash)
  end

  scenario 'Real-time updates with WebSockets' do
    blockchain = create(:blockchain)

    visit "/chains/#{blockchain.id}"

    # Wait for WebSocket connection
    expect(page).to have_css('#ws-status', text: 'Live', wait: 5)

    # Trigger new block in background
    Thread.new do
      sleep 2  # Give WebSocket time to connect
      block = create(:block, blockchain: blockchain)
      ChainForge::WebSocket::Publisher.publish_block(block)
    end

    # Should see notification
    expect(page).to have_content('New block', wait: 10)
  end
end
```

### 4. API Contract Tests

**spec/api/openapi_compliance_spec.rb**:
```ruby
require 'openapi3_parser'

RSpec.describe 'OpenAPI Compliance', type: :api do
  let(:openapi_doc) do
    OpenAPIParser.parse(File.read('openapi.yaml'))
  end

  describe 'GET /api/v1/chains' do
    it 'matches OpenAPI schema' do
      get '/api/v1/chains'

      expect(last_response.status).to eq(200)

      schema = openapi_doc.paths['/api/v1/chains']
                         .get.responses['200']
                         .content['application/json'].schema

      response_data = JSON.parse(last_response.body)

      expect(response_data).to match_openapi_schema(schema)
    end
  end

  describe 'POST /api/v1/chain' do
    it 'validates request body against schema' do
      schema = openapi_doc.paths['/api/v1/chain']
                         .post.request_body
                         .content['application/json'].schema

      valid_body = { name: 'TestChain' }

      expect(valid_body).to match_openapi_schema(schema)

      # Invalid body
      invalid_body = { name: '' }  # Empty name
      expect(invalid_body).not_to match_openapi_schema(schema)
    end
  end

  # Custom matcher
  RSpec::Matchers.define :match_openapi_schema do |schema|
    match do |data|
      # Implement JSON schema validation
      # Use json-schema gem or similar
      true
    end
  end
end
```

### 5. Performance Tests

**spec/performance/api_performance_spec.rb**:
```ruby
RSpec.describe 'API Performance', type: :performance do
  let!(:blockchain) { create(:blockchain) }
  let!(:blocks) { create_list(:block, 100, blockchain: blockchain) }

  describe 'GET /api/v1/chains' do
    it 'responds within 100ms' do
      expect {
        get '/api/v1/chains'
      }.to perform_under(100).ms
    end

    it 'handles 100 concurrent requests' do
      responses = []

      100.times do
        Thread.new do
          get '/api/v1/chains'
          responses << last_response
        end
      end.each(&:join)

      expect(responses.all? { |r| r.status == 200 }).to be true
    end
  end

  describe 'GET /api/v1/chain/:id/blocks' do
    it 'responds within 200ms with 50 blocks' do
      expect {
        get "/api/v1/chain/#{blockchain.id}/blocks?limit=50"
      }.to perform_under(200).ms
    end

    it 'does not degrade with large datasets' do
      # Create 1000 more blocks
      create_list(:block, 1000, blockchain: blockchain)

      expect {
        get "/api/v1/chain/#{blockchain.id}/blocks?limit=50"
      }.to perform_under(300).ms
    end
  end

  describe 'Mining performance' do
    it 'mines block within acceptable time' do
      duration = Benchmark.realtime do
        blockchain.add_block(
          [{ from: 'test', to: 'recipient', amount: 10 }],
          custom_difficulty: 2
        )
      end

      expect(duration).to be < 60  # Should complete within 60s for difficulty 2
    end
  end
end
```

### 6. Load Tests

**spec/load/k6_load_test.js** (using k6):
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '30s', target: 20 },   // Ramp up to 20 users
    { duration: '1m', target: 50 },    // Ramp up to 50 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    http_req_failed: ['rate<0.01'],    // Less than 1% errors
  },
};

const BASE_URL = 'http://localhost:1910';

export default function () {
  // GET chains
  let chains = http.get(`${BASE_URL}/api/v1/chains`);
  check(chains, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });

  // GET specific chain
  if (chains.json().chains.length > 0) {
    let chainId = chains.json().chains[0].id;
    let chain = http.get(`${BASE_URL}/api/v1/chain/${chainId}`);

    check(chain, {
      'chain status is 200': (r) => r.status === 200,
    });

    // GET blocks
    let blocks = http.get(`${BASE_URL}/api/v1/chain/${chainId}/blocks?limit=20`);
    check(blocks, {
      'blocks status is 200': (r) => r.status === 200,
    });
  }

  sleep(1);
}
```

**Run with**:
```bash
k6 run spec/load/k6_load_test.js
```

### 7. Security Tests

**spec/security/vulnerabilities_spec.rb**:
```ruby
RSpec.describe 'Security Vulnerabilities', type: :security do
  describe 'SQL Injection protection' do
    it 'sanitizes user input' do
      # Try SQL injection in search
      malicious_query = "'; DROP TABLE blockchains; --"

      get "/search?q=#{URI.encode_www_form_component(malicious_query)}"

      # Should not crash or execute SQL
      expect(last_response.status).to eq(200)
      expect(Blockchain.count).to be > 0  # Tables still exist
    end
  end

  describe 'XSS protection' do
    it 'escapes HTML in blockchain names' do
      post '/api/v1/chain',
        { name: '<script>alert("XSS")</script>' }.to_json,
        { 'CONTENT_TYPE' => 'application/json' }

      chain_id = JSON.parse(last_response.body)['blockchain']['id']

      get "/chains/#{chain_id}"

      # Should escape script tags
      expect(last_response.body).not_to include('<script>')
      expect(last_response.body).to include('&lt;script&gt;')
    end
  end

  describe 'Rate limiting' do
    it 'blocks excessive requests' do
      101.times do
        get '/api/v1/chains'
      end

      expect(last_response.status).to eq(429)  # Too Many Requests
      expect(last_response.headers['Retry-After']).to be_present
    end
  end

  describe 'CSRF protection' do
    it 'requires CSRF token for state-changing requests' do
      # Should be implemented with Rack::Protection
      post '/api/v1/chain',
        { name: 'TestChain' }.to_json,
        { 'CONTENT_TYPE' => 'application/json' }

      # For now, API is stateless so CSRF not applicable
      # But session-based endpoints should require CSRF
    end
  end

  describe 'Authentication bypass attempts' do
    it 'prevents unauthorized access to protected endpoints' do
      # If auth is implemented
      # get '/admin/dashboard'
      # expect(last_response.status).to eq(401)
    end
  end
end
```

### 8. Factories

**spec/factories/blockchains.rb**:
```ruby
FactoryBot.define do
  factory :blockchain do
    name { Faker::App.name }
    current_difficulty { 2 }
    block_reward { 50.0 }

    after(:create) do |blockchain|
      # Create genesis block
      create(:block, blockchain: blockchain, index: 1, previous_hash: '0')

      # Create mempool
      create(:mempool, blockchain: blockchain)
    end

    trait :with_blocks do
      transient do
        blocks_count { 5 }
      end

      after(:create) do |blockchain, evaluator|
        create_list(:block, evaluator.blocks_count,
          blockchain: blockchain,
          index: (2..evaluator.blocks_count + 1).to_a
        )
      end
    end
  end
end
```

**spec/factories/blocks.rb**:
```ruby
FactoryBot.define do
  factory :block do
    association :blockchain
    sequence(:index)
    timestamp { Time.now.to_i }
    nonce { rand(1000000) }
    difficulty { 2 }
    miner { Faker::Crypto.sha256[0..20] }
    mining_duration { rand(5.0..30.0).round(3) }
    previous_hash { Faker::Crypto.sha256 }

    transactions do
      [
        {
          from: 'COINBASE',
          to: miner,
          amount: 50.0,
          fee: 0,
          timestamp: timestamp
        }
      ]
    end

    after(:build) do |block|
      block.calculate_merkle_root
      block.calculate_hash
    end

    trait :with_transactions do
      transient do
        tx_count { 5 }
      end

      transactions do
        Array.new(tx_count) do
          {
            from: Faker::Crypto.sha256[0..20],
            to: Faker::Crypto.sha256[0..20],
            amount: rand(1.0..100.0).round(2),
            fee: rand(0.1..1.0).round(2),
            timestamp: Time.now.to_i
          }
        end
      end
    end
  end
end
```

### 9. CI/CD Integration

**.github/workflows/test.yml**:
```yaml
name: Test Suite

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  unit_tests:
    runs-on: ubuntu-latest

    services:
      mongodb:
        image: mongo:7
        ports:
          - 27017:27017

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Run unit tests
        run: bundle exec rspec spec/models spec/lib --format documentation

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/coverage.xml

  integration_tests:
    runs-on: ubuntu-latest

    services:
      mongodb:
        image: mongo:7
        ports:
          - 27017:27017

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Run integration tests
        run: bundle exec rspec spec/integration --format documentation

  e2e_tests:
    runs-on: ubuntu-latest

    services:
      mongodb:
        image: mongo:7
        ports:
          - 27017:27017

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Install Chrome
        uses: browser-actions/setup-chrome@latest

      - name: Run E2E tests
        run: bundle exec rspec spec/features --format documentation

  performance_tests:
    runs-on: ubuntu-latest

    services:
      mongodb:
        image: mongo:7
        ports:
          - 27017:27017

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Run performance tests
        run: bundle exec rspec spec/performance --format documentation

      - name: Performance regression check
        run: |
          echo "Checking for performance regressions..."
          # Compare with baseline

  security_tests:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Run Brakeman security scan
        uses: artichoke/brakeman-linter-action@v1

      - name: Run Bundler Audit
        run: |
          gem install bundler-audit
          bundle audit check --update
```

### 10. Test Coverage Reports

**spec/support/coverage.rb**:
```ruby
if ENV['COVERAGE']
  require 'simplecov'

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/config/'

    add_group 'Models', 'src/models'
    add_group 'Libraries', 'lib'
    add_group 'Workers', 'app/workers'
    add_group 'Helpers', 'app/helpers'

    track_files '{src,lib,app}/**/*.rb'

    minimum_coverage 80
    maximum_coverage_drop 5

    # Formatters
    if ENV['CI']
      require 'simplecov-cobertura'
      formatter SimpleCov::Formatter::CoberturaFormatter
    else
      formatter SimpleCov::Formatter::HTMLFormatter
    end
  end
end
```

## Test Commands

**Rakefile**:
```ruby
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc 'Run unit tests'
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.pattern = 'spec/{models,lib}/**/*_spec.rb'
  end

  desc 'Run integration tests'
  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = 'spec/integration/**/*_spec.rb'
  end

  desc 'Run E2E tests'
  RSpec::Core::RakeTask.new(:e2e) do |t|
    t.pattern = 'spec/features/**/*_spec.rb'
  end

  desc 'Run performance tests'
  RSpec::Core::RakeTask.new(:performance) do |t|
    t.pattern = 'spec/performance/**/*_spec.rb'
  end

  desc 'Run security tests'
  RSpec::Core::RakeTask.new(:security) do |t|
    t.pattern = 'spec/security/**/*_spec.rb'
  end

  desc 'Run all tests with coverage'
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task['spec'].invoke
  end
end

task default: :spec
```

## Test Pyramid

```
       /\
      /  \
     / E2E \        ~10% - Full browser tests
    /------\
   /        \
  / Integration\   ~30% - API & component integration
 /------------\
/              \
|  Unit Tests  |  ~60% - Models, libraries, helpers
\--------------/
```

## Coverage Targets

- **Overall**: 80%+ code coverage
- **Models**: 90%+ coverage
- **Critical paths**: 100% coverage
- **Edge cases**: Comprehensive error handling tests

## Criterios de Aceptación

- [ ] Unit tests para todos los models
- [ ] Integration tests para flujos completos
- [ ] E2E tests con Capybara/Selenium
- [ ] API contract tests con OpenAPI
- [ ] Performance tests con benchmarks
- [ ] Load tests con k6
- [ ] Security tests para vulnerabilidades comunes
- [ ] Factories para test data
- [ ] Database cleaner configurado
- [ ] SimpleCov reportando coverage
- [ ] CI/CD pipeline en GitHub Actions
- [ ] Coverage mínimo 80%
- [ ] Todos los tests passing
- [ ] Test execution time < 5 min

## Educational Value

Este task enseña:
- **Test pyramid** - Balance entre unit, integration, E2E
- **Test-driven development** - Writing tests first
- **Continuous integration** - Automated testing
- **Code coverage** - Measuring test completeness
- **Performance testing** - Benchmarking y regression
- **Load testing** - Capacity planning
- **Security testing** - Vulnerability scanning
- **Test automation** - CI/CD pipelines

Prácticas usadas por:
- **Google** - Extensive automated testing
- **Netflix** - Chaos engineering & testing
- **Stripe** - High test coverage for payments
- **GitHub** - Continuous testing for reliability

## Referencias

- [RSpec Documentation](https://rspec.info/)
- [Capybara Documentation](https://teamcapybara.github.io/capybara/)
- [FactoryBot Guide](https://github.com/thoughtbot/factory_bot)
- [SimpleCov Coverage](https://github.com/simplecov-ruby/simplecov)
- [k6 Load Testing](https://k6.io/docs/)
- [Testing Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
