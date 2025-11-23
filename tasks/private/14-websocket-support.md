# Task 14: WebSocket Support

**PR**: #22
**Fase**: 5 - User Interface
**Complejidad**: Medium
**Estimación**: 5-6 días
**Prioridad**: P3 (OPCIONAL)
**Dependencias**: Task 13 (Block Explorer UI)

## Objetivo

Implementar real-time updates usando WebSockets para que el Block Explorer UI muestre nuevos bloques, transacciones y mining jobs automáticamente sin necesidad de refrescar la página. Esto mejora significativamente la UX al proporcionar feedback instantáneo.

## Motivación

**Problemas actuales**:
- Users deben refrescar manualmente para ver nuevos bloques
- No hay notificaciones de mining jobs completados
- Stats desactualizadas hasta refresh manual
- Pobre UX para monitorear blockchain en tiempo real

**Solución**: WebSocket server con Faye:
- **Real-time block updates** - Nuevos bloques aparecen automáticamente
- **Mining job notifications** - Notificaciones cuando mining completa
- **Live stats** - Counters actualizados en tiempo real
- **Subscription-based** - Subscribe solo a chains específicas
- **Efficient** - Solo envia deltas, no full reloads
- **Fallback** - Long polling para browsers sin WebSocket

**Educational value**: Enseña arquitectura real-time, WebSockets, pub/sub patterns, y cómo construir UIs reactivas (usado por Slack, Discord, trading platforms).

## Cambios Técnicos

### 1. Setup & Dependencies

**Gemfile**:
```ruby
# WebSocket support
gem 'faye', '~> 1.4'  # WebSocket server
gem 'faye-websocket', '~> 0.11'
gem 'eventmachine', '~> 1.2'  # Required by Faye

# Async HTTP (optional, for better performance)
gem 'thin', '~> 1.8'  # EventMachine-based server
```

**config/faye.ru** (Faye server config):
```ruby
require 'faye'
require_relative '../config/environment'

# Faye server setup
faye_server = Faye::RackAdapter.new(
  mount: '/faye',
  timeout: 45,
  engine: {
    type: Faye::Redis,
    host: ENV.fetch('REDIS_URL', 'localhost'),
    port: 6379
  }
)

# Server-side extensions
class ServerAuth
  def incoming(message, request, callback)
    # Validate subscriptions
    if message['channel'] =~ /^\/blockchain\//
      # Allow subscription
      callback.call(message)
    elsif message['channel'] == '/meta/subscribe'
      # Allow meta channel
      callback.call(message)
    else
      # Reject unauthorized channels
      message['error'] = 'Unauthorized channel'
      callback.call(message)
    end
  end
end

faye_server.add_extension(ServerAuth.new)

# Mount Faye server
run faye_server
```

### 2. WebSocket Publisher Service

**lib/websocket/publisher.rb**:
```ruby
require 'faye'

module ChainForge
  module WebSocket
    class Publisher
      FAYE_URL = ENV.fetch('FAYE_URL', 'http://localhost:9292/faye')

      class << self
        # Publish new block
        def publish_block(block)
          publish("/blockchain/#{block.blockchain_id}/blocks", {
            type: 'new_block',
            data: {
              id: block.id.to_s,
              index: block.index,
              hash: block.hash,
              previous_hash: block.previous_hash,
              timestamp: block.timestamp,
              difficulty: block.difficulty,
              nonce: block.nonce,
              miner: block.miner,
              mining_duration: block.mining_duration,
              transactions_count: block.transactions.length,
              created_at: block.created_at.iso8601
            }
          })

          # Also publish to global channel
          publish('/blockchain/all', {
            type: 'new_block',
            blockchain_id: block.blockchain_id.to_s,
            blockchain_name: block.blockchain.name,
            data: {
              id: block.id.to_s,
              index: block.index,
              hash: block.hash[0..15] + '...',
              miner: block.miner[0..12],
              transactions_count: block.transactions.length
            }
          })

          LOGGER.info "Published new block to WebSocket",
            blockchain_id: block.blockchain_id.to_s,
            block_index: block.index
        end

        # Publish mining job update
        def publish_mining_job(job)
          publish("/blockchain/#{job.blockchain_id}/mining", {
            type: 'mining_update',
            data: {
              job_id: job.job_id,
              status: job.status,
              progress: job.progress,
              message: job.progress_message,
              result: job.result
            }
          })
        end

        # Publish transaction to mempool
        def publish_transaction(tx, blockchain_id)
          publish("/blockchain/#{blockchain_id}/transactions", {
            type: 'new_transaction',
            data: {
              tx_hash: tx['tx_hash'],
              from: tx['from'],
              to: tx['to'],
              amount: tx['amount'],
              fee: tx['fee'],
              timestamp: tx['timestamp']
            }
          })
        end

        # Publish stats update
        def publish_stats(blockchain_id, stats)
          publish("/blockchain/#{blockchain_id}/stats", {
            type: 'stats_update',
            data: stats
          })
        end

        # Publish difficulty adjustment
        def publish_difficulty_adjustment(blockchain_id, old_diff, new_diff)
          publish("/blockchain/#{blockchain_id}/difficulty", {
            type: 'difficulty_adjusted',
            data: {
              old_difficulty: old_diff,
              new_difficulty: new_diff,
              timestamp: Time.now.utc.iso8601
            }
          })
        end

        private

        def publish(channel, message)
          client.publish(channel, message)
        rescue => e
          LOGGER.error "Failed to publish to WebSocket",
            channel: channel,
            error: e.message
        end

        def client
          @client ||= Faye::Client.new(FAYE_URL)
        end
      end
    end
  end
end
```

### 3. Model Callbacks

**src/models/block.rb** (updated):
```ruby
class Block
  include Mongoid::Document
  include Mongoid::Timestamps

  # ... existing code ...

  # Callbacks
  after_create :publish_to_websocket

  private

  def publish_to_websocket
    ChainForge::WebSocket::Publisher.publish_block(self)

    # Update blockchain stats
    stats = blockchain.stats_cached
    ChainForge::WebSocket::Publisher.publish_stats(blockchain_id, stats)
  end
end
```

**src/models/mining_job.rb** (updated):
```ruby
class MiningJob
  include Mongoid::Document
  include Mongoid::Timestamps

  # ... existing code ...

  after_save :publish_status_update, if: :status_changed?

  private

  def publish_status_update
    ChainForge::WebSocket::Publisher.publish_mining_job(self)
  end
end
```

**src/models/mempool.rb** (updated):
```ruby
class Mempool
  # ... existing code ...

  def add_transaction(tx_data)
    tx = Transaction.new(tx_data)

    unless tx.valid?
      raise ValidationError, "Invalid transaction: #{tx.errors.full_messages.join(', ')}"
    end

    # Add to mempool
    self.pending_transactions << tx.as_json
    self.total_transactions += 1
    save!

    # Publish to WebSocket
    ChainForge::WebSocket::Publisher.publish_transaction(tx.as_json, blockchain_id)

    tx
  end
end
```

### 4. Client-Side WebSocket Integration

**public/js/websocket.js**:
```javascript
// WebSocket client using Faye
class ChainForgeWebSocket {
  constructor() {
    this.client = null;
    this.subscriptions = new Map();
    this.connected = false;
  }

  // Initialize connection
  connect(fayeUrl = '/faye') {
    if (this.client) return;

    this.client = new Faye.Client(fayeUrl, {
      timeout: 45,
      retry: 5
    });

    // Connection lifecycle
    this.client.on('transport:down', () => {
      console.warn('WebSocket connection lost. Reconnecting...');
      this.connected = false;
      this.showConnectionStatus('disconnected');
    });

    this.client.on('transport:up', () => {
      console.log('WebSocket connected');
      this.connected = true;
      this.showConnectionStatus('connected');
    });

    return this;
  }

  // Subscribe to blockchain updates
  subscribeToBlockchain(blockchainId, handlers = {}) {
    if (!this.client) {
      console.error('WebSocket not connected');
      return;
    }

    const subscriptionKey = `blockchain-${blockchainId}`;

    // Unsubscribe if already subscribed
    if (this.subscriptions.has(subscriptionKey)) {
      this.subscriptions.get(subscriptionKey).cancel();
    }

    // Subscribe to blocks
    const blocksSub = this.client.subscribe(
      `/blockchain/${blockchainId}/blocks`,
      (message) => {
        console.log('New block received:', message);
        if (handlers.onBlock) {
          handlers.onBlock(message.data);
        }
      }
    );

    // Subscribe to mining updates
    const miningSub = this.client.subscribe(
      `/blockchain/${blockchainId}/mining`,
      (message) => {
        console.log('Mining update:', message);
        if (handlers.onMiningUpdate) {
          handlers.onMiningUpdate(message.data);
        }
      }
    );

    // Subscribe to transactions
    const txSub = this.client.subscribe(
      `/blockchain/${blockchainId}/transactions`,
      (message) => {
        console.log('New transaction:', message);
        if (handlers.onTransaction) {
          handlers.onTransaction(message.data);
        }
      }
    );

    // Subscribe to stats
    const statsSub = this.client.subscribe(
      `/blockchain/${blockchainId}/stats`,
      (message) => {
        console.log('Stats update:', message);
        if (handlers.onStats) {
          handlers.onStats(message.data);
        }
      }
    );

    // Subscribe to difficulty changes
    const difficultySub = this.client.subscribe(
      `/blockchain/${blockchainId}/difficulty`,
      (message) => {
        console.log('Difficulty adjusted:', message);
        if (handlers.onDifficultyChange) {
          handlers.onDifficultyChange(message.data);
        }
      }
    );

    // Store subscriptions
    this.subscriptions.set(subscriptionKey, {
      blocks: blocksSub,
      mining: miningSub,
      transactions: txSub,
      stats: statsSub,
      difficulty: difficultySub,
      cancel: () => {
        blocksSub.cancel();
        miningSub.cancel();
        txSub.cancel();
        statsSub.cancel();
        difficultySub.cancel();
      }
    });

    return this;
  }

  // Subscribe to all blockchains
  subscribeToAll(handlers = {}) {
    if (!this.client) {
      console.error('WebSocket not connected');
      return;
    }

    const subscription = this.client.subscribe(
      '/blockchain/all',
      (message) => {
        console.log('Global update:', message);
        if (handlers.onBlock) {
          handlers.onBlock(message.data, message.blockchain_id);
        }
      }
    );

    this.subscriptions.set('all', subscription);
    return this;
  }

  // Unsubscribe from blockchain
  unsubscribe(blockchainId) {
    const key = `blockchain-${blockchainId}`;
    const sub = this.subscriptions.get(key);

    if (sub) {
      sub.cancel();
      this.subscriptions.delete(key);
    }
  }

  // Disconnect
  disconnect() {
    if (this.client) {
      this.subscriptions.forEach(sub => sub.cancel());
      this.subscriptions.clear();
      this.client.disconnect();
      this.client = null;
      this.connected = false;
    }
  }

  // Show connection status
  showConnectionStatus(status) {
    const indicator = document.getElementById('ws-status');
    if (!indicator) return;

    if (status === 'connected') {
      indicator.className = 'bg-green-500 text-white px-3 py-1 rounded-full text-xs';
      indicator.textContent = '🟢 Live';
    } else {
      indicator.className = 'bg-red-500 text-white px-3 py-1 rounded-full text-xs';
      indicator.textContent = '🔴 Disconnected';
    }
  }
}

// Global instance
const ws = new ChainForgeWebSocket();
```

### 5. Updated Views with WebSocket

**views/chains/show.slim** (additions):
```slim
/ WebSocket status indicator
.fixed.top-4.right-4.z-50
  #ws-status.bg-gray-500.text-white.px-3.py-1.rounded-full.text-xs
    | ⚪ Connecting...

/ ... existing content ...

javascript:
  document.addEventListener('DOMContentLoaded', () => {
    // Connect to WebSocket
    ws.connect();

    // Subscribe to this blockchain
    const blockchainId = '#{@chain.id}';

    ws.subscribeToBlockchain(blockchainId, {
      // New block handler
      onBlock: (block) => {
        console.log('New block added:', block);

        // Show notification
        showToast(`New block #${block.index} mined!`, 'success');

        // Update stats
        updateStats();

        // Add block to visual chain
        addBlockToChain(block);

        // Optionally reload page for full update
        if (confirm('New block mined! Reload to see full details?')) {
          location.reload();
        }
      },

      // Mining update handler
      onMiningUpdate: (job) => {
        console.log('Mining progress:', job);

        // Update progress bar if exists
        const progressBar = document.getElementById(`job-${job.job_id}-progress`);
        if (progressBar) {
          progressBar.style.width = `${job.progress}%`;
          progressBar.textContent = job.message;
        }

        // Show completion notification
        if (job.status === 'complete') {
          showToast(`Mining completed! Block #${job.result.block_index}`, 'success');
          updateStats();
        } else if (job.status === 'failed') {
          showToast(`Mining failed: ${job.error}`, 'error');
        }
      },

      // Transaction handler
      onTransaction: (tx) => {
        console.log('New transaction in mempool:', tx);

        // Update pending transaction count
        const pendingCount = document.getElementById('pending-tx-count');
        if (pendingCount) {
          const current = parseInt(pendingCount.textContent);
          pendingCount.textContent = current + 1;
        }
      },

      // Stats update handler
      onStats: (stats) => {
        console.log('Stats updated:', stats);

        // Update stats display
        const totalBlocks = document.getElementById('total-blocks');
        if (totalBlocks) {
          totalBlocks.textContent = formatNumber(stats.total_blocks);
        }

        const totalTransactions = document.getElementById('total-transactions');
        if (totalTransactions) {
          totalTransactions.textContent = formatNumber(stats.total_transactions);
        }
      },

      // Difficulty change handler
      onDifficultyChange: (data) => {
        console.log('Difficulty adjusted:', data);

        showToast(
          `Difficulty adjusted: ${data.old_difficulty} → ${data.new_difficulty}`,
          'info'
        );

        // Update difficulty display
        const difficultyDisplay = document.getElementById('current-difficulty');
        if (difficultyDisplay) {
          difficultyDisplay.textContent = data.new_difficulty;
        }
      }
    });

    // Helper to update stats via AJAX
    function updateStats() {
      fetch(`/api/v1/chain/${blockchainId}`)
        .then(res => res.json())
        .then(data => {
          // Update UI with fresh data
          const totalBlocks = document.getElementById('total-blocks');
          if (totalBlocks) {
            totalBlocks.textContent = formatNumber(data.blockchain.total_blocks);
          }
        })
        .catch(err => console.error('Failed to fetch stats:', err));
    }

    // Helper to add block to visual chain
    function addBlockToChain(block) {
      const chain = document.getElementById('block-chain-visual');
      if (!chain) return;

      const blockEl = document.createElement('div');
      blockEl.className = 'flex-shrink-0 animate-slide-in';
      blockEl.innerHTML = `
        <div class="bg-gradient-to-br from-indigo-500 to-purple-600 text-white rounded-lg p-4 w-48 shadow-lg">
          <div class="flex justify-between items-center mb-2">
            <div class="text-xs font-semibold">Block #${block.index}</div>
            <div class="text-xs">⛏️ ${block.difficulty}</div>
          </div>
          <div class="text-xs font-mono mb-2 truncate">${block.hash}</div>
          <div class="text-xs">📝 ${block.transactions_count} tx</div>
          <div class="text-xs mt-2">⏱️ ${block.mining_duration.toFixed(2)}s</div>
        </div>
      `;

      chain.appendChild(blockEl);

      // Scroll to show new block
      blockEl.scrollIntoView({ behavior: 'smooth', inline: 'end' });
    }
  });

  // Cleanup on page unload
  window.addEventListener('beforeunload', () => {
    ws.disconnect();
  });
```

**views/index.slim** (additions for homepage):
```slim
/ WebSocket status
.fixed.top-4.right-4.z-50
  #ws-status.bg-gray-500.text-white.px-3.py-1.rounded-full.text-xs
    | ⚪ Connecting...

/ ... existing content ...

javascript:
  document.addEventListener('DOMContentLoaded', () => {
    // Connect and subscribe to all blockchains
    ws.connect().subscribeToAll({
      onBlock: (blockData, blockchainId) => {
        console.log('New block across network:', blockData, blockchainId);

        // Show toast notification
        showToast(
          `New block #${blockData.index} mined on ${blockData.blockchain_name || 'chain'}`,
          'success'
        );

        // Update global stats
        const totalBlocks = document.getElementById('global-total-blocks');
        if (totalBlocks) {
          const current = parseInt(totalBlocks.textContent.replace(/,/g, ''));
          totalBlocks.textContent = formatNumber(current + 1);
        }

        // Optionally add to recent blocks table
        addToRecentBlocks(blockData, blockchainId);
      }
    });

    function addToRecentBlocks(block, blockchainId) {
      const table = document.querySelector('#recent-blocks-table tbody');
      if (!table) return;

      const row = document.createElement('tr');
      row.className = 'hover:bg-gray-50 animate-slide-in';
      row.innerHTML = `
        <td class="px-6 py-4 whitespace-nowrap">
          <a href="/chains/${blockchainId}/blocks/${block.id}" class="text-indigo-600 hover:text-indigo-900 font-medium">
            #${block.index}
          </a>
        </td>
        <td class="px-6 py-4 whitespace-nowrap">
          <a href="/chains/${blockchainId}" class="text-gray-900 hover:text-indigo-600">
            ${block.blockchain_name || 'Unknown'}
          </a>
        </td>
        <td class="px-6 py-4">
          <code class="text-xs bg-gray-100 px-2 py-1 rounded">${block.hash}</code>
        </td>
        <td class="px-6 py-4 whitespace-nowrap">
          <code class="text-xs">${block.miner}</code>
        </td>
        <td class="px-6 py-4 whitespace-nowrap text-center">
          <span class="bg-purple-100 text-purple-800 px-2 py-1 rounded-full text-xs font-medium">
            ${block.transactions_count}
          </span>
        </td>
        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
          Just now
        </td>
      `;

      // Add to top of table
      table.insertBefore(row, table.firstChild);

      // Remove last row if too many
      if (table.children.length > 10) {
        table.removeChild(table.lastChild);
      }
    }
  });
```

### 6. Layout Updates

**views/layout.slim** (add Faye client):
```slim
doctype html
html lang="en"
  head
    / ... existing head content ...

    / Faye WebSocket client
    script src="/faye/client.js"

    / Custom WebSocket handler
    script src="/js/websocket.js"
```

### 7. Docker Setup

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
      - FAYE_URL=http://faye:9292/faye
    depends_on:
      - redis
      - mongo
      - faye

  # Faye WebSocket server
  faye:
    build: .
    ports:
      - "9292:9292"
    environment:
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - redis
    command: bundle exec rackup config/faye.ru -p 9292 -o 0.0.0.0

  worker:
    # ... existing worker config ...

  redis:
    # ... existing redis config ...

  mongo:
    # ... existing mongo config ...
```

### 8. Nginx Reverse Proxy (Production)

**nginx.conf**:
```nginx
upstream app {
  server app:1910;
}

upstream faye {
  server faye:9292;
}

server {
  listen 80;
  server_name chainforge.example.com;

  # Main app
  location / {
    proxy_pass http://app;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  # Faye WebSocket
  location /faye {
    proxy_pass http://faye;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 86400;  # 24 hours for long-lived connections
  }
}
```

### 9. Tests

**spec/websocket/publisher_spec.rb**:
```ruby
RSpec.describe ChainForge::WebSocket::Publisher do
  let(:blockchain) { create(:blockchain) }
  let(:block) { create(:block, blockchain: blockchain) }

  before do
    # Mock Faye client
    @mock_client = instance_double(Faye::Client)
    allow(Faye::Client).to receive(:new).and_return(@mock_client)
  end

  describe '.publish_block' do
    it 'publishes block to blockchain channel' do
      expect(@mock_client).to receive(:publish).with(
        "/blockchain/#{blockchain.id}/blocks",
        hash_including(
          type: 'new_block',
          data: hash_including(
            id: block.id.to_s,
            index: block.index,
            hash: block.hash
          )
        )
      )

      described_class.publish_block(block)
    end

    it 'publishes to global channel' do
      expect(@mock_client).to receive(:publish).with(
        '/blockchain/all',
        hash_including(
          type: 'new_block',
          blockchain_id: blockchain.id.to_s
        )
      )

      described_class.publish_block(block)
    end
  end

  describe '.publish_mining_job' do
    let(:job) { create(:mining_job, blockchain: blockchain, status: 'working', progress: 50) }

    it 'publishes job update' do
      expect(@mock_client).to receive(:publish).with(
        "/blockchain/#{blockchain.id}/mining",
        hash_including(
          type: 'mining_update',
          data: hash_including(
            job_id: job.job_id,
            status: 'working',
            progress: 50
          )
        )
      )

      described_class.publish_mining_job(job)
    end
  end
end
```

**spec/features/websocket_updates_spec.rb**:
```ruby
RSpec.describe 'WebSocket Updates', type: :feature, js: true do
  let(:blockchain) { create(:blockchain) }

  before do
    visit "/chains/#{blockchain.id}"

    # Wait for WebSocket connection
    expect(page).to have_css('#ws-status', text: 'Live')
  end

  it 'shows notification when new block is mined' do
    # Simulate new block via WebSocket
    block = create(:block, blockchain: blockchain)
    ChainForge::WebSocket::Publisher.publish_block(block)

    # Check for toast notification
    expect(page).to have_content("New block ##{block.index} mined!")
  end

  it 'updates stats in real-time' do
    initial_count = blockchain.total_blocks

    # Create new block
    block = create(:block, blockchain: blockchain)
    ChainForge::WebSocket::Publisher.publish_block(block)

    # Stats should update
    expect(page).to have_content(initial_count + 1)
  end
end
```

## Performance & Scalability

### Connection Limits
- Faye with Redis backend scales horizontally
- Each server can handle ~10,000 concurrent connections
- Use nginx for load balancing multiple Faye servers

### Message Rate
- Throttle updates to avoid overwhelming clients
- Batch stats updates (max once per second)
- Use message compression for large payloads

### Fallback Strategy
```javascript
// Long polling fallback for older browsers
const client = new Faye.Client('/faye', {
  timeout: 45,
  retry: 5,
  disabled: ['websocket']  // Force long polling
});
```

## Security Considerations

1. **Channel Authorization** - Validate subscriptions server-side
2. **Rate Limiting** - Limit messages per client
3. **Authentication** - Require auth for private channels (future)
4. **Message Validation** - Sanitize all published data
5. **CORS** - Configure properly for cross-origin requests

## Environment Variables

```bash
# Faye WebSocket
FAYE_URL=http://localhost:9292/faye
FAYE_REDIS_HOST=localhost
FAYE_REDIS_PORT=6379

# Connection limits
FAYE_TIMEOUT=45
FAYE_MAX_CONNECTIONS=10000
```

## Criterios de Aceptación

- [ ] Faye server configurado y funcionando
- [ ] Publisher service publica eventos correctamente
- [ ] Block creation trigger WebSocket publish
- [ ] Mining job updates enviados via WebSocket
- [ ] Frontend conecta a WebSocket automáticamente
- [ ] Notificaciones toast para nuevos bloques
- [ ] Stats actualizadas en tiempo real
- [ ] Visual block chain actualizado live
- [ ] Connection status indicator funciona
- [ ] Reconnection automática si se pierde conexión
- [ ] Tests de WebSocket completos
- [ ] Docker Compose incluye Faye service
- [ ] Nginx config para WebSocket proxy
- [ ] Fallback a long polling funciona
- [ ] Documentación de canales y eventos

## Educational Value

Este task enseña:
- **WebSocket protocol** - Full-duplex communication
- **Pub/Sub pattern** - Publisher-subscriber architecture
- **Real-time UIs** - Reactive user interfaces
- **Event-driven architecture** - Decoupled components
- **Faye framework** - Ruby WebSocket library
- **Connection management** - Reconnection, timeouts
- **Horizontal scaling** - Redis backend for multi-server

Tecnologías similares usadas por:
- **Slack** - Real-time messaging con WebSockets
- **Discord** - Voice & text chat real-time
- **Coinbase Pro** - Live cryptocurrency prices
- **TradingView** - Real-time market data
- **GitHub** - Live notifications

## Optional Enhancements

### 1. Presence Tracking
```javascript
// Track who's viewing a blockchain
ws.client.subscribe('/blockchain/${id}/presence', (data) => {
  updateViewerCount(data.viewers);
});
```

### 2. Typing Indicators (for comments/chat)
```javascript
// Show who's typing
ws.client.publish('/blockchain/${id}/typing', { user: username });
```

### 3. Historical Replay
```javascript
// Replay missed events on reconnection
ws.client.subscribe('/blockchain/${id}/catch-up', (events) => {
  events.forEach(event => handleEvent(event));
});
```

## Referencias

- [Faye Documentation](https://faye.jcoglan.com/)
- [WebSocket RFC 6455](https://tools.ietf.org/html/rfc6455)
- [Real-time Web Applications](https://www.html5rocks.com/en/tutorials/websockets/basics/)
- [Scaling WebSockets](https://www.nginx.com/blog/websocket-nginx/)
- [EventMachine](https://github.com/eventmachine/eventmachine)
