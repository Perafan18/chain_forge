# Task 04: OpenAPI Specification & Auto-Generated SDKs

**PR**: #12
**Fase**: 2 - Developer Experience
**Complejidad**: Medium
**Estimación**: 5-7 días
**Prioridad**: P0
**Dependencias**: None

## Objetivo

Crear especificación OpenAPI 3.0 del ChainForge API y auto-generar SDKs en múltiples lenguajes usando herramientas como `openapi-generator`.

## Ventajas vs SDK Manual

✅ **Un solo source of truth** (spec OpenAPI)
✅ **Múltiples lenguajes** automáticamente (Ruby, Python, JS, Go, etc.)
✅ **Siempre sincronizado** con el API
✅ **Documentación interactiva** (Swagger UI)
✅ **Validación automática** de requests/responses
✅ **Menor mantenimiento** a largo plazo

## Cambios Técnicos

### 1. Agregar Gems

```ruby
# Gemfile
gem 'grape', '~> 2.0'  # API framework con OpenAPI support
gem 'grape-swagger', '~> 2.0'  # Generate OpenAPI spec
gem 'rack-cors', '~> 2.0'  # CORS para Swagger UI
```

**Alternativa** (si queremos mantener Sinatra):
```ruby
gem 'sinatra-openapi', '~> 1.0'
# o manualmente crear spec OpenAPI
```

### 2. Estructura del Proyecto

```
/
├── openapi/
│   ├── spec.yml                # OpenAPI 3.0 specification
│   └── swagger-ui/             # Swagger UI assets
├── clients/                    # Auto-generated clients
│   ├── ruby/
│   ├── python/
│   ├── javascript/
│   └── go/
├── scripts/
│   └── generate-clients.sh     # Script para generar todos los SDKs
```

### 3. OpenAPI Specification

**Archivo**: `openapi/spec.yml`

```yaml
openapi: 3.0.3
info:
  title: ChainForge API
  description: Educational blockchain with Proof of Work
  version: 1.0.0
  contact:
    name: ChainForge Private Project
    url: https://github.com/Perafan18/chain_forge
  license:
    name: MIT

servers:
  - url: http://localhost:1910/api/v1
    description: Development server
  - url: https://api.chainforge.example.com/api/v1
    description: Production server

tags:
  - name: Chains
    description: Blockchain management
  - name: Blocks
    description: Block mining and retrieval
  - name: Validation
    description: Data validation
  - name: Health
    description: System health

paths:
  /chain:
    post:
      summary: Create a new blockchain
      tags: [Chains]
      operationId: createChain
      responses:
        '200':
          description: Chain created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ChainResponse'
        '429':
          $ref: '#/components/responses/RateLimited'

  /chain/{chainId}/block:
    post:
      summary: Mine a new block
      tags: [Blocks]
      operationId: mineBlock
      parameters:
        - $ref: '#/components/parameters/ChainId'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/BlockRequest'
      responses:
        '200':
          description: Block mined successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BlockResponse'
        '400':
          $ref: '#/components/responses/ValidationError'
        '429':
          $ref: '#/components/responses/RateLimited'

  /chain/{chainId}/block/{blockId}:
    get:
      summary: Get block details
      tags: [Blocks]
      operationId: getBlock
      parameters:
        - $ref: '#/components/parameters/ChainId'
        - $ref: '#/components/parameters/BlockId'
      responses:
        '200':
          description: Block details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BlockDetailResponse'
        '404':
          $ref: '#/components/responses/NotFound'

  /chain/{chainId}/block/{blockId}/valid:
    post:
      summary: Validate block data
      tags: [Validation]
      operationId: validateBlock
      parameters:
        - $ref: '#/components/parameters/ChainId'
        - $ref: '#/components/parameters/BlockId'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ValidationRequest'
      responses:
        '200':
          description: Validation result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ValidationResponse'

  /health:
    get:
      summary: Health check
      tags: [Health]
      operationId: healthCheck
      responses:
        '200':
          description: System is healthy
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthResponse'
        '503':
          description: System is unhealthy
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthResponse'

components:
  parameters:
    ChainId:
      name: chainId
      in: path
      required: true
      schema:
        type: string
        format: objectid
      description: MongoDB ObjectId of the blockchain

    BlockId:
      name: blockId
      in: path
      required: true
      schema:
        type: string
        format: objectid
      description: MongoDB ObjectId of the block

  schemas:
    ChainResponse:
      type: object
      required: [id]
      properties:
        id:
          type: string
          format: objectid
          example: "507f1f77bcf86cd799439011"

    BlockRequest:
      type: object
      required: [data]
      properties:
        data:
          type: string
          minLength: 1
          example: "Transaction data here"
        difficulty:
          type: integer
          minimum: 1
          maximum: 10
          example: 2

    BlockResponse:
      type: object
      required: [chain_id, block_id, block_hash, nonce, difficulty]
      properties:
        chain_id:
          type: string
          format: objectid
        block_id:
          type: string
          format: objectid
        block_hash:
          type: string
          example: "000a1b2c3d4e5f..."
        nonce:
          type: integer
          example: 1542
        difficulty:
          type: integer
          example: 2

    BlockDetailResponse:
      type: object
      required: [chain_id, block]
      properties:
        chain_id:
          type: string
          format: objectid
        block:
          type: object
          properties:
            id:
              type: string
            index:
              type: integer
            data:
              type: string
            hash:
              type: string
            previous_hash:
              type: string
            nonce:
              type: integer
            difficulty:
              type: integer
            timestamp:
              type: integer
            valid_hash:
              type: boolean

    ValidationRequest:
      type: object
      required: [data]
      properties:
        data:
          type: string

    ValidationResponse:
      type: object
      required: [chain_id, block_id, valid]
      properties:
        chain_id:
          type: string
        block_id:
          type: string
        valid:
          type: boolean

    HealthResponse:
      type: object
      required: [status, timestamp, checks]
      properties:
        status:
          type: string
          enum: [healthy, unhealthy]
        timestamp:
          type: string
          format: date-time
        checks:
          type: object
          properties:
            database:
              type: string
              enum: [ok, error]
            chain_integrity:
              type: string
              enum: [ok, error]
        uptime_seconds:
          type: integer
        errors:
          type: array
          items:
            type: string

    ErrorResponse:
      type: object
      required: [error]
      properties:
        error:
          type: string

    ValidationErrorResponse:
      type: object
      required: [errors]
      properties:
        errors:
          type: object
          additionalProperties:
            type: array
            items:
              type: string

  responses:
    RateLimited:
      description: Rate limit exceeded
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
          example:
            error: "Rate limit exceeded. Please try again later."

    ValidationError:
      description: Validation error
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ValidationErrorResponse'

    NotFound:
      description: Resource not found
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'

  securitySchemes:
    ApiKey:
      type: apiKey
      in: header
      name: X-API-Key
      description: Optional API key for authenticated requests
```

### 4. Swagger UI Endpoint

**En main.rb**:

```ruby
require 'sinatra/reloader' if development?

# Servir spec OpenAPI
get '/api/openapi.yml' do
  content_type 'text/yaml'
  File.read('openapi/spec.yml')
end

# Swagger UI
get '/docs' do
  content_type :html
  send_file 'openapi/swagger-ui/index.html'
end
```

**Instalar Swagger UI**:
```bash
mkdir -p openapi/swagger-ui
cd openapi/swagger-ui
wget https://github.com/swagger-api/swagger-ui/releases/download/v5.10.0/swagger-ui.zip
unzip swagger-ui.zip
# Configurar index.html para apuntar a /api/openapi.yml
```

### 5. Script de Generación de SDKs

**Archivo**: `scripts/generate-clients.sh`

```bash
#!/bin/bash

set -e

OPENAPI_SPEC="openapi/spec.yml"
OUTPUT_DIR="clients"

echo "🔧 Generating SDKs from OpenAPI spec..."

# Instalar openapi-generator si no existe
if ! command -v openapi-generator &> /dev/null; then
    echo "Installing openapi-generator..."
    npm install -g @openapitools/openapi-generator-cli
fi

# Ruby SDK
echo "📦 Generating Ruby SDK..."
openapi-generator generate \
  -i $OPENAPI_SPEC \
  -g ruby \
  -o $OUTPUT_DIR/ruby \
  --additional-properties=gemName=chainforge_client,gemVersion=1.0.0

# Python SDK
echo "🐍 Generating Python SDK..."
openapi-generator generate \
  -i $OPENAPI_SPEC \
  -g python \
  -o $OUTPUT_DIR/python \
  --additional-properties=packageName=chainforge_client,packageVersion=1.0.0

# JavaScript/TypeScript SDK
echo "📜 Generating JavaScript SDK..."
openapi-generator generate \
  -i $OPENAPI_SPEC \
  -g typescript-fetch \
  -o $OUTPUT_DIR/javascript \
  --additional-properties=npmName=chainforge-client,npmVersion=1.0.0

# Go SDK
echo "🐹 Generating Go SDK..."
openapi-generator generate \
  -i $OPENAPI_SPEC \
  -g go \
  -o $OUTPUT_DIR/go \
  --additional-properties=packageName=chainforge

echo "✅ All SDKs generated successfully!"
echo ""
echo "📍 SDKs location:"
echo "  - Ruby:       clients/ruby/"
echo "  - Python:     clients/python/"
echo "  - JavaScript: clients/javascript/"
echo "  - Go:         clients/go/"
echo ""
echo "📖 Documentation: http://localhost:1910/docs"
```

### 6. Uso de SDKs Generados

**Ruby**:
```ruby
require 'chainforge_client'

client = ChainforgeClient::DefaultApi.new
client.api_client.config.host = 'http://localhost:1910'

# Create chain
chain = client.create_chain
puts "Chain ID: #{chain.id}"

# Mine block
block_request = ChainforgeClient::BlockRequest.new(
  data: 'Hello World',
  difficulty: 2
)
block = client.mine_block(chain.id, block_request)
puts "Block mined with nonce: #{block.nonce}"
```

**Python**:
```python
import chainforge_client
from chainforge_client.api import default_api
from chainforge_client.model.block_request import BlockRequest

config = chainforge_client.Configuration(host="http://localhost:1910")
api = default_api.DefaultApi(chainforge_client.ApiClient(config))

# Create chain
chain = api.create_chain()
print(f"Chain ID: {chain.id}")

# Mine block
block_req = BlockRequest(data="Hello World", difficulty=2)
block = api.mine_block(chain.id, block_req)
print(f"Block mined with nonce: {block.nonce}")
```

**JavaScript/TypeScript**:
```typescript
import { DefaultApi, Configuration, BlockRequest } from 'chainforge-client';

const config = new Configuration({ basePath: 'http://localhost:1910' });
const api = new DefaultApi(config);

// Create chain
const chain = await api.createChain();
console.log(`Chain ID: ${chain.id}`);

// Mine block
const blockReq: BlockRequest = { data: 'Hello World', difficulty: 2 };
const block = await api.mineBlock(chain.id, blockReq);
console.log(`Block mined with nonce: ${block.nonce}`);
```

## Tests

### Validar OpenAPI Spec

```bash
# Con openapi-generator
openapi-generator validate -i openapi/spec.yml

# Con speccy
npm install -g speccy
speccy lint openapi/spec.yml
```

### Test de SDKs Generados

**spec/openapi/sdks_spec.rb**:
```ruby
RSpec.describe 'Generated SDKs' do
  it 'generates valid Ruby SDK' do
    expect(File).to exist('clients/ruby/lib/chainforge_client.rb')
  end

  it 'Ruby SDK can create chain' do
    # Integration test usando SDK generado
  end
end
```

## CI/CD Integration

**.github/workflows/openapi.yml**:
```yaml
name: OpenAPI & SDKs

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate OpenAPI spec
        run: |
          npm install -g @openapitools/openapi-generator-cli
          openapi-generator validate -i openapi/spec.yml

  generate-sdks:
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - uses: actions/checkout@v3
      - name: Generate SDKs
        run: ./scripts/generate-clients.sh
      - name: Upload SDKs as artifacts
        uses: actions/upload-artifact@v3
        with:
          name: sdks
          path: clients/
```

## Publicación de SDKs

### Ruby (RubyGems)
```bash
cd clients/ruby
gem build chainforge_client.gemspec
gem push chainforge_client-1.0.0.gem
```

### Python (PyPI)
```bash
cd clients/python
python setup.py sdist bdist_wheel
twine upload dist/*
```

### JavaScript (npm)
```bash
cd clients/javascript
npm publish
```

## Criterios de Aceptación

- [ ] OpenAPI 3.0 spec completo y válido
- [ ] Swagger UI accesible en `/docs`
- [ ] Script genera SDKs en Ruby, Python, JS, Go
- [ ] Ruby SDK funciona correctamente
- [ ] Python SDK funciona correctamente
- [ ] JS SDK funciona correctamente
- [ ] Tests de validación de spec
- [ ] CI valida spec en cada PR
- [ ] Documentación de uso de cada SDK
- [ ] README actualizado con links a docs

## Ventajas Adicionales

1. **Contract-First Development**: API spec como source of truth
2. **Mejor Colaboración**: Frontend puede usar spec antes de backend completo
3. **Testing**: Validación automática de requests/responses
4. **Documentación Always Updated**: Swagger UI siempre sincronizado
5. **Multi-Language Support**: Fácil agregar más lenguajes después

## Próximos Pasos

Después de esta tarea:
1. Los demás devs pueden consumir API con SDKs type-safe
2. Task 03 (CLI) puede usar Ruby SDK generado
3. Task 13 (Block Explorer) puede usar JS SDK
4. Documentación interactiva disponible

## Referencias

- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [OpenAPI Generator](https://openapi-generator.tech/)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)
- [grape-swagger](https://github.com/ruby-grape/grape-swagger)
