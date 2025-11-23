# Task 01: Structured Logging

**PR**: #9
**Fase**: 1 - Observabilidad
**Complejidad**: Small
**Estimación**: 3-5 días
**Prioridad**: P0 (Critical)
**Dependencias**: Ninguna

## Objetivo

Implementar logging estructurado con formato JSON y correlation IDs para facilitar debugging y análisis en producción.

## Motivación

**Problema actual**:
- Logs desestructurados difíciles de parsear
- No hay correlation entre requests relacionados
- No hay contexto suficiente para debugging

**Solución**:
- Logs en formato JSON
- Correlation IDs para tracing
- Niveles de log apropiados (DEBUG, INFO, WARN, ERROR)
- Contexto rico (timestamps, durations, metadata)

## Cambios Técnicos

### 1. Agregar Gem

```ruby
# Gemfile
gem 'semantic_logger', '~> 4.14'
gem 'amazing_print', '~> 1.5' # Para console pretty-print
```

### 2. Configuración de Logger

**Nuevo archivo**: `config/logger.rb`

```ruby
require 'semantic_logger'

# Formato JSON para production, colorizado para development
if ENV['RACK_ENV'] == 'production'
  SemanticLogger.add_appender(
    file_name: 'log/production.log',
    formatter: :json
  )
else
  SemanticLogger.add_appender(
    io: $stdout,
    formatter: :color
  )
end

# Configurar nivel de log
log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym
SemanticLogger.default_level = log_level

# Logger global
LOGGER = SemanticLogger['ChainForge']
```

### 3. Middleware para Correlation IDs

**Nuevo archivo**: `app/middleware/request_logger.rb`

```ruby
class RequestLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    correlation_id = request.env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid

    SemanticLogger.tagged(correlation_id: correlation_id) do
      LOGGER.info('Request started', {
        method: request.request_method,
        path: request.path,
        ip: request.ip
      })

      start_time = Time.now
      status, headers, response = @app.call(env)
      duration = ((Time.now - start_time) * 1000).round(2)

      LOGGER.info('Request completed', {
        method: request.request_method,
        path: request.path,
        status: status,
        duration_ms: duration
      })

      headers['X-Request-ID'] = correlation_id
      [status, headers, response]
    end
  end
end
```

### 4. Actualizar main.rb

```ruby
# main.rb
require_relative 'config/logger'
require_relative 'app/middleware/request_logger'

# Agregar middleware
use RequestLogger

# Reemplazar puts/print con LOGGER
# Antes:
# puts "Mining block with difficulty #{difficulty}"

# Después:
LOGGER.info('Mining block', { difficulty: difficulty, chain_id: chain_id })
```

### 5. Logging en Modelos

**Actualizar**: `src/blockchain.rb`

```ruby
class Blockchain
  include Mongoid::Document
  include SemanticLogger::Loggable

  def add_block(data, difficulty: 2)
    logger.debug('Adding block to chain', {
      chain_id: id,
      difficulty: difficulty,
      data_size: data.bytesize
    })

    # ... existing code ...

    logger.info('Block mined successfully', {
      chain_id: id,
      block_id: block.id,
      nonce: block.nonce,
      mining_time: mining_duration
    })

    block
  rescue => e
    logger.error('Failed to add block', { error: e.message, chain_id: id })
    raise
  end
end
```

**Actualizar**: `src/block.rb`

```ruby
class Block
  include Mongoid::Document
  include SemanticLogger::Loggable

  def mine_block
    logger.debug('Starting mining', { difficulty: difficulty })
    start_time = Time.now
    target = '0' * difficulty
    attempts = 0

    loop do
      calculate_hash
      attempts += 1

      if attempts % 10000 == 0
        logger.debug('Mining progress', {
          attempts: attempts,
          elapsed_seconds: (Time.now - start_time).round(2)
        })
      end

      break if _hash.start_with?(target)
      self.nonce += 1
    end

    duration = (Time.now - start_time).round(3)
    logger.info('Mining completed', {
      difficulty: difficulty,
      nonce: nonce,
      attempts: attempts,
      duration_seconds: duration,
      hashes_per_second: (attempts / duration).round(0)
    })

    _hash
  end
end
```

### 6. Logging en Endpoints

**Actualizar**: `main.rb` endpoints

```ruby
post '/chain/:id/block' do
  LOGGER.info('Block creation request', { chain_id: params[:id] })

  block_data = parse_json_body
  validation = BlockDataContract.new.call(block_data)

  if validation.failure?
    LOGGER.warn('Validation failed', { errors: validation.errors.to_h })
    halt 400, { errors: validation.errors.to_h }.to_json
  end

  # ... rest of endpoint ...
end
```

## Archivos a Modificar

- `Gemfile` - Agregar semantic_logger
- `main.rb` - Require logger config, agregar middleware
- `src/blockchain.rb` - Agregar logging
- `src/block.rb` - Agregar logging en mine_block
- `config/rack_attack.rb` - Log rate limit violations

## Archivos a Crear

- `config/logger.rb` - Configuración de logger
- `app/middleware/request_logger.rb` - Middleware de logging
- `log/.gitkeep` - Directorio para logs
- `.gitignore` - Agregar `log/*.log`

## Tests

### 1. Test de Configuración

**Nuevo**: `spec/config/logger_spec.rb`

```ruby
require 'spec_helper'

RSpec.describe 'Logger Configuration' do
  it 'configures semantic logger' do
    expect(SemanticLogger.appenders).not_to be_empty
  end

  it 'sets appropriate log level' do
    expect(SemanticLogger.default_level).to be_in([:debug, :info, :warn, :error])
  end

  it 'provides global LOGGER constant' do
    expect(defined?(LOGGER)).to eq('constant')
    expect(LOGGER).to be_a(SemanticLogger::Logger)
  end
end
```

### 2. Test de Request Logger Middleware

**Nuevo**: `spec/middleware/request_logger_spec.rb`

```ruby
require 'spec_helper'
require 'rack/test'

RSpec.describe RequestLogger do
  include Rack::Test::Methods

  let(:app) do
    Rack::Builder.new do
      use RequestLogger
      run ->(env) { [200, {'Content-Type' => 'text/plain'}, ['OK']] }
    end
  end

  it 'adds X-Request-ID header to response' do
    get '/'
    expect(last_response.headers).to have_key('X-Request-ID')
  end

  it 'uses provided X-Request-ID if present' do
    get '/', {}, {'HTTP_X_REQUEST_ID' => 'test-id-123'}
    expect(last_response.headers['X-Request-ID']).to eq('test-id-123')
  end

  it 'logs request start and completion' do
    expect(LOGGER).to receive(:info).with('Request started', anything).once
    expect(LOGGER).to receive(:info).with('Request completed', anything).once
    get '/'
  end
end
```

### 3. Test de Logging en Modelos

**Actualizar**: `spec/blockchain_spec.rb`

```ruby
describe '#add_block' do
  it 'logs block addition' do
    expect(blockchain.logger).to receive(:info).with('Block mined successfully', anything)
    blockchain.add_block('test data')
  end

  it 'logs error on failure' do
    allow(blockchain).to receive(:integrity_valid?).and_return(false)
    expect(blockchain.logger).to receive(:error).with('Failed to add block', anything)

    expect {
      blockchain.add_block('test')
    }.to raise_error
  end
end
```

## Environment Variables

```bash
# .env.example
LOG_LEVEL=info  # debug, info, warn, error
RACK_ENV=development  # development, test, production
```

## Formato de Log Esperado

### Development (Colorizado)
```
[2025-11-09 10:30:45.123] INFO [ChainForge] Request started -- {:method=>"POST", :path=>"/api/v1/chain", :ip=>"127.0.0.1"}
[2025-11-09 10:30:45.234] INFO [Blockchain] Block mined successfully -- {:chain_id=>"507f...", :nonce=>157, :mining_time=>0.11}
[2025-11-09 10:30:45.235] INFO [ChainForge] Request completed -- {:method=>"POST", :status=>200, :duration_ms=>112.5}
```

### Production (JSON)
```json
{
  "timestamp": "2025-11-09T10:30:45.123Z",
  "level": "info",
  "name": "ChainForge",
  "message": "Request started",
  "payload": {
    "method": "POST",
    "path": "/api/v1/chain",
    "ip": "127.0.0.1"
  },
  "tags": {
    "correlation_id": "uuid-123..."
  }
}
```

## Criterios de Aceptación

- [ ] semantic_logger instalado y configurado
- [ ] Logs en JSON en production, colorizados en development
- [ ] Correlation IDs en todos los requests
- [ ] X-Request-ID header en responses
- [ ] Logging en Blockchain#add_block y Block#mine_block
- [ ] Logging en todos los endpoints API
- [ ] Tests de logger configuration
- [ ] Tests de request logger middleware
- [ ] Tests de logging en modelos
- [ ] Documentación en CLAUDE.md sobre logging
- [ ] CI pasa con todos los tests

## Documentación

### Actualizar CLAUDE.md

Agregar sección:

```markdown
## Logging

ChainForge uses structured logging with semantic_logger:

- **Development**: Colorized output to stdout
- **Production**: JSON format to log/production.log
- **Levels**: DEBUG, INFO, WARN, ERROR
- **Correlation IDs**: X-Request-ID header for tracing

### Configuration

```bash
LOG_LEVEL=info  # Set log verbosity
RACK_ENV=production  # Controls log format
```

### Usage in Code

```ruby
LOGGER.info('Message', { key: 'value', context: data })
LOGGER.error('Error message', { error: exception.message })
```
```

### Actualizar README.md

Agregar en sección "Monitoring":

```markdown
### Logging

ChainForge uses structured logging for production observability:
- JSON-formatted logs for easy parsing
- Correlation IDs for request tracing
- Performance metrics (request duration, mining time)
- Configurable log levels
```

## Próximos Pasos

Después de completar esta tarea:
1. Verificar que logs se generan correctamente en dev y test
2. Continuar con Task 02 (Health & Metrics) que usará este logging
3. En futuras tareas, agregar logging a nuevas features

## Referencias

- [semantic_logger documentation](https://logger.rocketjob.io/)
- [JSON logging best practices](https://www.datadoghq.com/blog/json-logging-best-practices/)
- [Correlation IDs in microservices](https://blog.rapid7.com/2016/12/23/the-value-of-correlation-ids/)
