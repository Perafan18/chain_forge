# Task 03: CLI Tool (chainforge command)

**PR**: #11
**Fase**: 2 - Developer Experience
**Complejidad**: Medium
**Estimación**: 5-7 días
**Prioridad**: P0
**Dependencias**: None

## Objetivo

Crear CLI tool `chainforge` para interactuar con blockchain sin usar curl.

## Comandos

```bash
# Gestión de chains
chainforge create                    # Crear nueva chain
chainforge list                      # Listar chains
chainforge show CHAIN_ID            # Ver detalles de chain

# Gestión de blocks
chainforge mine CHAIN_ID "data"     # Minar nuevo block
chainforge mine CHAIN_ID "data" -d 3 # Con difficulty custom
chainforge get CHAIN_ID BLOCK_ID    # Ver block
chainforge list-blocks CHAIN_ID     # Listar blocks de chain

# Validación
chainforge validate CHAIN_ID BLOCK_ID "data"  # Validar data

# Utilidades
chainforge benchmark DIFFICULTY     # Benchmark mining
chainforge config                   # Ver configuración actual
chainforge version                  # Ver versión
```

## Implementación

### Estructura
```
bin/
  chainforge          # Executable
lib/
  chainforge/
    cli.rb            # Thor CLI class
    client.rb         # API client wrapper
    formatters.rb     # Output formatting
    config.rb         # Configuration management
```

### Gem: Thor
```ruby
# chainforge.gemspec
spec.add_dependency 'thor', '~> 1.3'
spec.add_dependency 'tty-prompt', '~> 0.23'
spec.add_dependency 'tty-table', '~> 0.12'
spec.add_dependency 'pastel', '~> 0.8'
```

### bin/chainforge
```ruby
#!/usr/bin/env ruby

require_relative '../lib/chainforge/cli'
ChainForge::CLI.start(ARGV)
```

### lib/chainforge/cli.rb
```ruby
require 'thor'
require 'tty-prompt'

module ChainForge
  class CLI < Thor
    desc 'create', 'Create a new blockchain'
    def create
      response = client.create_chain
      puts paint.green("✓ Chain created: #{response['id']}")
    end

    desc 'mine CHAIN_ID DATA', 'Mine a new block'
    option :difficulty, aliases: '-d', type: :numeric
    def mine(chain_id, data)
      puts paint.yellow("Mining block with difficulty #{options[:difficulty] || 'default'}...")
      
      response = client.mine_block(
        chain_id,
        data,
        difficulty: options[:difficulty]
      )
      
      puts paint.green("✓ Block mined!")
      print_block(response)
    end

    desc 'benchmark DIFFICULTY', 'Benchmark mining performance'
    def benchmark(difficulty)
      puts "Benchmarking difficulty #{difficulty}..."
      # Implementation
    end

    private

    def client
      @client ||= ChainForge::Client.new(
        base_url: config.api_url
      )
    end

    def config
      @config ||= ChainForge::Config.load
    end

    def paint
      @paint ||= Pastel.new
    end

    def print_block(block)
      table = TTY::Table.new(
        ['Field', 'Value'],
        [
          ['Chain ID', block['chain_id']],
          ['Block ID', block['block_id']],
          ['Hash', block['block_hash'][0..15] + '...'],
          ['Nonce', block['nonce']],
          ['Difficulty', block['difficulty']]
        ]
      )
      puts table.render(:unicode)
    end
  end
end
```

### Configuración (~/.chainforge/config.yml)
```yaml
api_url: http://localhost:1910
default_difficulty: 2
output_format: table  # table, json, plain
color: true
```

## Tests

```ruby
RSpec.describe ChainForge::CLI do
  describe '#create' do
    it 'creates a new chain' do
      # Test implementation
    end
  end

  describe '#mine' do
    it 'mines a block with default difficulty' do
      # Test implementation
    end

    it 'mines a block with custom difficulty' do
      # Test implementation
    end
  end
end
```

## Criterios de Aceptación

- [ ] Comando `chainforge create` funciona
- [ ] Comando `chainforge mine` funciona
- [ ] Comando `chainforge benchmark` funciona
- [ ] Output colorizado y formateado
- [ ] Manejo de errores con mensajes claros
- [ ] Configuración en ~/.chainforge/config.yml
- [ ] Help text para todos los comandos
- [ ] Tests completos
- [ ] README actualizado con ejemplos de CLI
