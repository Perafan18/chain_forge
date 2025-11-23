# Task 06: Dynamic Difficulty Adjustment

**PR**: #14
**Fase**: 3 - Blockchain Avanzado
**Complejidad**: Medium
**Estimación**: 5-6 días
**Prioridad**: P0
**Dependencias**: None (pero beneficia de Task 01 para logging)

## Objetivo

Implementar ajuste dinámico de difficulty basado en el tiempo promedio de mining, similar al algoritmo de Bitcoin, para mantener un target block time constante.

## Motivación

**Problema actual**: La difficulty es estática. Si el hardware mejora o hay más miners, los blocks se minan más rápido. Si hay menos poder de cómputo, más lento.

**Solución**: Ajustar automáticamente la difficulty cada N blocks para mantener un tiempo de bloque predecible (~10 segundos).

**Inspiración**: Bitcoin ajusta difficulty cada 2016 blocks (~2 semanas) para mantener 10 minutos por block.

## Algoritmo de Ajuste

### Concepto

Cada `ADJUSTMENT_INTERVAL` blocks (default: 10), calculamos:

```
tiempo_promedio = tiempo_total / número_de_blocks
ratio = tiempo_promedio / target_time

Si ratio > 1.0: blocks están tomando MÁS tiempo → REDUCIR difficulty
Si ratio < 1.0: blocks están tomando MENOS tiempo → AUMENTAR difficulty
```

### Implementación Matemática

```ruby
# Simplified approach (initial implementation)
if avg_time > target_time * 1.1  # 10% slower
  new_difficulty = current_difficulty - 1  # Make easier
elsif avg_time < target_time * 0.9  # 10% faster
  new_difficulty = current_difficulty + 1  # Make harder
else
  new_difficulty = current_difficulty  # Keep same
end

# Clamp to min/max
new_difficulty = [[new_difficulty, MIN_DIFFICULTY].max, MAX_DIFFICULTY].min
```

### Approach Avanzado (opcional para futuras versiones)

```ruby
# Proportional adjustment (more realistic)
ratio = avg_time / target_time
new_difficulty = (current_difficulty * ratio).round

# Limit change rate (prevent wild swings)
max_change = current_difficulty * 0.25  # Max 25% change
change = new_difficulty - current_difficulty
change = [[change, -max_change].max, max_change].min

new_difficulty = current_difficulty + change
```

## Cambios Técnicos

### 1. Configuración (config/difficulty.rb)

```ruby
module ChainForge
  module DifficultyConfig
    TARGET_BLOCK_TIME = ENV.fetch('TARGET_BLOCK_TIME', '10').to_i  # seconds
    ADJUSTMENT_INTERVAL = ENV.fetch('ADJUSTMENT_INTERVAL', '10').to_i  # blocks
    MIN_DIFFICULTY = ENV.fetch('MIN_DIFFICULTY', '1').to_i
    MAX_DIFFICULTY = ENV.fetch('MAX_DIFFICULTY', '10').to_i

    # Threshold for adjustment (10% tolerance)
    ADJUSTMENT_THRESHOLD = ENV.fetch('ADJUSTMENT_THRESHOLD', '0.1').to_f

    def self.should_adjust?(block_index)
      block_index > 0 && (block_index % ADJUSTMENT_INTERVAL).zero?
    end

    def self.clamp_difficulty(difficulty)
      [[difficulty, MIN_DIFFICULTY].max, MAX_DIFFICULTY].min
    end
  end
end
```

### 2. Actualizar Block Model

**Archivo**: `src/models/block.rb`

```ruby
class Block
  include Mongoid::Document
  include Mongoid::Timestamps

  field :index, type: Integer
  field :data, type: String
  field :hash, type: String
  field :previous_hash, type: String
  field :nonce, type: Integer, default: 0
  field :difficulty, type: Integer, default: 2
  field :timestamp, type: Integer  # Ya existe desde v2
  field :mining_duration, type: Float  # NEW: Tiempo que tomó minar (seconds)

  embedded_in :blockchain

  validates :index, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :data, presence: true
  validates :difficulty, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10 }

  # NEW: Track when mining started
  attr_accessor :mining_started_at

  def mine_block
    @mining_started_at = Time.now

    self.nonce = 0
    self.timestamp = Time.now.to_i
    target = '0' * difficulty

    until hash.start_with?(target)
      self.nonce += 1
      self.hash = calculate_hash
    end

    # Record mining duration
    self.mining_duration = Time.now - @mining_started_at

    LOGGER.info "Block mined",
      index: index,
      nonce: nonce,
      difficulty: difficulty,
      mining_duration: mining_duration,
      hash: hash[0..15]
  end

  def calculate_hash
    content = "#{index}#{data}#{previous_hash}#{nonce}#{difficulty}#{timestamp}"
    Digest::SHA256.hexdigest(content)
  end

  def valid_hash?
    hash.start_with?('0' * difficulty) && hash == calculate_hash
  end
end
```

### 3. Actualizar Blockchain Model

**Archivo**: `src/models/blockchain.rb`

```ruby
require_relative '../../config/difficulty'

class Blockchain
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :blocks

  field :current_difficulty, type: Integer, default: 2  # NEW
  field :last_adjustment_at, type: Integer  # NEW: block index

  validates :blocks, presence: true

  def initialize(attributes = {})
    super
    self.current_difficulty ||= ChainForge::DifficultyConfig::MIN_DIFFICULTY
    self.last_adjustment_at ||= 0
    create_genesis_block if blocks.empty?
  end

  def add_block(data, custom_difficulty: nil)
    previous_block = blocks.last
    new_index = previous_block.index + 1

    # Calculate difficulty for this block
    difficulty = custom_difficulty || calculate_next_difficulty(new_index)

    new_block = blocks.build(
      index: new_index,
      data: data,
      previous_hash: previous_block.hash,
      difficulty: difficulty
    )

    new_block.mine_block
    save!

    # Update current difficulty if adjustment happened
    self.current_difficulty = difficulty if ChainForge::DifficultyConfig.should_adjust?(new_index)

    LOGGER.info "Block added to chain",
      chain_id: id.to_s,
      block_index: new_index,
      difficulty: difficulty,
      current_difficulty: current_difficulty

    new_block
  end

  def calculate_next_difficulty(next_index)
    # Don't adjust if not at adjustment interval
    unless ChainForge::DifficultyConfig.should_adjust?(next_index)
      return current_difficulty
    end

    # Need at least ADJUSTMENT_INTERVAL blocks to calculate
    return current_difficulty if blocks.length < ChainForge::DifficultyConfig::ADJUSTMENT_INTERVAL

    # Get last N blocks
    recent_blocks = blocks
      .order_by(index: :desc)
      .limit(ChainForge::DifficultyConfig::ADJUSTMENT_INTERVAL)
      .to_a

    # Calculate average mining time
    avg_time = recent_blocks.sum(&:mining_duration) / recent_blocks.length.to_f
    target_time = ChainForge::DifficultyConfig::TARGET_BLOCK_TIME

    LOGGER.info "Difficulty adjustment calculation",
      block_index: next_index,
      avg_time: avg_time.round(2),
      target_time: target_time,
      current_difficulty: current_difficulty

    # Calculate adjustment
    new_difficulty = adjust_difficulty(current_difficulty, avg_time, target_time)

    if new_difficulty != current_difficulty
      LOGGER.info "Difficulty adjusted",
        old_difficulty: current_difficulty,
        new_difficulty: new_difficulty,
        reason: avg_time > target_time ? "too_slow" : "too_fast"
    end

    self.last_adjustment_at = next_index
    new_difficulty
  end

  private

  def adjust_difficulty(current, avg_time, target_time)
    threshold = ChainForge::DifficultyConfig::ADJUSTMENT_THRESHOLD

    if avg_time > target_time * (1 + threshold)  # >10% slower
      new_diff = current - 1
    elsif avg_time < target_time * (1 - threshold)  # >10% faster
      new_diff = current + 1
    else
      new_diff = current  # Within tolerance
    end

    ChainForge::DifficultyConfig.clamp_difficulty(new_diff)
  end

  def create_genesis_block
    genesis = blocks.build(
      index: 0,
      data: 'Genesis Block',
      previous_hash: '0',
      difficulty: current_difficulty
    )
    genesis.mine_block
  end

  def valid_chain?
    blocks.each_cons(2) do |prev_block, current_block|
      # Validate hash
      return false unless current_block.valid_hash?

      # Validate chain link
      return false unless current_block.previous_hash == prev_block.hash

      # Validate index sequence
      return false unless current_block.index == prev_block.index + 1
    end
    true
  end
end
```

### 4. Actualizar API Endpoint

**Archivo**: `main.rb`

```ruby
# GET difficulty info
get '/api/v1/chain/:id/difficulty' do
  content_type :json

  chain = Blockchain.find(params[:id])

  # Get recent blocks stats
  recent_blocks = chain.blocks
    .order_by(index: :desc)
    .limit(ChainForge::DifficultyConfig::ADJUSTMENT_INTERVAL)
    .to_a

  avg_mining_time = recent_blocks.any? ?
    (recent_blocks.sum(&:mining_duration) / recent_blocks.length) : 0

  {
    current_difficulty: chain.current_difficulty,
    last_adjustment_at: chain.last_adjustment_at,
    blocks_until_next_adjustment: ChainForge::DifficultyConfig::ADJUSTMENT_INTERVAL -
      (chain.blocks.length % ChainForge::DifficultyConfig::ADJUSTMENT_INTERVAL),
    config: {
      target_block_time: ChainForge::DifficultyConfig::TARGET_BLOCK_TIME,
      adjustment_interval: ChainForge::DifficultyConfig::ADJUSTMENT_INTERVAL,
      min_difficulty: ChainForge::DifficultyConfig::MIN_DIFFICULTY,
      max_difficulty: ChainForge::DifficultyConfig::MAX_DIFFICULTY
    },
    stats: {
      recent_avg_time: avg_mining_time.round(2),
      recent_blocks_count: recent_blocks.length
    }
  }.to_json
end

# Update mine endpoint to return difficulty info
post '/api/v1/chain/:id/block' do
  content_type :json

  # ... existing validation ...

  chain = Blockchain.find(params[:id])
  new_block = chain.add_block(
    params[:data],
    custom_difficulty: params[:difficulty]&.to_i
  )

  {
    chain_id: chain.id.to_s,
    block_id: new_block.id.to_s,
    block_hash: new_block.hash,
    nonce: new_block.nonce,
    difficulty: new_block.difficulty,
    mining_duration: new_block.mining_duration.round(2),
    current_chain_difficulty: chain.current_difficulty  # NEW
  }.to_json
end
```

## Tests

**Archivo**: `spec/models/difficulty_spec.rb`

```ruby
require 'spec_helper'

RSpec.describe 'Dynamic Difficulty Adjustment' do
  let(:chain) { Blockchain.create }

  before do
    # Override config for predictable testing
    stub_const('ChainForge::DifficultyConfig::TARGET_BLOCK_TIME', 10)
    stub_const('ChainForge::DifficultyConfig::ADJUSTMENT_INTERVAL', 5)
    stub_const('ChainForge::DifficultyConfig::MIN_DIFFICULTY', 1)
    stub_const('ChainForge::DifficultyConfig::MAX_DIFFICULTY', 10)
  end

  describe 'Blockchain#calculate_next_difficulty' do
    context 'before adjustment interval' do
      it 'maintains current difficulty' do
        chain.current_difficulty = 3
        expect(chain.calculate_next_difficulty(3)).to eq(3)
      end
    end

    context 'at adjustment interval with slow mining' do
      it 'reduces difficulty' do
        chain.current_difficulty = 5

        # Create blocks with slow mining times (20s each = 2x target)
        5.times do |i|
          block = chain.blocks.build(
            index: i + 1,
            data: "Block #{i}",
            previous_hash: chain.blocks.last.hash,
            difficulty: 5,
            mining_duration: 20.0  # Much slower than 10s target
          )
          block.hash = block.calculate_hash
          block.save
        end

        # At block 5 (adjustment interval), should reduce difficulty
        expect(chain.calculate_next_difficulty(5)).to eq(4)
      end
    end

    context 'at adjustment interval with fast mining' do
      it 'increases difficulty' do
        chain.current_difficulty = 2

        # Create blocks with fast mining times (5s each = 0.5x target)
        5.times do |i|
          block = chain.blocks.build(
            index: i + 1,
            data: "Block #{i}",
            previous_hash: chain.blocks.last.hash,
            difficulty: 2,
            mining_duration: 5.0  # Much faster than 10s target
          )
          block.hash = block.calculate_hash
          block.save
        end

        expect(chain.calculate_next_difficulty(5)).to eq(3)
      end
    end

    context 'respects min/max bounds' do
      it 'does not go below MIN_DIFFICULTY' do
        chain.current_difficulty = 1

        5.times do |i|
          block = chain.blocks.build(
            index: i + 1,
            data: "Block #{i}",
            previous_hash: chain.blocks.last.hash,
            difficulty: 1,
            mining_duration: 50.0  # Very slow
          )
          block.hash = block.calculate_hash
          block.save
        end

        expect(chain.calculate_next_difficulty(5)).to eq(1)
      end

      it 'does not go above MAX_DIFFICULTY' do
        chain.current_difficulty = 10

        5.times do |i|
          block = chain.blocks.build(
            index: i + 1,
            data: "Block #{i}",
            previous_hash: chain.blocks.last.hash,
            difficulty: 10,
            mining_duration: 1.0  # Very fast
          )
          block.hash = block.calculate_hash
          block.save
        end

        expect(chain.calculate_next_difficulty(5)).to eq(10)
      end
    end

    context 'within tolerance threshold' do
      it 'maintains difficulty when mining time is close to target' do
        chain.current_difficulty = 5

        # Create blocks with mining time within 10% of target (9-11s)
        5.times do |i|
          block = chain.blocks.build(
            index: i + 1,
            data: "Block #{i}",
            previous_hash: chain.blocks.last.hash,
            difficulty: 5,
            mining_duration: 10.5  # Within threshold
          )
          block.hash = block.calculate_hash
          block.save
        end

        expect(chain.calculate_next_difficulty(5)).to eq(5)
      end
    end
  end

  describe 'Block mining duration tracking' do
    it 'records mining_duration after mining' do
      block = chain.add_block('Test data', custom_difficulty: 1)

      expect(block.mining_duration).to be > 0
      expect(block.mining_duration).to be_a(Float)
    end
  end

  describe 'Integration: Multiple adjustment cycles' do
    it 'adjusts difficulty across multiple intervals' do
      initial_difficulty = 2
      chain.current_difficulty = initial_difficulty

      difficulties = []

      # Mine 20 blocks (4 adjustment intervals)
      20.times do |i|
        # Simulate varying mining times
        mining_time = (i < 10) ? 5.0 : 15.0  # Fast, then slow

        block = chain.blocks.build(
          index: i + 1,
          data: "Block #{i}",
          previous_hash: chain.blocks.last.hash,
          difficulty: chain.current_difficulty
        )
        block.mining_duration = mining_time
        block.hash = block.calculate_hash
        block.save

        # Recalculate difficulty if at interval
        if (i + 1) % 5 == 0
          chain.current_difficulty = chain.calculate_next_difficulty(i + 1)
          difficulties << chain.current_difficulty
        end
      end

      # Difficulty should have increased first (fast blocks), then decreased (slow blocks)
      expect(difficulties.first).to be > initial_difficulty
      expect(difficulties.last).to be < difficulties.first
    end
  end
end
```

**Archivo**: `spec/api/difficulty_spec.rb`

```ruby
RSpec.describe 'Difficulty API' do
  let!(:chain) { Blockchain.create }

  describe 'GET /api/v1/chain/:id/difficulty' do
    it 'returns current difficulty info' do
      get "/api/v1/chain/#{chain.id}/difficulty"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data).to include('current_difficulty', 'config', 'stats')
      expect(data['config']).to include('target_block_time', 'adjustment_interval')
    end

    it 'shows blocks until next adjustment' do
      chain.add_block('Block 1')
      chain.add_block('Block 2')

      get "/api/v1/chain/#{chain.id}/difficulty"
      data = JSON.parse(last_response.body)

      expect(data['blocks_until_next_adjustment']).to eq(7)  # 10 - 3 blocks
    end
  end

  describe 'POST /api/v1/chain/:id/block with dynamic difficulty' do
    it 'returns mining duration and current chain difficulty' do
      post "/api/v1/chain/#{chain.id}/block", { data: 'Test block' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data).to include('mining_duration', 'current_chain_difficulty')
      expect(data['mining_duration']).to be > 0
    end
  end
end
```

## Migración

**Archivo**: `scripts/migrate_add_difficulty_fields.rb`

```ruby
#!/usr/bin/env ruby

require_relative '../config/mongoid'

puts "Migrating chains and blocks for dynamic difficulty..."

Blockchain.all.each do |chain|
  # Set initial difficulty
  chain.current_difficulty ||= 2
  chain.last_adjustment_at ||= 0

  # For existing blocks without mining_duration, estimate
  chain.blocks.each do |block|
    unless block.mining_duration
      # Rough estimate based on difficulty and nonce
      estimated_duration = (block.nonce.to_f / 1000) * block.difficulty
      block.mining_duration = estimated_duration
    end
  end

  chain.save
end

puts "✓ Migration complete"
puts "  - Updated #{Blockchain.count} chains"
puts "  - Updated #{Block.count} blocks"
```

## Actualizar OpenAPI Spec

```yaml
paths:
  /chain/{chainId}/difficulty:
    get:
      summary: Get difficulty information
      tags: [Blocks]
      operationId: getDifficulty
      parameters:
        - $ref: '#/components/parameters/ChainId'
      responses:
        '200':
          description: Difficulty information
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/DifficultyResponse'

components:
  schemas:
    BlockResponse:
      # Add new fields to existing schema
      properties:
        mining_duration:
          type: number
          format: float
        current_chain_difficulty:
          type: integer

    DifficultyResponse:
      type: object
      properties:
        current_difficulty:
          type: integer
        last_adjustment_at:
          type: integer
        blocks_until_next_adjustment:
          type: integer
        config:
          type: object
          properties:
            target_block_time:
              type: integer
            adjustment_interval:
              type: integer
            min_difficulty:
              type: integer
            max_difficulty:
              type: integer
        stats:
          type: object
          properties:
            recent_avg_time:
              type: number
            recent_blocks_count:
              type: integer
```

## .env Configuration

```bash
# Dynamic Difficulty Settings
TARGET_BLOCK_TIME=10         # Target time per block (seconds)
ADJUSTMENT_INTERVAL=10       # Blocks between difficulty adjustments
MIN_DIFFICULTY=1             # Minimum difficulty level
MAX_DIFFICULTY=10            # Maximum difficulty level
ADJUSTMENT_THRESHOLD=0.1     # 10% tolerance before adjusting
```

## Monitoring y Observability

Agregar métricas Prometheus (requiere Task 02):

```ruby
# config/metrics.rb
DIFFICULTY_GAUGE = Prometheus::Client::Gauge.new(
  :chainforge_current_difficulty,
  docstring: 'Current mining difficulty',
  labels: [:chain_id]
)

MINING_DURATION_HISTOGRAM = Prometheus::Client::Histogram.new(
  :chainforge_mining_duration_seconds,
  docstring: 'Block mining duration',
  labels: [:chain_id, :difficulty],
  buckets: [1, 5, 10, 20, 30, 60]
)

# En Blockchain#add_block
DIFFICULTY_GAUGE.set(current_difficulty, labels: { chain_id: id.to_s })
MINING_DURATION_HISTOGRAM.observe(
  new_block.mining_duration,
  labels: { chain_id: id.to_s, difficulty: new_block.difficulty }
)
```

## Comparación con Bitcoin

| Aspecto | Bitcoin | ChainForge Private |
|---------|---------|---------------------|
| Target time | 10 minutos | 10 segundos (configurable) |
| Adjustment interval | 2016 blocks (~2 semanas) | 10 blocks (configurable) |
| Algorithm | Ratio-based proportional | Simplified step adjustment |
| Min/Max limits | None (difficulty can grow infinitely) | 1-10 (configurable) |
| Adjustment tolerance | None (always adjusts) | 10% threshold |

## Criterios de Aceptación

- [ ] `Blockchain#calculate_next_difficulty` implementado y testeado
- [ ] `Block#mining_duration` se registra correctamente
- [ ] Difficulty se ajusta automáticamente cada N blocks
- [ ] Respeta MIN_DIFFICULTY y MAX_DIFFICULTY
- [ ] GET /api/v1/chain/:id/difficulty endpoint funciona
- [ ] POST /api/v1/chain/:id/block retorna mining_duration
- [ ] Tests completos con >90% coverage
- [ ] Migración para chains existentes funciona
- [ ] OpenAPI spec actualizado
- [ ] Logging de adjustments
- [ ] Métricas Prometheus (si Task 02 completado)
- [ ] Configuración via ENV vars
- [ ] Documentación actualizada

## Educational Value

Este feature enseña:
1. **Proof of Work adaptativo** - Cómo Bitcoin mantiene bloques cada 10 minutos
2. **Homeostasis en sistemas distribuidos** - Auto-regulación
3. **Trade-offs** - Threshold, interval, change rate
4. **Time-series analysis** - Calcular promedios móviles
5. **Sistemas de feedback** - Adjust based on past performance

## Referencias

- [Bitcoin Difficulty Adjustment](https://en.bitcoin.it/wiki/Difficulty)
- [Bitcoin Retargeting Algorithm](https://en.bitcoin.it/wiki/Target)
- [Ethereum Difficulty Bomb](https://ethereum.org/en/glossary/#difficulty-bomb)
- [Blockchain Difficulty Explained](https://www.investopedia.com/terms/d/difficulty-cryptocurrencies.asp)
