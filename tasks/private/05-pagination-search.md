# Task 05: Pagination & Search APIs

**PR**: #13
**Fase**: 2 - Developer Experience
**Complejidad**: Small
**Estimación**: 3-4 días
**Prioridad**: P0
**Dependencias**: None

## Objetivo

Agregar paginación y búsqueda a los endpoints existentes para mejorar usabilidad con datasets grandes.

## Nuevos Endpoints

### GET /api/v1/chains
Lista todas las chains con paginación.

**Query Parameters**:
- `page` (default: 1)
- `limit` (default: 20, max: 100)
- `sort` (default: "created_at", options: "created_at", "updated_at")
- `order` (default: "desc", options: "asc", "desc")

**Response**:
```json
{
  "data": [
    {
      "id": "507f1f77bcf86cd799439011",
      "created_at": "2025-11-09T10:30:00Z",
      "blocks_count": 15
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "pages": 8,
    "has_next": true,
    "has_prev": false
  }
}
```

### GET /api/v1/chain/:id/blocks
Lista blocks de una chain con paginación.

**Query Parameters**:
- `page`, `limit`, `sort`, `order` (igual que chains)
- `min_difficulty` (filtrar por difficulty mínimo)
- `max_difficulty` (filtrar por difficulty máximo)

**Response**:
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "data": [
    {
      "id": "507f1f77bcf86cd799439012",
      "index": 5,
      "hash": "000a1b2c3d...",
      "nonce": 1542,
      "difficulty": 2,
      "timestamp": 1699524000
    }
  ],
  "pagination": { ... }
}
```

### GET /api/v1/chain/:id/blocks/search
Busca blocks por contenido de data.

**Query Parameters**:
- `q` (query string, required)
- `page`, `limit` (paginación)

**Response**:
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "query": "transaction",
  "data": [ ... ],
  "pagination": { ... }
}
```

## Cambios Técnicos

### Helper de Paginación

**Archivo**: `lib/pagination_helper.rb`

```ruby
module PaginationHelper
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 100

  def paginate(collection, params)
    page = [params[:page].to_i, 1].max
    limit = [[params[:limit].to_i, DEFAULT_LIMIT].max, MAX_LIMIT].min

    total = collection.count
    pages = (total.to_f / limit).ceil

    paginated = collection
      .skip((page - 1) * limit)
      .limit(limit)

    {
      data: paginated.to_a,
      pagination: {
        page: page,
        limit: limit,
        total: total,
        pages: pages,
        has_next: page < pages,
        has_prev: page > 1
      }
    }
  end

  def apply_sorting(collection, sort_field, order)
    valid_fields = %w[created_at updated_at index timestamp]
    field = valid_fields.include?(sort_field) ? sort_field : 'created_at'
    direction = order == 'asc' ? 1 : -1

    collection.order_by([[field, direction]])
  end
end
```

### MongoDB Indexes

Agregar a `src/models/blockchain.rb` y `src/models/block.rb`:

```ruby
# blockchain.rb
class Blockchain
  include Mongoid::Document
  include Mongoid::Timestamps

  # Existing fields...

  index({ created_at: -1 })
  index({ updated_at: -1 })
end

# block.rb
class Block
  include Mongoid::Document
  include Mongoid::Timestamps

  # Existing fields...

  index({ blockchain_id: 1, created_at: -1 })
  index({ blockchain_id: 1, index: 1 })
  index({ blockchain_id: 1, difficulty: 1 })
  index({ data: 'text' })  # Para full-text search
end
```

### Actualizar main.rb

```ruby
require_relative 'lib/pagination_helper'

class ChainForgeAPI < Sinatra::Base
  helpers PaginationHelper

  # Nuevo endpoint: List chains
  get '/api/v1/chains' do
    content_type :json

    collection = Blockchain.all
    collection = apply_sorting(collection, params[:sort], params[:order])

    result = paginate(collection, params)
    result.to_json
  end

  # Nuevo endpoint: List blocks
  get '/api/v1/chain/:id/blocks' do
    content_type :json

    chain = Blockchain.find(params[:id])
    collection = chain.blocks

    # Filtros opcionales
    if params[:min_difficulty]
      collection = collection.where(:difficulty.gte => params[:min_difficulty].to_i)
    end
    if params[:max_difficulty]
      collection = collection.where(:difficulty.lte => params[:max_difficulty].to_i)
    end

    collection = apply_sorting(collection, params[:sort], params[:order])
    result = paginate(collection, params)
    result[:chain_id] = chain.id.to_s

    result.to_json
  end

  # Nuevo endpoint: Search blocks
  get '/api/v1/chain/:id/blocks/search' do
    content_type :json

    halt 400, { error: 'Query parameter "q" is required' }.to_json unless params[:q]

    chain = Blockchain.find(params[:id])

    # Full-text search en MongoDB
    collection = chain.blocks.where(
      :data => /#{Regexp.escape(params[:q])}/i
    )

    result = paginate(collection, params)
    result[:chain_id] = chain.id.to_s
    result[:query] = params[:q]

    result.to_json
  end
end
```

## Tests

**Archivo**: `spec/api/pagination_spec.rb`

```ruby
RSpec.describe 'Pagination API' do
  let!(:chain) { Blockchain.create }
  let!(:blocks) do
    25.times.map do |i|
      Block.create(
        blockchain: chain,
        index: i,
        data: "Block #{i}",
        hash: "hash#{i}",
        previous_hash: i > 0 ? "hash#{i-1}" : "0",
        nonce: i * 100,
        difficulty: (i % 3) + 1,
        timestamp: Time.now.to_i + i
      )
    end
  end

  describe 'GET /api/v1/chains' do
    it 'returns paginated chains' do
      get '/api/v1/chains?page=1&limit=10'

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['pagination']['page']).to eq(1)
      expect(data['pagination']['limit']).to eq(10)
      expect(data['pagination']['total']).to be > 0
    end

    it 'respects max limit' do
      get '/api/v1/chains?limit=999'

      data = JSON.parse(last_response.body)
      expect(data['pagination']['limit']).to eq(100)
    end
  end

  describe 'GET /api/v1/chain/:id/blocks' do
    it 'returns paginated blocks' do
      get "/api/v1/chain/#{chain.id}/blocks?page=1&limit=10"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['data'].length).to eq(10)
      expect(data['pagination']['total']).to eq(25)
      expect(data['pagination']['pages']).to eq(3)
    end

    it 'filters by difficulty' do
      get "/api/v1/chain/#{chain.id}/blocks?min_difficulty=2"

      data = JSON.parse(last_response.body)
      data['data'].each do |block|
        expect(block['difficulty']).to be >= 2
      end
    end

    it 'sorts by index ascending' do
      get "/api/v1/chain/#{chain.id}/blocks?sort=index&order=asc&limit=5"

      data = JSON.parse(last_response.body)
      indexes = data['data'].map { |b| b['index'] }
      expect(indexes).to eq(indexes.sort)
    end
  end

  describe 'GET /api/v1/chain/:id/blocks/search' do
    it 'searches blocks by content' do
      get "/api/v1/chain/#{chain.id}/blocks/search?q=Block%2010"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data['query']).to eq('Block 10')
      expect(data['data'].length).to be > 0
      expect(data['data'].first['data']).to include('Block 10')
    end

    it 'returns 400 without query parameter' do
      get "/api/v1/chain/#{chain.id}/blocks/search"

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['error']).to include('required')
    end

    it 'paginates search results' do
      # Create many matching blocks
      30.times { |i| chain.blocks.create(data: "test #{i}", hash: "h#{i}") }

      get "/api/v1/chain/#{chain.id}/blocks/search?q=test&limit=10"

      data = JSON.parse(last_response.body)
      expect(data['data'].length).to eq(10)
      expect(data['pagination']['has_next']).to be true
    end
  end
end
```

## Migración de Indexes

Crear script para agregar indexes:

**Archivo**: `scripts/add_pagination_indexes.rb`

```ruby
#!/usr/bin/env ruby

require_relative '../config/mongoid'

puts "Adding pagination indexes..."

Blockchain.create_indexes
Block.create_indexes

puts "✓ Indexes created successfully"

# Verificar indexes
puts "\nBlockchain indexes:"
Blockchain.collection.indexes.each do |index|
  puts "  - #{index['name']}"
end

puts "\nBlock indexes:"
Block.collection.indexes.each do |index|
  puts "  - #{index['name']}"
end
```

## Actualizar OpenAPI Spec

Agregar a `openapi/spec.yml`:

```yaml
paths:
  /chains:
    get:
      summary: List all blockchains
      tags: [Chains]
      operationId: listChains
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
        - name: sort
          in: query
          schema:
            type: string
            enum: [created_at, updated_at]
        - name: order
          in: query
          schema:
            type: string
            enum: [asc, desc]
      responses:
        '200':
          description: Paginated chains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PaginatedChainsResponse'

components:
  schemas:
    PaginatedChainsResponse:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/ChainSummary'
        pagination:
          $ref: '#/components/schemas/Pagination'

    Pagination:
      type: object
      properties:
        page:
          type: integer
        limit:
          type: integer
        total:
          type: integer
        pages:
          type: integer
        has_next:
          type: boolean
        has_prev:
          type: boolean
```

## Performance Considerations

1. **Indexes**: Critical para performance con datasets grandes
2. **Limit máximo**: 100 para prevenir queries pesados
3. **Count caching**: Considerar cachear totals en Redis (Task 10)
4. **Cursor-based pagination**: Para futuras versiones considerar cursor en lugar de offset

## Criterios de Aceptación

- [ ] GET /api/v1/chains funciona con paginación
- [ ] GET /api/v1/chain/:id/blocks funciona con paginación
- [ ] GET /api/v1/chain/:id/blocks/search funciona
- [ ] Filtros por difficulty funcionan
- [ ] Sorting por diferentes campos funciona
- [ ] Indexes de MongoDB creados
- [ ] Tests completos (>90% coverage)
- [ ] OpenAPI spec actualizado
- [ ] Performance aceptable (<200ms) con 1000+ records
- [ ] Documentación en API_DOCUMENTATION.md

## Referencias

- [Mongoid Pagination](https://www.mongodb.com/docs/mongoid/current/reference/queries/)
- [MongoDB Text Search](https://www.mongodb.com/docs/manual/text-search/)
- [Pagination Best Practices](https://docs.github.com/en/rest/guides/using-pagination-in-the-rest-api)
