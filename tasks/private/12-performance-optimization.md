# Task 12: Performance Optimization

**PR**: #20
**Fase**: 4 - Infrastructure
**Complejidad**: Medium
**Estimación**: 5-6 días
**Prioridad**: P2
**Dependencias**: Task 10 (Redis Integration), Task 05 (Pagination)

## Objetivo

Optimizar el rendimiento de ChainForge mediante indexes de MongoDB, query optimization, caching strategies inteligentes, connection pooling, y benchmarking comprehensivo. El objetivo es reducir latencia de API en 10x y soportar 1000+ req/s.

## Motivación

**Problemas actuales**:
- Queries lentas en colecciones grandes (sin indexes)
- Full collection scans para búsquedas
- N+1 queries en relaciones (blockchain → blocks)
- No hay caching de datos frecuentemente accedidos
- No hay benchmarking sistemático
- Connection pool pequeño para MongoDB

**Solución**: Optimización multi-capa:
- **Database layer** - Indexes estratégicos, query optimization
- **Application layer** - Eager loading, batch processing
- **Cache layer** - Redis para datos hot
- **Monitoring layer** - APM, query profiling, benchmarks

**Educational value**: Enseña técnicas de performance engineering, database optimization, profiling, y monitoring (skills críticas en producción).

## Cambios Técnicos

### 1. MongoDB Indexes

**Script de migración**: `db/migrations/001_create_indexes.rb`

```ruby
# MongoDB index migration
class CreateIndexes
  def self.up
    puts "Creating MongoDB indexes..."

    # Blockchain indexes
    Blockchain.collection.indexes.create_many([
      { key: { created_at: -1 } },
      { key: { name: 1 }, unique: true },
      { key: { total_blocks: -1 } },
      { key: { current_difficulty: 1 } },
      { key: { created_at: -1, total_blocks: -1 } }  # Compound index
    ])

    # Block indexes
    Block.collection.indexes.create_many([
      { key: { blockchain_id: 1, index: -1 } },  # Primary query pattern
      { key: { hash: 1 }, unique: true },
      { key: { previous_hash: 1 } },
      { key: { miner: 1, created_at: -1 } },  # Miner history
      { key: { difficulty: 1 } },
      { key: { created_at: -1 } },
      { key: { blockchain_id: 1, created_at: -1 } },  # Compound
      { key: { merkle_root: 1 } }
    ])

    # Transaction indexes
    Transaction.collection.indexes.create_many([
      { key: { tx_hash: 1 }, unique: true },
      { key: { from: 1, created_at: -1 } },
      { key: { to: 1, created_at: -1 } },
      { key: { block_index: 1 } },
      { key: { confirmed: 1, created_at: -1 } },
      { key: { timestamp: -1 } },
      # Compound indexes for common queries
      { key: { from: 1, confirmed: 1 } },
      { key: { to: 1, confirmed: 1 } }
    ])

    # Mempool indexes
    Mempool.collection.indexes.create_many([
      { key: { blockchain_id: 1 }, unique: true },
      { key: { total_transactions: -1 } }
    ])

    # MiningJob indexes
    MiningJob.collection.indexes.create_many([
      { key: { job_id: 1 }, unique: true },
      { key: { blockchain_id: 1, created_at: -1 } },
      { key: { miner_address: 1, created_at: -1 } },
      { key: { status: 1, created_at: -1 } },
      { key: { created_at: -1 } }
    ])

    puts "✓ Indexes created successfully"
  end

  def self.down
    puts "Dropping indexes..."

    [Blockchain, Block, Transaction, Mempool, MiningJob].each do |model|
      model.collection.indexes.drop_all
    end

    puts "✓ Indexes dropped"
  end

  def self.status
    puts "\nIndex Status:"
    puts "=" * 60

    [Blockchain, Block, Transaction, Mempool, MiningJob].each do |model|
      puts "\n#{model.name}:"
      model.collection.indexes.each do |index|
        puts "  #{index['name']}: #{index['key'].inspect}"
      end
    end
  end
end
```

**Rake task**: `lib/tasks/db.rake`

```ruby
namespace :db do
  desc 'Run migrations'
  task :migrate do
    require_relative '../db/migrations/001_create_indexes'
    CreateIndexes.up
  end

  desc 'Rollback migrations'
  task :rollback do
    require_relative '../db/migrations/001_create_indexes'
    CreateIndexes.down
  end

  desc 'Show index status'
  task :index_status do
    require_relative '../db/migrations/001_create_indexes'
    CreateIndexes.status
  end
end
```

### 2. Query Optimization

**Modelo actualizado**: `src/models/blockchain.rb`

```ruby
class Blockchain
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :blocks, dependent: :destroy
  has_one :mempool, dependent: :destroy

  # Indexes defined in model
  index({ name: 1 }, { unique: true })
  index({ created_at: -1 })
  index({ total_blocks: -1 })

  # Query scopes for common patterns
  scope :recent, -> { order_by(created_at: -1) }
  scope :popular, -> { order_by(total_blocks: -1) }
  scope :with_blocks, -> { includes(:blocks) }  # Eager loading

  # Optimized queries
  def recent_blocks(limit = 10)
    # Use only_fields to select specific fields
    blocks.order_by(index: -1)
          .limit(limit)
          .only(:id, :index, :hash, :timestamp, :difficulty, :nonce)
  end

  def block_at_index(index)
    # Use find_by with index
    blocks.find_by(index: index)
  end

  def blocks_by_miner(miner_address, limit = 100)
    blocks.where(miner: miner_address)
          .order_by(created_at: -1)
          .limit(limit)
  end

  # Aggregate queries
  def mining_stats
    # Use MongoDB aggregation pipeline
    blocks.collection.aggregate([
      { '$match': { blockchain_id: id } },
      { '$group': {
        _id: '$miner',
        blocks_mined: { '$sum': 1 },
        total_difficulty: { '$sum': '$difficulty' },
        avg_mining_time: { '$avg': '$mining_duration' }
      }},
      { '$sort': { blocks_mined: -1 } },
      { '$limit': 10 }
    ]).to_a
  end

  # Cached stats
  def stats_cached
    cache_key = "blockchain:#{id}:stats"

    cache_fetch(cache_key, ttl: RedisConfig::CACHE_TTL_SHORT) do
      {
        total_blocks: blocks.count,
        total_transactions: blocks.sum { |b| b.transactions.length },
        current_difficulty: current_difficulty,
        last_block: blocks.last&.as_json(only: [:index, :hash, :timestamp])
      }
    end
  end
end
```

**Modelo actualizado**: `src/models/block.rb`

```ruby
class Block
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :blockchain

  # Indexes
  index({ blockchain_id: 1, index: -1 })
  index({ hash: 1 }, { unique: true })
  index({ miner: 1, created_at: -1 })

  # Query scopes
  scope :recent, -> { order_by(created_at: -1) }
  scope :by_difficulty, ->(diff) { where(difficulty: diff) }
  scope :by_miner, ->(miner) { where(miner: miner) }

  # Optimized serialization
  def as_json_light
    {
      id: id.to_s,
      index: index,
      hash: hash,
      timestamp: timestamp,
      difficulty: difficulty
    }
  end

  def as_json_full
    {
      id: id.to_s,
      index: index,
      hash: hash,
      previous_hash: previous_hash,
      timestamp: timestamp,
      nonce: nonce,
      difficulty: difficulty,
      merkle_root: merkle_root,
      miner: miner,
      mining_duration: mining_duration,
      transactions_count: transactions.length,
      created_at: created_at.iso8601
    }
  end
end
```

### 3. Connection Pooling

**config/mongoid.yml**:

```yaml
development:
  clients:
    default:
      database: chainforge_development
      hosts:
        - localhost:27017
      options:
        # Connection pool settings
        min_pool_size: 5
        max_pool_size: 25
        wait_queue_timeout: 5
        # Socket settings
        connect_timeout: 10
        socket_timeout: 10
        # Retry settings
        max_read_retries: 5
        retry_reads: true
        retry_writes: true
        # Performance
        compressors: ['zstd']
        server_selection_timeout: 30

production:
  clients:
    default:
      uri: <%= ENV['MONGODB_URI'] %>
      options:
        min_pool_size: 10
        max_pool_size: 50
        wait_queue_timeout: 10
        connect_timeout: 15
        socket_timeout: 15
        max_read_retries: 5
        retry_reads: true
        retry_writes: true
        compressors: ['zstd']
        server_selection_timeout: 30
        # Production optimizations
        max_idle_time: 60
        heartbeat_frequency: 10
```

### 4. Advanced Caching

**lib/cache_strategies.rb**:

```ruby
module ChainForge
  module CacheStrategies
    # Cache-aside pattern
    def self.cache_aside(key, ttl: 300)
      cached = REDIS.with { |r| r.get(key) }

      if cached
        JSON.parse(cached, symbolize_names: true)
      else
        value = yield
        REDIS.with { |r| r.setex(key, ttl, value.to_json) } if value
        value
      end
    end

    # Write-through cache
    def self.cache_write_through(key, value, ttl: 300)
      # Write to cache first
      REDIS.with { |r| r.setex(key, ttl, value.to_json) }
      # Then persist to DB
      yield
    end

    # Cache with tags for invalidation
    def self.cache_with_tags(key, tags: [], ttl: 300)
      cached = REDIS.with { |r| r.get(key) }

      if cached
        JSON.parse(cached, symbolize_names: true)
      else
        value = yield

        if value
          REDIS.with do |redis|
            # Store value
            redis.setex(key, ttl, value.to_json)

            # Add to tag sets
            tags.each do |tag|
              redis.sadd("cache:tag:#{tag}", key)
              redis.expire("cache:tag:#{tag}", ttl)
            end
          end
        end

        value
      end
    end

    # Invalidate by tag
    def self.invalidate_tag(tag)
      REDIS.with do |redis|
        keys = redis.smembers("cache:tag:#{tag}")
        redis.del(*keys) if keys.any?
        redis.del("cache:tag:#{tag}")
        keys.length
      end
    end

    # Multi-level cache (Redis + memory)
    class MultiCache
      def initialize
        @memory_cache = {}
        @memory_cache_mutex = Mutex.new
      end

      def fetch(key, ttl: 300, memory_ttl: 60)
        # Check memory first
        if memory_value = get_from_memory(key)
          return memory_value
        end

        # Check Redis
        redis_value = REDIS.with { |r| r.get(key) }
        if redis_value
          value = JSON.parse(redis_value, symbolize_names: true)
          set_in_memory(key, value, memory_ttl)
          return value
        end

        # Generate value
        value = yield

        if value
          # Store in Redis
          REDIS.with { |r| r.setex(key, ttl, value.to_json) }
          # Store in memory
          set_in_memory(key, value, memory_ttl)
        end

        value
      end

      private

      def get_from_memory(key)
        @memory_cache_mutex.synchronize do
          entry = @memory_cache[key]
          return nil unless entry

          if Time.now > entry[:expires_at]
            @memory_cache.delete(key)
            nil
          else
            entry[:value]
          end
        end
      end

      def set_in_memory(key, value, ttl)
        @memory_cache_mutex.synchronize do
          @memory_cache[key] = {
            value: value,
            expires_at: Time.now + ttl
          }
        end
      end
    end
  end
end
```

### 5. API Response Optimization

**app/helpers/api_helper.rb**:

```ruby
module ApiHelper
  # Efficient pagination with cursor-based pagination
  def cursor_paginate(collection, cursor: nil, limit: 20)
    query = collection

    if cursor
      # Decode cursor (base64 encoded timestamp)
      timestamp = Time.at(Base64.decode64(cursor).to_i)
      query = query.where(:created_at.lt => timestamp)
    end

    items = query.order_by(created_at: -1).limit(limit + 1).to_a
    has_next = items.length > limit
    items = items.take(limit)

    next_cursor = if has_next && items.last
      Base64.strict_encode64(items.last.created_at.to_i.to_s)
    end

    {
      data: items,
      pagination: {
        cursor: next_cursor,
        has_next: has_next,
        limit: limit
      }
    }
  end

  # ETags for caching
  def with_etag(entity)
    etag = Digest::MD5.hexdigest(entity.updated_at.to_s)

    if request.env['HTTP_IF_NONE_MATCH'] == etag
      halt 304  # Not Modified
    end

    headers 'ETag' => etag
    entity
  end

  # Compression
  def compress_response(data)
    if request.env['HTTP_ACCEPT_ENCODING']&.include?('gzip')
      compressed = ActiveSupport::Gzip.compress(data.to_json)
      headers 'Content-Encoding' => 'gzip'
      compressed
    else
      data.to_json
    end
  end

  # Selective field loading
  def serialize_with_fields(object, fields: nil)
    if fields
      object.as_json(only: fields.split(',').map(&:to_sym))
    else
      object.as_json
    end
  end
end
```

**app.rb** (optimized endpoints):

```ruby
helpers ApiHelper

# Optimized blockchain list
get '/api/v1/chains' do
  content_type :json

  # Use cursor pagination for large datasets
  result = cursor_paginate(
    Blockchain.all,
    cursor: params[:cursor],
    limit: params[:limit]&.to_i || 20
  )

  # Cache response
  cache_key = "chains:list:#{params[:cursor]}:#{params[:limit]}"

  cached = cache_fetch(cache_key, ttl: 60) do
    result[:data].map do |chain|
      {
        id: chain.id.to_s,
        name: chain.name,
        total_blocks: chain.total_blocks,
        current_difficulty: chain.current_difficulty,
        created_at: chain.created_at.iso8601
      }
    end
  end

  {
    chains: cached,
    pagination: result[:pagination]
  }.to_json
end

# Optimized block list with ETags
get '/api/v1/chain/:id/blocks' do
  content_type :json

  blockchain = find_blockchain(params[:id])

  # Check ETag
  last_modified = blockchain.blocks.max(:updated_at)
  etag = Digest::MD5.hexdigest("#{blockchain.id}-#{last_modified}")

  if request.env['HTTP_IF_NONE_MATCH'] == etag
    halt 304
  end

  headers 'ETag' => etag

  # Use projection to load only needed fields
  fields = params[:fields]

  blocks = if fields
    blockchain.blocks.only(*fields.split(',').map(&:to_sym))
  else
    blockchain.blocks.only(:id, :index, :hash, :timestamp, :difficulty)
  end

  cursor_paginate(blocks, cursor: params[:cursor], limit: params[:limit]&.to_i || 50).to_json
end

# Optimized balance lookup with caching
get '/api/v1/balance/:address' do
  content_type :json

  address = params[:address]
  cache_key = "balance:#{address}"

  balance_data = cache_fetch(cache_key, ttl: 30) do
    received = Transaction.where(to: address, confirmed: true).sum(:amount)
    sent = Transaction.where(from: address, confirmed: true).sum(:amount)

    {
      address: address,
      received: received.round(4),
      sent: sent.round(4),
      balance: (received - sent).round(4),
      updated_at: Time.now.utc.iso8601
    }
  end

  balance_data.to_json
end
```

### 6. Query Profiling

**lib/query_profiler.rb**:

```ruby
module ChainForge
  class QueryProfiler
    def self.enable!
      # Enable MongoDB query logging
      Mongoid.logger.level = Logger::DEBUG

      # Add query time middleware
      Mongoid::QueryCache.cache do
        yield
      end
    end

    def self.slow_queries(threshold_ms: 100)
      # Parse MongoDB logs for slow queries
      log_file = 'log/mongodb.log'

      return [] unless File.exist?(log_file)

      slow = []

      File.readlines(log_file).each do |line|
        if line =~ /COMMAND.*(\d+)ms/
          duration = $1.to_i
          slow << { query: line, duration: duration } if duration > threshold_ms
        end
      end

      slow.sort_by { |q| -q[:duration] }
    end

    def self.explain_query(model, query)
      model.where(query).explain
    end

    # Middleware to log slow queries
    class SlowQueryLogger
      def initialize(app, threshold_ms: 100)
        @app = app
        @threshold_ms = threshold_ms
      end

      def call(env)
        start = Time.now
        status, headers, response = @app.call(env)
        duration = ((Time.now - start) * 1000).round(2)

        if duration > @threshold_ms
          LOGGER.warn "Slow request",
            path: env['PATH_INFO'],
            method: env['REQUEST_METHOD'],
            duration: duration,
            threshold: @threshold_ms
        end

        [status, headers, response]
      end
    end
  end
end

# Use in app.rb
use ChainForge::QueryProfiler::SlowQueryLogger, threshold_ms: 100
```

### 7. Benchmarking Suite

**benchmark/api_benchmark.rb**:

```ruby
require 'benchmark'
require 'httparty'

class ApiBenchmark
  BASE_URL = ENV.fetch('API_URL', 'http://localhost:1910')

  def self.run_all
    puts "ChainForge API Benchmarks"
    puts "=" * 60

    benchmark_list_chains
    benchmark_get_blockchain
    benchmark_list_blocks
    benchmark_get_block
    benchmark_balance_lookup
    benchmark_mining

    puts "\n✓ Benchmarks complete"
  end

  def self.benchmark_list_chains
    puts "\n## List Chains"

    times = Benchmark.measure do
      100.times do
        HTTParty.get("#{BASE_URL}/api/v1/chains")
      end
    end

    avg = (times.real / 100 * 1000).round(2)
    puts "Average: #{avg}ms per request"
    puts "Throughput: #{(100 / times.real).round(2)} req/s"
  end

  def self.benchmark_get_blockchain
    # Create test blockchain
    response = HTTParty.post("#{BASE_URL}/api/v1/chain",
      body: { name: "benchmark_chain_#{Time.now.to_i}" }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    chain_id = JSON.parse(response.body)['blockchain']['id']

    puts "\n## Get Blockchain"

    times = Benchmark.measure do
      1000.times do
        HTTParty.get("#{BASE_URL}/api/v1/chain/#{chain_id}")
      end
    end

    avg = (times.real / 1000 * 1000).round(2)
    puts "Average: #{avg}ms per request"
    puts "Throughput: #{(1000 / times.real).round(2)} req/s"
  end

  def self.benchmark_list_blocks
    puts "\n## List Blocks (paginated)"

    # Use existing chain with blocks
    chains = JSON.parse(HTTParty.get("#{BASE_URL}/api/v1/chains").body)
    chain_id = chains['chains'].first['id']

    times = Benchmark.measure do
      100.times do
        HTTParty.get("#{BASE_URL}/api/v1/chain/#{chain_id}/blocks?limit=50")
      end
    end

    avg = (times.real / 100 * 1000).round(2)
    puts "Average: #{avg}ms per request"
    puts "Throughput: #{(100 / times.real).round(2)} req/s"
  end

  def self.benchmark_get_block
    puts "\n## Get Single Block"

    chains = JSON.parse(HTTParty.get("#{BASE_URL}/api/v1/chains").body)
    chain_id = chains['chains'].first['id']

    blocks = JSON.parse(HTTParty.get("#{BASE_URL}/api/v1/chain/#{chain_id}/blocks?limit=1").body)
    block_id = blocks['data'].first['id']

    times = Benchmark.measure do
      1000.times do
        HTTParty.get("#{BASE_URL}/api/v1/chain/#{chain_id}/block/#{block_id}")
      end
    end

    avg = (times.real / 1000 * 1000).round(2)
    puts "Average: #{avg}ms per request"
    puts "Throughput: #{(1000 / times.real).round(2)} req/s"
  end

  def self.benchmark_balance_lookup
    puts "\n## Balance Lookup"

    address = "test_address_#{rand(1000)}"

    times = Benchmark.measure do
      100.times do
        HTTParty.get("#{BASE_URL}/api/v1/balance/#{address}")
      end
    end

    avg = (times.real / 100 * 1000).round(2)
    puts "Average: #{avg}ms per request"
    puts "Throughput: #{(100 / times.real).round(2)} req/s"
  end

  def self.benchmark_mining
    puts "\n## Queue Mining Job"

    chains = JSON.parse(HTTParty.get("#{BASE_URL}/api/v1/chains").body)
    chain_id = chains['chains'].first['id']

    times = Benchmark.measure do
      10.times do
        HTTParty.post("#{BASE_URL}/api/v1/chain/#{chain_id}/block",
          body: { miner_address: "benchmark_miner", difficulty: 1 }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      end
    end

    avg = (times.real / 10 * 1000).round(2)
    puts "Average: #{avg}ms per request"
    puts "Throughput: #{(10 / times.real).round(2)} req/s"
  end
end

# Run if executed directly
if __FILE__ == $0
  ApiBenchmark.run_all
end
```

**CLI command**:

```ruby
desc 'benchmark', 'Run API benchmarks'
option :url, type: :string, default: 'http://localhost:1910', desc: 'API URL'
def benchmark
  ENV['API_URL'] = options[:url]
  require_relative '../benchmark/api_benchmark'
  ApiBenchmark.run_all
end
```

### 8. Application Performance Monitoring

**lib/apm.rb**:

```ruby
module ChainForge
  class APM
    def self.instrument
      # Request tracking
      ActiveSupport::Notifications.subscribe('process_action.rack') do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)

        LOGGER.info "Request completed",
          path: event.payload[:path],
          method: event.payload[:method],
          status: event.payload[:status],
          duration: event.duration.round(2),
          db_runtime: event.payload[:db_runtime]&.round(2),
          view_runtime: event.payload[:view_runtime]&.round(2)
      end

      # Database query tracking
      ActiveSupport::Notifications.subscribe('query.mongoid') do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)

        if event.duration > 100
          LOGGER.warn "Slow query",
            query: event.payload[:selector],
            duration: event.duration.round(2)
        end
      end

      # Cache hit/miss tracking
      ActiveSupport::Notifications.subscribe('cache_read.active_support') do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)

        LOGGER.debug "Cache #{event.payload[:hit] ? 'hit' : 'miss'}",
          key: event.payload[:key]
      end
    end

    def self.metrics
      {
        requests: {
          total: request_count,
          avg_duration: avg_request_duration
        },
        database: {
          queries: query_count,
          avg_duration: avg_query_duration,
          slow_queries: slow_query_count
        },
        cache: {
          hits: cache_hit_count,
          misses: cache_miss_count,
          hit_rate: cache_hit_rate
        }
      }
    end
  end
end
```

## Performance Targets

### Before Optimization

| Metric | Value |
|--------|-------|
| List chains (100 chains) | ~500ms |
| Get blockchain | ~150ms |
| List blocks (50 blocks) | ~800ms |
| Get single block | ~100ms |
| Balance lookup | ~300ms |
| Queue mining job | ~80ms |
| Throughput | ~50 req/s |

### After Optimization

| Metric | Value | Improvement |
|--------|-------|-------------|
| List chains (100 chains) | ~50ms | 10x |
| Get blockchain | ~15ms | 10x |
| List blocks (50 blocks) | ~80ms | 10x |
| Get single block | ~10ms | 10x |
| Balance lookup | ~30ms | 10x |
| Queue mining job | ~8ms | 10x |
| Throughput | ~1000 req/s | 20x |

## Monitoring Dashboard

**health endpoint updated**:

```ruby
get '/api/v1/metrics' do
  content_type :json

  {
    database: {
      mongodb: {
        connected: Mongoid.connected?,
        pool_size: Mongoid.default_client.cluster.servers.first.pool.size,
        queries_per_sec: query_rate
      }
    },
    cache: {
      redis: ChainForge::RedisConfig.info,
      hit_rate: cache_hit_rate,
      memory_usage: redis_memory_usage
    },
    performance: {
      avg_response_time: avg_response_time,
      p95_response_time: p95_response_time,
      throughput: current_throughput
    },
    system: {
      ruby_version: RUBY_VERSION,
      memory_usage: memory_usage_mb,
      cpu_usage: cpu_usage_percent
    }
  }.to_json
end
```

## Environment Variables

```bash
# MongoDB connection pool
MONGODB_MIN_POOL_SIZE=10
MONGODB_MAX_POOL_SIZE=50

# Redis
REDIS_POOL_SIZE=10

# Performance
ENABLE_QUERY_CACHE=true
ENABLE_COMPRESSION=true
SLOW_QUERY_THRESHOLD_MS=100
```

## CLI Commands

```ruby
desc 'db:migrate', 'Run database migrations'
def db_migrate
  require_relative '../db/migrations/001_create_indexes'
  CreateIndexes.up
  puts paint.green("✓ Migrations completed")
end

desc 'db:index:status', 'Show index status'
def db_index_status
  require_relative '../db/migrations/001_create_indexes'
  CreateIndexes.status
end

desc 'perf:profile', 'Profile slow queries'
option :threshold, type: :numeric, default: 100, desc: 'Threshold in ms'
def perf_profile
  slow = ChainForge::QueryProfiler.slow_queries(threshold_ms: options[:threshold])

  if slow.empty?
    puts paint.green("✓ No slow queries found")
  else
    puts paint.yellow("Found #{slow.length} slow queries:")
    slow.take(10).each_with_index do |q, i|
      puts "\n#{i + 1}. Duration: #{q[:duration]}ms"
      puts q[:query]
    end
  end
end

desc 'cache:clear', 'Clear all caches'
def cache_clear
  count = cache_invalidate_pattern('*')
  puts paint.green("✓ Cleared #{count} cache keys")
end

desc 'cache:stats', 'Show cache statistics'
def cache_stats
  stats = ChainForge::RedisConfig.info

  puts "\nRedis Cache Statistics:"
  puts "Memory: #{stats[:used_memory]}"
  puts "Connected clients: #{stats[:connected_clients]}"
  puts "Uptime: #{stats[:uptime_seconds]}s"
end
```

## Tests

**spec/performance/optimization_spec.rb**:

```ruby
RSpec.describe 'Performance Optimization' do
  describe 'MongoDB indexes' do
    it 'has index on blockchain name' do
      indexes = Blockchain.collection.indexes.map { |i| i['key'] }
      expect(indexes).to include({ 'name' => 1 })
    end

    it 'has compound index on block queries' do
      indexes = Block.collection.indexes.map { |i| i['key'] }
      expect(indexes).to include({ 'blockchain_id' => 1, 'index' => -1 })
    end

    it 'has unique index on block hash' do
      index = Block.collection.indexes.find { |i| i['key'] == { 'hash' => 1 } }
      expect(index['unique']).to be true
    end
  end

  describe 'Query optimization' do
    let(:blockchain) { create(:blockchain) }

    before do
      # Create test data
      10.times { |i| create(:block, blockchain: blockchain, index: i + 1) }
    end

    it 'uses index for block lookup' do
      explain = blockchain.blocks.where(index: 5).explain

      # Check that index is used (not collection scan)
      expect(explain['executionStats']['executionStages']['stage']).to eq('FETCH')
      expect(explain['executionStats']['totalDocsExamined']).to be <= 1
    end

    it 'efficiently fetches recent blocks' do
      expect {
        blockchain.recent_blocks(5)
      }.to perform_under(10).ms  # Custom RSpec matcher
    end
  end

  describe 'Caching' do
    let(:blockchain) { create(:blockchain) }

    it 'caches blockchain stats' do
      # First call - cache miss
      expect(REDIS).to receive(:get).and_return(nil)
      expect(REDIS).to receive(:setex)

      blockchain.stats_cached

      # Second call - cache hit
      expect(REDIS).to receive(:get).and_return({ total_blocks: 10 }.to_json)

      blockchain.stats_cached
    end

    it 'invalidates cache on blockchain update' do
      cache_key = "blockchain:#{blockchain.id}:stats"

      # Populate cache
      blockchain.stats_cached

      # Update blockchain
      blockchain.update(name: 'new_name')
      cache_invalidate(cache_key)

      # Cache should be empty
      cached = REDIS.with { |r| r.get(cache_key) }
      expect(cached).to be_nil
    end
  end

  describe 'API response time' do
    it 'responds to /chains under 50ms', :benchmark do
      time = Benchmark.realtime do
        get '/api/v1/chains'
      end

      expect(time * 1000).to be < 50
    end

    it 'responds to /chain/:id under 20ms', :benchmark do
      blockchain = create(:blockchain)

      time = Benchmark.realtime do
        get "/api/v1/chain/#{blockchain.id}"
      end

      expect(time * 1000).to be < 20
    end
  end
end
```

## Criterios de Aceptación

- [ ] MongoDB indexes creados para todas las colecciones
- [ ] Query optimization implementado (scopes, eager loading)
- [ ] Connection pooling configurado (MongoDB y Redis)
- [ ] Caching strategies implementadas (cache-aside, write-through)
- [ ] Multi-level cache (memory + Redis) funcionando
- [ ] API responses optimizados con ETags
- [ ] Cursor-based pagination implementado
- [ ] Query profiler detecta slow queries
- [ ] Benchmark suite completo y ejecutable
- [ ] APM instrumentación activa
- [ ] Metrics endpoint /api/v1/metrics funciona
- [ ] CLI commands (db:migrate, perf:profile, cache:clear)
- [ ] Tests de performance completos
- [ ] Performance targets alcanzados (10x improvement)
- [ ] Documentación de optimizaciones

## Educational Value

Este task enseña:
- **Database optimization** - Indexes, query planning, aggregation pipelines
- **Caching strategies** - Cache-aside, write-through, multi-level
- **Connection pooling** - Resource management en producción
- **Query profiling** - Identificar bottlenecks con EXPLAIN
- **Benchmarking** - Medir performance objetivamente
- **APM** - Application Performance Monitoring
- **Load testing** - Evaluar throughput y latency
- **Cursor pagination** - Escalar a millones de registros

Técnicas usadas por:
- **Netflix** - Caching multi-tier con EVCache
- **Twitter** - Manhattan (distributed database) con aggressive caching
- **Facebook** - TAO (distributed data store) con read-through cache
- **Instagram** - PostgreSQL optimization con Redis cache

## Security Considerations

1. **Query injection**: Usar Mongoid query builder (no raw queries)
2. **Cache poisoning**: Validar data antes de cachear
3. **Resource exhaustion**: Limitar query complexity y result size
4. **Metrics endpoint**: Proteger con autenticación

## Referencias

- [MongoDB Performance Best Practices](https://www.mongodb.com/docs/manual/administration/analyzing-mongodb-performance/)
- [MongoDB Indexes](https://www.mongodb.com/docs/manual/indexes/)
- [Redis Caching Patterns](https://redis.io/docs/manual/patterns/)
- [Database Connection Pooling](https://en.wikipedia.org/wiki/Connection_pool)
- [High Performance Browser Networking](https://hpbn.co/)
