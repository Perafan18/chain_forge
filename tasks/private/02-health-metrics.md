# Task 02: Health Check & Metrics Endpoints

**PR**: #10
**Fase**: 1 - Observabilidad
**Complejidad**: Medium
**Estimación**: 4-6 días
**Prioridad**: P0 (Critical)
**Dependencias**: Task 01 (Structured Logging)

## Objetivo

Implementar endpoints de health check y métricas para monitoring y observabilidad en producción.

## Endpoints

### 1. Health Check: `GET /health`

**Response (200 OK)**:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-09T10:30:45Z",
  "checks": {
    "database": "ok",
    "chain_integrity": "ok"
  },
  "uptime_seconds": 12345
}
```

**Response (503 Service Unavailable)** si algún check falla:
```json
{
  "status": "unhealthy",
  "timestamp": "2025-11-09T10:30:45Z",
  "checks": {
    "database": "error",
    "chain_integrity": "ok"
  },
  "errors": ["MongoDB connection failed"]
}
```

### 2. Metrics: `GET /metrics`

**Formato Prometheus**:
```
# HELP chainforge_api_requests_total Total API requests
# TYPE chainforge_api_requests_total counter
chainforge_api_requests_total{method="POST",path="/api/v1/chain",status="200"} 42

# HELP chainforge_mining_duration_seconds Mining duration
# TYPE chainforge_mining_duration_seconds histogram
chainforge_mining_duration_seconds_bucket{difficulty="2",le="0.1"} 10
chainforge_mining_duration_seconds_bucket{difficulty="2",le="1.0"} 45
chainforge_mining_duration_seconds_sum{difficulty="2"} 23.5
chainforge_mining_duration_seconds_count{difficulty="2"} 50

# HELP chainforge_blocks_mined_total Total blocks mined
# TYPE chainforge_blocks_mined_total counter
chainforge_blocks_mined_total{difficulty="2"} 50
chainforge_blocks_mined_total{difficulty="3"} 12

# HELP chainforge_validation_failures_total Validation failures
# TYPE chainforge_validation_failures_total counter
chainforge_validation_failures_total 5
```

## Implementación

### Gemfile
```ruby
gem 'prometheus-client', '~> 4.2'
```

### config/metrics.rb
```ruby
require 'prometheus/client'

module Metrics
  class << self
    def registry
      @registry ||= Prometheus::Client.registry
    end

    def api_requests
      @api_requests ||= registry.counter(
        :chainforge_api_requests_total,
        docstring: 'Total API requests',
        labels: [:method, :path, :status]
      )
    end

    def mining_duration
      @mining_duration ||= registry.histogram(
        :chainforge_mining_duration_seconds,
        docstring: 'Mining duration in seconds',
        labels: [:difficulty],
        buckets: [0.1, 0.5, 1.0, 5.0, 10.0, 30.0, 60.0, 300.0]
      )
    end

    def blocks_mined
      @blocks_mined ||= registry.counter(
        :chainforge_blocks_mined_total,
        docstring: 'Total blocks mined',
        labels: [:difficulty]
      )
    end

    def validation_failures
      @validation_failures ||= registry.counter(
        :chainforge_validation_failures_total,
        docstring: 'Total validation failures'
      )
    end
  end
end
```

### app/middleware/metrics_middleware.rb
```ruby
class MetricsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    status, headers, response = @app.call(env)

    Metrics.api_requests.increment(
      labels: {
        method: request.request_method,
        path: request.path,
        status: status.to_s
      }
    )

    [status, headers, response]
  end
end
```

### main.rb - Health Endpoint
```ruby
get '/health' do
  content_type :json

  checks = {
    database: check_database,
    chain_integrity: check_chain_integrity
  }

  all_healthy = checks.values.all? { |v| v == 'ok' }
  status all_healthy ? 200 : 503

  {
    status: all_healthy ? 'healthy' : 'unhealthy',
    timestamp: Time.now.utc.iso8601,
    checks: checks,
    uptime_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i,
    errors: checks.select { |_, v| v != 'ok' }.keys
  }.to_json
end

helpers do
  def check_database
    Mongoid.default_client.command(ping: 1)
    'ok'
  rescue => e
    LOGGER.error('Database health check failed', error: e.message)
    'error'
  end

  def check_chain_integrity
    # Sample recent chains
    Blockchain.desc(:created_at).limit(5).each do |chain|
      return 'error' unless chain.integrity_valid?
    end
    'ok'
  rescue => e
    LOGGER.error('Chain integrity check failed', error: e.message)
    'error'
  end
end
```

### main.rb - Metrics Endpoint
```ruby
get '/metrics' do
  content_type 'text/plain'
  Prometheus::Client::Formats::Text.marshal(Metrics.registry)
end
```

### Instrumentar Block#mine_block
```ruby
def mine_block
  start_time = Time.now

  # ... existing mining code ...

  duration = Time.now - start_time
  Metrics.mining_duration.observe(duration, labels: { difficulty: difficulty.to_s })
  Metrics.blocks_mined.increment(labels: { difficulty: difficulty.to_s })

  _hash
end
```

### Instrumentar Validation Failures
```ruby
# In main.rb
if validation.failure?
  Metrics.validation_failures.increment
  LOGGER.warn('Validation failed', { errors: validation.errors.to_h })
  halt 400, { errors: validation.errors.to_h }.to_json
end
```

## Tests

### spec/health_spec.rb
```ruby
RSpec.describe 'GET /health' do
  it 'returns healthy status when all checks pass' do
    get '/health'
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    expect(json['status']).to eq('healthy')
  end

  it 'returns unhealthy when database is down' do
    allow(Mongoid.default_client).to receive(:command).and_raise(Mongo::Error)
    get '/health'
    expect(last_response.status).to eq(503)
    json = JSON.parse(last_response.body)
    expect(json['status']).to eq('unhealthy')
  end
end
```

### spec/metrics_spec.rb
```ruby
RSpec.describe 'GET /metrics' do
  it 'returns prometheus metrics' do
    get '/metrics'
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include('text/plain')
    expect(last_response.body).to include('chainforge_api_requests_total')
  end
end
```

## Criterios de Aceptación

- [ ] GET /health retorna 200 cuando todo está ok
- [ ] GET /health retorna 503 cuando hay fallas
- [ ] Health check valida MongoDB connection
- [ ] Health check valida chain integrity
- [ ] GET /metrics retorna formato Prometheus
- [ ] Métricas de API requests funcionan
- [ ] Métricas de mining duration funcionan
- [ ] Métricas de blocks mined funcionan
- [ ] Tests de health endpoint
- [ ] Tests de metrics endpoint
- [ ] Documentación actualizada

## Grafana Dashboard (Futuro)

Con estas métricas se puede crear dashboard con:
- Request rate (requests/second)
- Error rate (errors/total requests)
- Mining duration percentiles (p50, p95, p99)
- Blocks mined per difficulty
- Chain health status

## Referencias

- [Prometheus Client Ruby](https://github.com/prometheus/client_ruby)
- [Health Check API Pattern](https://microservices.io/patterns/observability/health-check-api.html)
