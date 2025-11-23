# Task 11: Async Mining (Sidekiq)

**PR**: #19
**Fase**: 4 - Infrastructure
**Complejidad**: Large
**Estimación**: 7-10 días
**Prioridad**: P1
**Dependencias**: Task 10 (Redis Integration) - required for job queue

## Objetivo

Mover el proceso de mining a background jobs asíncronos usando Sidekiq, permitiendo que las API requests retornen inmediatamente mientras el mining ocurre en workers dedicados. Esto mejora la experiencia del usuario y permite escalar horizontalmente los mining workers.

## Motivación

**Problemas actuales**:
- POST /chain/:id/block bloquea el request hasta que el mining termina
- Con difficulty alto, requests pueden tardar varios minutos
- Un solo proceso de Sinatra no puede minar múltiples bloques en paralelo
- Timeout de HTTP puede interrumpir el mining
- No hay visibilidad del progreso del mining

**Solución**: Sidekiq + Redis para background jobs:
- **Immediate response** - API retorna `job_id` inmediatamente
- **Parallel mining** - Múltiples workers pueden minar simultáneamente
- **Fault tolerance** - Jobs se reintenta automáticamente si fallan
- **Progress tracking** - Status y progreso en tiempo real vía API
- **Horizontal scaling** - Agregar más workers para mayor throughput
- **Job history** - Persistencia de jobs completados y fallidos

**Educational value**: Enseña arquitectura asíncrona, background job processing, y patrones de escalabilidad horizontal (usado por GitHub, Shopify, Airbnb en producción).

## Cambios Técnicos

### 1. Setup & Configuration

**Gemfile**:
```ruby
gem 'sidekiq', '~> 7.2'
gem 'sidekiq-status', '~> 3.0'  # Job status tracking
gem 'sidekiq-scheduler', '~> 5.0'  # Cron-like scheduled jobs
```

**config/sidekiq.yml**:
```yaml
---
:concurrency: 5
:max_retries: 3
:queues:
  - [critical, 3]
  - [default, 2]
  - [mining, 1]
  - [low, 1]

# Scheduled jobs
:schedule:
  cleanup_old_jobs:
    cron: '0 3 * * *'  # Daily at 3 AM
    class: CleanupJobsWorker
    queue: low

  update_difficulty:
    every: '1h'
    class: DifficultyAdjustmentWorker
    queue: default
```

**config/initializers/sidekiq.rb**:
```ruby
require 'sidekiq'
require 'sidekiq-status'
require 'sidekiq/web'

Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    network_timeout: 5,
    pool_timeout: 5
  }

  # Enable job status tracking
  Sidekiq::Status.configure_server_middleware config, expiration: 30.minutes
  Sidekiq::Status.configure_client_middleware config, expiration: 30.minutes

  # Lifecycle hooks
  config.on(:startup) do
    LOGGER.info "Sidekiq server started"
  end

  config.on(:shutdown) do
    LOGGER.info "Sidekiq server shutting down"
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    network_timeout: 5,
    pool_timeout: 5
  }

  # Enable job status tracking
  Sidekiq::Status.configure_client_middleware config, expiration: 30.minutes
end

# Death handler - log failed jobs after all retries
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, ex) do
    LOGGER.error "Job died after retries",
      jid: job['jid'],
      class: job['class'],
      error: ex.message
  end
end
```

### 2. Base Worker Class

**app/workers/application_worker.rb**:
```ruby
require 'sidekiq'
require 'sidekiq-status'

class ApplicationWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker  # Adds status tracking

  # Default options for all workers
  sidekiq_options retry: 3, backtrace: true

  # Override in subclasses for custom retry logic
  sidekiq_retry_in do |count, exception|
    case exception
    when ValidationError
      :kill  # Don't retry validation errors
    when Mongo::Error::OperationFailure
      30 * (count + 1)  # Exponential backoff for DB errors
    else
      60  # Default: retry after 1 minute
    end
  end

  def perform(*args)
    LOGGER.info "Starting job",
      worker: self.class.name,
      jid: jid,
      args: args

    start_time = Time.now

    begin
      execute(*args)

      LOGGER.info "Job completed",
        worker: self.class.name,
        jid: jid,
        duration: Time.now - start_time
    rescue => e
      LOGGER.error "Job failed",
        worker: self.class.name,
        jid: jid,
        error: e.message,
        backtrace: e.backtrace.first(5)
      raise
    end
  end

  # Subclasses implement this
  def execute(*args)
    raise NotImplementedError
  end

  # Helper to update job progress
  def update_progress(current, total, message: nil)
    at(current, total, message)
  end
end
```

### 3. Mining Worker

**app/workers/mining_worker.rb**:
```ruby
class MiningWorker < ApplicationWorker
  sidekiq_options queue: :mining, retry: 2

  # Override retry logic - don't retry mining failures
  sidekiq_retry_in do |count, exception|
    case exception
    when ValidationError, MiningError
      :kill
    else
      300  # 5 minutes for other errors
    end
  end

  def execute(blockchain_id, miner_address, options = {})
    blockchain = Blockchain.find(blockchain_id)

    total(100)  # Set total progress to 100%
    at(5, "Fetching pending transactions")

    # Get transactions from mempool
    tx_list = blockchain.mempool.get_transactions_for_mining(options['tx_limit'] || 100)

    at(10, "Creating coinbase transaction")

    # Calculate total fees
    total_fees = tx_list.sum { |tx| tx['fee'] || 0 }

    # Coinbase transaction
    coinbase_tx = {
      from: "COINBASE",
      to: miner_address,
      amount: blockchain.block_reward + total_fees,
      timestamp: Time.now.to_i,
      data: "Block reward + fees for block #{blockchain.blocks.count + 1}",
      fee: 0.0
    }

    all_transactions = [coinbase_tx] + tx_list

    at(20, "Calculating Merkle root")

    # Calculate Merkle root
    merkle_tree = ChainForge::MerkleTree.new(all_transactions.map(&:to_json))
    merkle_root = merkle_tree.root

    at(30, "Starting mining process")

    # Get difficulty
    difficulty = options['difficulty'] || blockchain.calculate_next_difficulty(blockchain.blocks.count + 1)

    # Create block (unmined)
    block = Block.new(
      blockchain: blockchain,
      index: blockchain.blocks.count + 1,
      timestamp: Time.now.to_i,
      transactions: all_transactions,
      previous_hash: blockchain.blocks.last&.hash || '0',
      nonce: 0,
      difficulty: difficulty,
      merkle_root: merkle_root,
      miner: miner_address
    )

    # Mine the block with progress updates
    target = '0' * difficulty
    start_time = Time.now
    attempt = 0
    update_interval = 10_000  # Update every 10k attempts

    loop do
      block.nonce = attempt
      block.calculate_hash

      # Update progress every 10k attempts
      if attempt % update_interval == 0
        progress = [30 + (attempt / 100_000), 95].min  # Progress from 30% to 95%
        at(progress, "Mining: #{attempt} attempts, #{(Time.now - start_time).round(2)}s")
      end

      if block.hash.start_with?(target)
        at(95, "Valid hash found!")
        break
      end

      attempt += 1

      # Safety check: max 10 minutes
      if Time.now - start_time > 600
        raise MiningError, "Mining timeout after 10 minutes (#{attempt} attempts)"
      end
    end

    # Record mining duration
    block.mining_duration = Time.now - start_time
    block.save!

    at(98, "Cleaning up mempool")

    # Remove mined transactions from mempool
    blockchain.mempool.remove_transactions(tx_list.map { |tx| tx['tx_hash'] })

    # Update blockchain
    blockchain.inc(total_blocks: 1)
    blockchain.set(last_block_hash: block.hash)

    at(100, "Mining complete!")

    LOGGER.info "Block mined successfully",
      blockchain_id: blockchain_id,
      block_index: block.index,
      nonce: block.nonce,
      attempts: attempt,
      duration: block.mining_duration,
      difficulty: difficulty,
      miner: miner_address

    # Return result
    {
      block_id: block.id.to_s,
      block_index: block.index,
      hash: block.hash,
      nonce: block.nonce,
      difficulty: difficulty,
      mining_duration: block.mining_duration.round(3),
      attempts: attempt,
      transactions_count: all_transactions.length,
      reward: blockchain.block_reward + total_fees
    }
  end
end

# Custom error
class MiningError < StandardError; end
```

### 4. Batch Mining Worker

**app/workers/batch_mining_worker.rb**:
```ruby
class BatchMiningWorker < ApplicationWorker
  sidekiq_options queue: :mining, retry: 1

  def execute(blockchain_id, miner_address, count, options = {})
    total(count)

    results = []
    count.times do |i|
      at(i, "Mining block #{i + 1}/#{count}")

      job_id = MiningWorker.perform_async(
        blockchain_id,
        miner_address,
        options
      )

      results << { block_number: i + 1, job_id: job_id }
    end

    at(count, "All mining jobs queued")

    {
      message: "#{count} mining jobs queued",
      jobs: results
    }
  end
end
```

### 5. Cleanup Worker

**app/workers/cleanup_jobs_worker.rb**:
```ruby
class CleanupJobsWorker < ApplicationWorker
  sidekiq_options queue: :low, retry: 1

  def execute
    # Clean up job status data older than 7 days
    cutoff = 7.days.ago.to_i

    REDIS.with do |redis|
      # Find old job keys
      keys = redis.keys("sidekiq:status:*")
      deleted = 0

      keys.each do |key|
        created_at = redis.hget(key, "update_time")
        if created_at && created_at.to_i < cutoff
          redis.del(key)
          deleted += 1
        end
      end

      LOGGER.info "Cleaned up old jobs", deleted: deleted
      deleted
    end
  end
end
```

### 6. Difficulty Adjustment Worker

**app/workers/difficulty_adjustment_worker.rb**:
```ruby
class DifficultyAdjustmentWorker < ApplicationWorker
  sidekiq_options queue: :default, retry: 1

  def execute
    updated = 0

    Blockchain.all.each do |blockchain|
      next unless blockchain.blocks.count >= Blockchain::ADJUSTMENT_INTERVAL

      old_difficulty = blockchain.current_difficulty
      new_difficulty = blockchain.calculate_next_difficulty(blockchain.blocks.count + 1)

      if old_difficulty != new_difficulty
        blockchain.update!(current_difficulty: new_difficulty)
        updated += 1

        LOGGER.info "Difficulty adjusted",
          blockchain_id: blockchain.id.to_s,
          old_difficulty: old_difficulty,
          new_difficulty: new_difficulty
      end
    end

    { blockchains_updated: updated }
  end
end
```

### 7. Job Model

**src/models/mining_job.rb**:
```ruby
class MiningJob
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :blockchain

  field :job_id, type: String
  field :miner_address, type: String
  field :status, type: String, default: 'queued'  # queued, working, complete, failed
  field :progress, type: Integer, default: 0
  field :progress_message, type: String
  field :result, type: Hash
  field :error, type: String
  field :started_at, type: Time
  field :completed_at, type: Time
  field :duration, type: Float

  index({ job_id: 1 }, { unique: true })
  index({ blockchain_id: 1, created_at: -1 })
  index({ miner_address: 1, created_at: -1 })
  index({ status: 1, created_at: -1 })

  validates :job_id, presence: true, uniqueness: true
  validates :miner_address, presence: true
  validates :status, inclusion: { in: %w[queued working complete failed] }

  # Create from Sidekiq job
  def self.create_from_job(job_id, blockchain_id, miner_address)
    create!(
      job_id: job_id,
      blockchain_id: blockchain_id,
      miner_address: miner_address,
      status: 'queued',
      started_at: Time.now
    )
  end

  # Update from Sidekiq status
  def update_from_sidekiq
    status_data = Sidekiq::Status.get_all(job_id)
    return unless status_data

    self.status = status_data['status'] || 'queued'
    self.progress = status_data['pct_complete'].to_i if status_data['pct_complete']
    self.progress_message = status_data['message'] if status_data['message']

    if status == 'complete' && !completed_at
      self.completed_at = Time.now
      self.duration = (completed_at - started_at).round(3)
    end

    save!
  end

  # Check if job is done
  def done?
    %w[complete failed].include?(status)
  end

  # Get full job info
  def full_info
    update_from_sidekiq unless done?

    {
      job_id: job_id,
      blockchain_id: blockchain_id.to_s,
      miner_address: miner_address,
      status: status,
      progress: progress,
      progress_message: progress_message,
      result: result,
      error: error,
      started_at: started_at&.iso8601,
      completed_at: completed_at&.iso8601,
      duration: duration,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end
end
```

### 8. API Updates

**app.rb** (updated endpoints):
```ruby
# Mine block asynchronously
post '/api/v1/chain/:id/block' do
  content_type :json

  blockchain = find_blockchain(params[:id])

  # Validate miner address
  miner_address = parsed_body['miner_address']
  halt 400, { error: 'miner_address is required' }.to_json unless miner_address

  # Options
  options = {
    'difficulty' => parsed_body['difficulty'],
    'tx_limit' => parsed_body['tx_limit'] || 100
  }

  # Queue mining job
  job_id = MiningWorker.perform_async(
    blockchain.id.to_s,
    miner_address,
    options
  )

  # Create job record
  mining_job = MiningJob.create_from_job(job_id, blockchain.id, miner_address)

  LOGGER.info "Mining job queued",
    blockchain_id: blockchain.id.to_s,
    job_id: job_id,
    miner_address: miner_address

  status 202  # Accepted
  {
    message: "Mining job queued",
    job_id: job_id,
    status_url: "/api/v1/jobs/#{job_id}",
    blockchain_id: blockchain.id.to_s
  }.to_json
end

# Mine multiple blocks in batch
post '/api/v1/chain/:id/mine/batch' do
  content_type :json

  blockchain = find_blockchain(params[:id])

  miner_address = parsed_body['miner_address']
  count = parsed_body['count'].to_i

  halt 400, { error: 'miner_address is required' }.to_json unless miner_address
  halt 400, { error: 'count must be between 1 and 100' }.to_json unless count.between?(1, 100)

  options = {
    'difficulty' => parsed_body['difficulty'],
    'tx_limit' => parsed_body['tx_limit'] || 100
  }

  job_id = BatchMiningWorker.perform_async(
    blockchain.id.to_s,
    miner_address,
    count,
    options
  )

  status 202
  {
    message: "Batch mining job queued",
    job_id: job_id,
    count: count,
    status_url: "/api/v1/jobs/#{job_id}"
  }.to_json
end

# Get job status
get '/api/v1/jobs/:job_id' do
  content_type :json

  job_id = params[:job_id]

  # Try to find in database first
  mining_job = MiningJob.find_by(job_id: job_id)

  if mining_job
    mining_job.full_info.to_json
  else
    # Fallback to Sidekiq status
    status_data = Sidekiq::Status.get_all(job_id)

    halt 404, { error: 'Job not found' }.to_json unless status_data

    {
      job_id: job_id,
      status: status_data['status'],
      progress: status_data['pct_complete'].to_i,
      message: status_data['message'],
      updated_at: Time.at(status_data['update_time'].to_i).iso8601
    }.to_json
  end
end

# List jobs for a blockchain
get '/api/v1/chain/:id/jobs' do
  content_type :json

  blockchain = find_blockchain(params[:id])

  jobs = MiningJob.where(blockchain_id: blockchain.id)
                  .order_by(created_at: :desc)
                  .limit(50)

  {
    blockchain_id: blockchain.id.to_s,
    jobs: jobs.map(&:full_info)
  }.to_json
end

# Cancel a job
delete '/api/v1/jobs/:job_id' do
  content_type :json

  job_id = params[:job_id]

  # Kill job in Sidekiq
  killed = Sidekiq::Status.cancel(job_id)

  if killed
    # Update database
    mining_job = MiningJob.find_by(job_id: job_id)
    mining_job&.update!(status: 'failed', error: 'Cancelled by user')

    { message: 'Job cancelled successfully', job_id: job_id }.to_json
  else
    halt 404, { error: 'Job not found or already completed' }.to_json
  end
end

# Sidekiq Web UI (protected)
require 'sidekiq/web'

# Basic auth for Sidekiq Web UI
Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  [user, password] == [
    ENV.fetch('SIDEKIQ_USERNAME', 'admin'),
    ENV.fetch('SIDEKIQ_PASSWORD', 'password')
  ]
end

mount Sidekiq::Web, at: '/sidekiq'
```

### 9. CLI Commands

**cli.rb** (new commands):
```ruby
desc 'mine CHAIN_ID', 'Queue a mining job'
option :miner, type: :string, aliases: '-m', required: true, desc: 'Miner address'
option :difficulty, type: :numeric, aliases: '-d', desc: 'Custom difficulty'
option :async, type: :boolean, default: true, desc: 'Queue async job (default: true)'
def mine(chain_id)
  if options[:async]
    # Async mining
    response = client.post("/chain/#{chain_id}/block", {
      miner_address: options[:miner],
      difficulty: options[:difficulty]
    }.compact)

    puts paint.green("✓ Mining job queued")
    puts "Job ID: #{response['job_id']}"
    puts "Status URL: #{response['status_url']}"

    # Optionally wait for completion
    if yes?("Wait for mining to complete?")
      wait_for_job(response['job_id'])
    end
  else
    # Synchronous mining (for testing)
    puts paint.yellow("⚠ Synchronous mining - this may take a while...")
    # Direct mining without Sidekiq
  end
end

desc 'mine:batch CHAIN_ID COUNT', 'Queue multiple mining jobs'
option :miner, type: :string, aliases: '-m', required: true
option :difficulty, type: :numeric, aliases: '-d'
def mine_batch(chain_id, count)
  response = client.post("/chain/#{chain_id}/mine/batch", {
    miner_address: options[:miner],
    count: count.to_i,
    difficulty: options[:difficulty]
  }.compact)

  puts paint.green("✓ #{count} mining jobs queued")
  puts "Batch Job ID: #{response['job_id']}"
end

desc 'job:status JOB_ID', 'Check status of a mining job'
def job_status(job_id)
  response = client.get("/jobs/#{job_id}")

  puts "\nJob Status: #{response['job_id']}"
  puts "Status: #{colorize_status(response['status'])}"
  puts "Progress: #{response['progress']}%"
  puts "Message: #{response['progress_message']}" if response['progress_message']

  if response['result']
    puts "\nResult:"
    puts "  Block Index: #{response['result']['block_index']}"
    puts "  Hash: #{response['result']['hash']}"
    puts "  Duration: #{response['result']['mining_duration']}s"
    puts "  Attempts: #{response['result']['attempts']}"
  end

  if response['error']
    puts paint.red("\nError: #{response['error']}")
  end
end

desc 'job:list CHAIN_ID', 'List mining jobs for a blockchain'
option :limit, type: :numeric, default: 10
def job_list(chain_id)
  response = client.get("/chain/#{chain_id}/jobs")

  jobs = response['jobs'].take(options[:limit])

  puts "\nMining Jobs for Chain #{chain_id}:"
  puts

  jobs.each do |job|
    status_color = case job['status']
    when 'complete' then :green
    when 'failed' then :red
    when 'working' then :yellow
    else :blue
    end

    puts "#{paint.send(status_color, job['status'].upcase.ljust(10))} | #{job['job_id']} | #{job['progress']}%"
  end
end

desc 'job:cancel JOB_ID', 'Cancel a mining job'
def job_cancel(job_id)
  response = client.delete("/jobs/#{job_id}")
  puts paint.green("✓ #{response['message']}")
rescue => e
  puts paint.red("✗ #{e.message}")
end

private

def wait_for_job(job_id)
  print "Mining"

  loop do
    response = client.get("/jobs/#{job_id}")

    case response['status']
    when 'complete'
      puts " ✓ Complete!"
      puts "\nBlock mined:"
      puts "  Index: #{response['result']['block_index']}"
      puts "  Hash: #{response['result']['hash']}"
      puts "  Duration: #{response['result']['mining_duration']}s"
      break
    when 'failed'
      puts " ✗ Failed!"
      puts "Error: #{response['error']}"
      break
    else
      print "."
      sleep 2
    end
  end
end

def colorize_status(status)
  case status
  when 'complete' then paint.green(status)
  when 'failed' then paint.red(status)
  when 'working' then paint.yellow(status)
  else paint.blue(status)
  end
end
```

### 10. Docker Setup

**docker-compose.yml** (updated):
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "1910:1910"
    environment:
      - REDIS_URL=redis://redis:6379/0
      - MONGODB_URI=mongodb://mongo:27017/chainforge
      - RACK_ENV=production
    depends_on:
      - redis
      - mongo
    command: bundle exec rackup -o 0.0.0.0 -p 1910

  # Sidekiq worker
  worker:
    build: .
    environment:
      - REDIS_URL=redis://redis:6379/0
      - MONGODB_URI=mongodb://mongo:27017/chainforge
      - RACK_ENV=production
    depends_on:
      - redis
      - mongo
    command: bundle exec sidekiq -r ./app.rb -C config/sidekiq.yml
    deploy:
      replicas: 3  # Run 3 workers

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --appendfsync everysec

  mongo:
    image: mongo:7
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db

volumes:
  redis_data:
  mongo_data:
```

**Procfile** (for Heroku/production):
```
web: bundle exec rackup -o 0.0.0.0 -p $PORT
worker: bundle exec sidekiq -r ./app.rb -C config/sidekiq.yml
```

### 11. Tests

**spec/workers/mining_worker_spec.rb**:
```ruby
RSpec.describe MiningWorker do
  let(:blockchain) { create(:blockchain, current_difficulty: 2) }
  let(:miner_address) { "miner123" }

  before do
    # Add some transactions to mempool
    3.times do |i|
      blockchain.mempool.add_transaction({
        from: "user#{i}",
        to: "recipient#{i}",
        amount: 10.0 + i,
        timestamp: Time.now.to_i,
        fee: 0.1 * (i + 1)
      })
    end
  end

  describe '#execute' do
    it 'mines a block successfully' do
      result = MiningWorker.new.execute(
        blockchain.id.to_s,
        miner_address,
        {}
      )

      expect(result).to include(
        :block_id,
        :block_index,
        :hash,
        :nonce,
        :difficulty,
        :mining_duration,
        :attempts,
        :transactions_count,
        :reward
      )

      expect(result[:difficulty]).to eq(2)
      expect(result[:transactions_count]).to eq(4)  # 3 + 1 coinbase

      # Verify block was saved
      block = Block.find(result[:block_id])
      expect(block.hash).to start_with('00')
      expect(block.miner).to eq(miner_address)
    end

    it 'includes coinbase transaction' do
      result = MiningWorker.new.execute(
        blockchain.id.to_s,
        miner_address,
        {}
      )

      block = Block.find(result[:block_id])
      coinbase = block.transactions.first

      expect(coinbase['from']).to eq('COINBASE')
      expect(coinbase['to']).to eq(miner_address)
      expect(coinbase['amount']).to be > blockchain.block_reward
    end

    it 'cleans mempool after mining' do
      expect {
        MiningWorker.new.execute(blockchain.id.to_s, miner_address, {})
      }.to change { blockchain.mempool.pending_transactions.count }.from(3).to(0)
    end

    it 'respects custom difficulty' do
      result = MiningWorker.new.execute(
        blockchain.id.to_s,
        miner_address,
        { 'difficulty' => 3 }
      )

      expect(result[:difficulty]).to eq(3)

      block = Block.find(result[:block_id])
      expect(block.hash).to start_with('000')
    end

    it 'updates progress during mining' do
      # Mock Sidekiq::Status to capture progress updates
      progress_updates = []

      allow_any_instance_of(MiningWorker).to receive(:at) do |_, current, message|
        progress_updates << { current: current, message: message }
      end

      MiningWorker.new.execute(blockchain.id.to_s, miner_address, {})

      expect(progress_updates).not_to be_empty
      expect(progress_updates.first).to include(current: 5)
      expect(progress_updates.last).to include(current: 100)
    end
  end

  describe 'async execution' do
    it 'queues job and returns job_id' do
      job_id = MiningWorker.perform_async(
        blockchain.id.to_s,
        miner_address,
        {}
      )

      expect(job_id).to be_present
      expect(Sidekiq::Status.status(job_id)).to eq(:queued).or eq(:working)
    end

    it 'can be monitored via Sidekiq::Status', :sidekiq do
      job_id = MiningWorker.perform_async(
        blockchain.id.to_s,
        miner_address,
        { 'difficulty' => 1 }  # Easy for fast testing
      )

      # Process jobs
      Sidekiq::Worker.drain_all

      expect(Sidekiq::Status.complete?(job_id)).to be true
    end
  end
end
```

**spec/models/mining_job_spec.rb**:
```ruby
RSpec.describe MiningJob do
  let(:blockchain) { create(:blockchain) }
  let(:job_id) { SecureRandom.uuid }
  let(:miner_address) { "miner123" }

  describe '.create_from_job' do
    it 'creates job record' do
      job = MiningJob.create_from_job(job_id, blockchain.id, miner_address)

      expect(job).to be_persisted
      expect(job.job_id).to eq(job_id)
      expect(job.status).to eq('queued')
      expect(job.miner_address).to eq(miner_address)
    end
  end

  describe '#update_from_sidekiq' do
    let(:mining_job) { create(:mining_job, job_id: job_id) }

    it 'updates status from Sidekiq' do
      allow(Sidekiq::Status).to receive(:get_all).with(job_id).and_return({
        'status' => 'working',
        'pct_complete' => '50',
        'message' => 'Mining in progress'
      })

      mining_job.update_from_sidekiq

      expect(mining_job.status).to eq('working')
      expect(mining_job.progress).to eq(50)
      expect(mining_job.progress_message).to eq('Mining in progress')
    end
  end

  describe '#done?' do
    it 'returns true for completed jobs' do
      job = create(:mining_job, status: 'complete')
      expect(job.done?).to be true
    end

    it 'returns true for failed jobs' do
      job = create(:mining_job, status: 'failed')
      expect(job.done?).to be true
    end

    it 'returns false for working jobs' do
      job = create(:mining_job, status: 'working')
      expect(job.done?).to be false
    end
  end
end
```

**spec/requests/async_mining_spec.rb**:
```ruby
RSpec.describe 'Async Mining API' do
  let(:blockchain) { create(:blockchain) }
  let(:miner_address) { "miner_test_123" }

  describe 'POST /api/v1/chain/:id/block' do
    it 'queues mining job and returns 202' do
      post "/api/v1/chain/#{blockchain.id}/block", {
        miner_address: miner_address
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(202)

      json = JSON.parse(last_response.body)
      expect(json['job_id']).to be_present
      expect(json['status_url']).to include('/jobs/')
    end

    it 'requires miner_address' do
      post "/api/v1/chain/#{blockchain.id}/block", {}.to_json,
        { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['error']).to include('miner_address')
    end
  end

  describe 'GET /api/v1/jobs/:job_id' do
    let(:job_id) { MiningWorker.perform_async(blockchain.id.to_s, miner_address, {}) }

    before do
      MiningJob.create_from_job(job_id, blockchain.id, miner_address)
    end

    it 'returns job status' do
      get "/api/v1/jobs/#{job_id}"

      expect(last_response.status).to eq(200)

      json = JSON.parse(last_response.body)
      expect(json['job_id']).to eq(job_id)
      expect(json['status']).to be_in(%w[queued working complete failed])
    end

    it 'returns 404 for non-existent job' do
      get "/api/v1/jobs/non-existent-id"

      expect(last_response.status).to eq(404)
    end
  end

  describe 'DELETE /api/v1/jobs/:job_id' do
    let(:job_id) { MiningWorker.perform_async(blockchain.id.to_s, miner_address, {}) }

    it 'cancels the job' do
      delete "/api/v1/jobs/#{job_id}"

      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['message']).to include('cancelled')
    end
  end

  describe 'POST /api/v1/chain/:id/mine/batch' do
    it 'queues batch mining jobs' do
      post "/api/v1/chain/#{blockchain.id}/mine/batch", {
        miner_address: miner_address,
        count: 5
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(202)

      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(5)
      expect(json['job_id']).to be_present
    end

    it 'validates count range' do
      post "/api/v1/chain/#{blockchain.id}/mine/batch", {
        miner_address: miner_address,
        count: 150
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(400)
    end
  end
end
```

## Performance Benchmarks

| Scenario | Synchronous | Async (Sidekiq) | Improvement |
|----------|-------------|-----------------|-------------|
| API Response Time | ~30-60s (blocked) | ~50ms | 600-1200x |
| Concurrent Mining | 1 block at a time | N workers in parallel | Nx throughput |
| Request Timeout | Common at difficulty > 3 | Never | ∞ |
| User Experience | Poor (waiting) | Excellent (immediate) | 🎉 |

## Monitoring & Observability

**Sidekiq Web UI** accessible at `/sidekiq`:
- Real-time job queue stats
- Failed job inspection
- Retry management
- Performance metrics
- Worker status

**Custom Metrics** (add to health endpoint):
```ruby
get '/health' do
  sidekiq_stats = Sidekiq::Stats.new

  {
    # ... existing checks ...
    sidekiq: {
      processed: sidekiq_stats.processed,
      failed: sidekiq_stats.failed,
      queues: sidekiq_stats.queues,
      workers: sidekiq_stats.workers_size,
      busy: sidekiq_stats.processes_size
    }
  }.to_json
end
```

## Environment Variables

```bash
# Redis
REDIS_URL=redis://localhost:6379/0

# Sidekiq
SIDEKIQ_CONCURRENCY=5
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=your-secure-password

# MongoDB
MONGODB_URI=mongodb://localhost:27017/chainforge
```

## Migration Guide

### From Synchronous to Async

**Before** (v2):
```ruby
# Direct mining - blocks for minutes
post '/api/v1/chain/:id/block' do
  blockchain.add_block(data, difficulty)  # Takes 30-60s
end
```

**After** (private fork):
```ruby
# Async mining - returns immediately
post '/api/v1/chain/:id/block' do
  job_id = MiningWorker.perform_async(...)  # Returns in <50ms
  status 202
  { job_id: job_id }.to_json
end
```

## Criterios de Aceptación

- [ ] Sidekiq configurado con Redis
- [ ] MiningWorker implementado con progress tracking
- [ ] BatchMiningWorker para mining masivo
- [ ] MiningJob model persiste job info
- [ ] API POST /chain/:id/block retorna job_id (202)
- [ ] API GET /jobs/:id retorna status y progress
- [ ] API DELETE /jobs/:id cancela jobs
- [ ] API POST /chain/:id/mine/batch para batch mining
- [ ] CLI commands: mine, job:status, job:list, job:cancel
- [ ] Sidekiq Web UI protegido con basic auth
- [ ] Docker Compose incluye workers
- [ ] Tests completos (workers, models, API)
- [ ] Cleanup worker elimina jobs viejos
- [ ] Progress updates cada 10k attempts
- [ ] Error handling y retry logic

## Educational Value

Este task enseña:
- **Background job processing** - Patrón fundamental en web apps modernas
- **Asynchronous architecture** - Separación de request/response del processing
- **Job queues** - Redis como message broker
- **Worker pools** - Horizontal scaling pattern
- **Progress tracking** - User feedback en long-running operations
- **Fault tolerance** - Retry logic y error handling
- **Monitoring** - Observability de background workers

Tecnologías como Sidekiq son usadas por:
- **GitHub** - Para git operations, webhooks
- **Shopify** - Para order processing
- **Airbnb** - Para booking confirmations
- **Stripe** - Para payment processing

## Security Considerations

1. **Sidekiq Web UI**: Proteger con autenticación fuerte
2. **Job validation**: Validar miner_address antes de queueing
3. **Rate limiting**: Limitar jobs por usuario/IP
4. **Resource limits**: Max mining duration (10 min timeout)
5. **Queue priority**: Separar queues por criticidad

## Referencias

- [Sidekiq Documentation](https://github.com/mperham/sidekiq/wiki)
- [Sidekiq Best Practices](https://github.com/mperham/sidekiq/wiki/Best-Practices)
- [Sidekiq Status](https://github.com/utgarda/sidekiq-status)
- [Background Job Processing in Ruby](https://www.cloudamqp.com/blog/background-processing-in-ruby.html)
- [Async Mining Pattern](https://bitcoin.org/en/developer-guide#mining)
