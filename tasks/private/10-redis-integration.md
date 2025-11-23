# Task 10: Redis Integration

**PR**: #18
**Fase**: 4 - Infrastructure
**Complejidad**: Medium
**Estimación**: 4-5 días
**Prioridad**: P1
**Dependencias**: Task 02 (Health & Metrics) - beneficial for monitoring

## Objetivo

Integrar Redis como backend para rate limiting persistente, caching de datos frecuentes, y session storage para el mempool, mejorando performance y escalabilidad.

## Motivación

**Problemas actuales**:
- Rate limiting en memoria se pierde al restart
- No hay caching de queries frecuentes
- Mempool podría beneficiarse de storage más rápido

**Solución**: Redis como capa intermedia entre application y MongoDB:
- **Rate limiting persistente** - Sobrevive restarts
- **Cache layer** - Reduce carga en MongoDB
- **Fast mempool storage** - Transactions pending en Redis
- **Session management** - Para features futuras

**Educational value**: Enseña arquitectura multi-tier, caching strategies, y uso de Redis (usado en producción por Twitter, GitHub, Stack Overflow).

## Cambios Técnicos

### 1. Setup & Configuration

**Gemfile**:
```ruby
gem 'redis', '~> 5.0'
gem 'connection_pool', '~> 2.4'  # Connection pooling
gem 'hiredis', '~> 0.6'  # Faster Redis protocol parser (opcional)
```

**Dockerfile updates**:
```dockerfile
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "1910:1910"
    environment:
      - REDIS_URL=redis://redis:6379/0
      - MONGODB_URI=mongodb://mongo:27017/chainforge
    depends_on:
      - redis
      - mongo

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

**Config file**: `config/redis.rb`

```ruby
require 'redis'
require 'connection_pool'

module ChainForge
  class RedisConfig
    REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
    POOL_SIZE = ENV.fetch('REDIS_POOL_SIZE', '5').to_i
    POOL_TIMEOUT = ENV.fetch('REDIS_POOL_TIMEOUT', '5').to_i

    # TTL constants (in seconds)
    CACHE_TTL_SHORT = 60          # 1 minute
    CACHE_TTL_MEDIUM = 300        # 5 minutes
    CACHE_TTL_LONG = 3600         # 1 hour
    CACHE_TTL_DAY = 86400         # 24 hours

    # Redis connection pool
    def self.pool
      @pool ||= ConnectionPool.new(size: POOL_SIZE, timeout: POOL_TIMEOUT) do
        Redis.new(
          url: REDIS_URL,
          driver: :hiredis,  # Optional: faster protocol parser
          reconnect_attempts: 3,
          reconnect_delay: 0.5,
          reconnect_delay_max: 5.0
        )
      end
    end

    # Health check
    def self.healthy?
      pool.with { |redis| redis.ping == 'PONG' }
    rescue Redis::CannotConnectError, Redis::TimeoutError
      false
    end

    # Get info
    def self.info
      pool.with do |redis|
        info = redis.info
        {
          connected: true,
          version: info['redis_version'],
          used_memory: info['used_memory_human'],
          connected_clients: info['connected_clients'].to_i,
          uptime_seconds: info['uptime_in_seconds'].to_i
        }
      end
    rescue => e
      {
        connected: false,
        error: e.message
      }
    end
  end
end

# Global alias for convenience
REDIS = ChainForge::RedisConfig.pool
```

### 2. Persistent Rate Limiting

**Archivo**: `config/rack_attack.rb` (actualizado)

```ruby
require 'rack/attack'
require_relative 'redis'

# Use Redis for Rack::Attack cache
Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(
  ChainForge::RedisConfig.pool
)

# Rate limits
Rack::Attack.throttle('api/ip', limit: 100, period: 60) do |req|
  req.ip if req.path.start_with?('/api/')
end

Rack::Attack.throttle('api/mining', limit: 10, period: 60) do |req|
  req.ip if req.path == '/api/v1/chain/:id/block' && req.post?
end

# Blocklist
Rack::Attack.blocklist('block malicious IPs') do |req|
  # Check Redis for blocked IPs
  REDIS.with { |redis| redis.sismember('blocked_ips', req.ip) }
end

# Custom response
Rack::Attack.throttled_responder = lambda do |env|
  retry_after = env['rack.attack.match_data'][:period]

  [
    429,
    {
      'Content-Type' => 'application/json',
      'Retry-After' => retry_after.to_s
    },
    [{
      error: 'Rate limit exceeded',
      retry_after: retry_after
    }.to_json]
  ]
end
```

### 3. Cache Layer

**Archivo**: `lib/cache_helper.rb`

```ruby
require_relative '../config/redis'

module ChainForge
  module CacheHelper
    # Fetch with caching
    def cache_fetch(key, ttl: RedisConfig::CACHE_TTL_MEDIUM)
      cached = REDIS.with { |redis| redis.get(key) }

      if cached
        LOGGER.debug "Cache hit", key: key
        return JSON.parse(cached, symbolize_names: true)
      end

      LOGGER.debug "Cache miss", key: key
      value = yield

      if value
        REDIS.with do |redis|
          redis.setex(key, ttl, value.to_json)
        end
      end

      value
    end

    # Invalidate cache
    def cache_invalidate(*keys)
      REDIS.with do |redis|
        redis.del(*keys) if keys.any?
      end

      LOGGER.debug "Cache invalidated", keys: keys
    end

    # Invalidate pattern
    def cache_invalidate_pattern(pattern)
      REDIS.with do |redis|
        keys = redis.keys(pattern)
        redis.del(*keys) if keys.any?
        keys.length
      end
    end

    # Get cache stats
    def cache_stats
      REDIS.with do |redis|
        info = redis.info('stats')
        {
          hits: info['keyspace_hits'].to_i,
          misses: info['keyspace_misses'].to_i,
          hit_rate: calculate_hit_rate(info)
        }
      end
    end

    private

    def calculate_hit_rate(info)
      hits = info['keyspace_hits'].to_i
      misses = info['keyspace_misses'].to_i
      total = hits + misses

      return 0 if total.zero?
      (hits.to_f / total * 100).round(2)
    end
  end
end
```

### 4. Redis-backed Mempool

**Archivo**: `src/models/mempool.rb` (refactored)

```ruby
class Mempool
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :blockchain

  # Add transaction to Redis
  def add_transaction(tx_data)
    tx = Transaction.new(tx_data)

    unless tx.valid?
      raise ValidationError, "Invalid transaction: #{tx.errors.full_messages.join(', ')}"
    end

    # Add to Redis sorted set (sorted by fee)
    redis_key = "mempool:#{blockchain_id}:transactions"

    REDIS.with do |redis|
      redis.zadd(redis_key, tx.fee, tx.as_json.to_json)
      redis.expire(redis_key, 86400)  # 24 hours
    end

    # Backup to MongoDB
    self.pending_transactions << tx.as_json
    save!

    LOGGER.info "Transaction added to mempool (Redis)",
      blockchain_id: blockchain.id.to_s,
      tx_hash: tx.tx_hash

    tx
  end

  # Get transactions from Redis (faster)
  def get_transactions_for_mining(limit = 100)
    redis_key = "mempool:#{blockchain_id}:transactions"

    REDIS.with do |redis|
      tx_data = redis.zrevrange(redis_key, 0, limit - 1)
      tx_data.map { |json| JSON.parse(json, symbolize_names: true) }
    end
  end

  # Remove from Redis
  def remove_transactions(tx_hashes)
    redis_key = "mempool:#{blockchain_id}:transactions"
    removed = 0

    REDIS.with do |redis|
      tx_hashes.each do |tx_hash|
        # Find and remove
        all_txs = redis.zrange(redis_key, 0, -1)
        all_txs.each do |json|
          tx = JSON.parse(json, symbolize_names: true)
          if tx[:tx_hash] == tx_hash
            redis.zrem(redis_key, json)
            removed += 1
            break
          end
        end
      end
    end

    removed
  end

  # Stats from Redis
  def stats
    redis_key = "mempool:#{blockchain_id}:transactions"

    REDIS.with do |redis|
      count = redis.zcard(redis_key)
      txs = redis.zrevrange(redis_key, 0, -1).map { |json| JSON.parse(json, symbolize_names: true) }

      {
        pending_count: count,
        total_fees: txs.sum { |tx| tx[:fee] || 0 }.round(4),
        avg_fee: count > 0 ? (txs.sum { |tx| tx[:fee] || 0 } / count).round(4) : 0
      }
    end
  end
end
```

### 5. API Endpoints

```ruby
# Health check with Redis
get '/health' do
  content_type :json

  checks = {
    database: check_database,
    redis: ChainForge::RedisConfig.healthy? ? 'ok' : 'error',
    chain_integrity: check_chain_integrity
  }

  all_healthy = checks.values.all? { |v| v == 'ok' }
  status all_healthy ? 200 : 503

  {
    status: all_healthy ? 'healthy' : 'unhealthy',
    timestamp: Time.now.utc.iso8601,
    checks: checks,
    redis_info: ChainForge::RedisConfig.info
  }.to_json
end

# Redis stats
get '/api/v1/redis/stats' do
  content_type :json

  {
    redis: ChainForge::RedisConfig.info,
    cache: cache_stats
  }.to_json
end

# Clear cache
delete '/api/v1/cache' do
  content_type :json

  pattern = params[:pattern] || '*'
  count = cache_invalidate_pattern(pattern)

  {
    message: "Cache cleared",
    keys_deleted: count
  }.to_json
end
```

### 6. CLI Commands

```ruby
desc 'redis:info', 'Show Redis connection info'
def redis_info
  info = ChainForge::RedisConfig.info

  if info[:connected]
    puts paint.green("✓ Redis connected")
    puts "Version: #{info[:version]}"
    puts "Memory: #{info[:used_memory]}"
  else
    puts paint.red("✗ Redis not connected")
  end
end

desc 'redis:flush', 'Clear Redis cache'
option :pattern, type: :string, default: '*'
def redis_flush
  count = cache_invalidate_pattern(options[:pattern])
  puts paint.green("✓ Cache cleared (#{count} keys)")
end
```

## Tests

```ruby
RSpec.describe ChainForge::CacheHelper do
  include ChainForge::CacheHelper

  before { REDIS.with { |r| r.flushdb } }

  describe '#cache_fetch' do
    it 'caches value on first call' do
      call_count = 0

      2.times do
        cache_fetch('test_key') do
          call_count += 1
          { value: 'hello' }
        end
      end

      expect(call_count).to eq(1)
    end
  end
end
```

## Environment Variables

```bash
REDIS_URL=redis://localhost:6379/0
REDIS_POOL_SIZE=5
REDIS_POOL_TIMEOUT=5
```

## Criterios de Aceptación

- [ ] Redis connection pool configurado
- [ ] Rack::Attack usa Redis para rate limiting
- [ ] Cache helper implementado
- [ ] Mempool usa Redis
- [ ] Health check incluye Redis
- [ ] API endpoint /api/v1/redis/stats funciona
- [ ] CLI commands implementados
- [ ] Tests completos
- [ ] Docker compose configurado

## Performance Improvements

| Operation | Before | After | Improvement |
|-----------|--------|-------|-------------|
| Get balance | ~50ms | ~5ms | 10x |
| List pending txs | ~30ms | ~3ms | 10x |
| Add to mempool | ~20ms | ~8ms | 2.5x |

## Referencias

- [Redis Documentation](https://redis.io/documentation)
- [Redis Ruby Client](https://github.com/redis/redis-rb)
- [Connection Pool](https://github.com/mperham/connection_pool)
