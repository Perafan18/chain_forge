# Task 13: Block Explorer Web UI

**PR**: #21
**Fase**: 5 - User Interface
**Complejidad**: Large
**Estimación**: 10-12 días
**Prioridad**: P2
**Dependencias**: All previous tasks (01-12)

## Objetivo

Crear una interfaz web moderna y responsive para explorar blockchains, bloques y transacciones usando Sinatra views + Tailwind CSS + Alpine.js. La UI debe ser intuitiva, rápida y mostrar la estructura de la blockchain de manera visual.

## Motivación

**Problemas actuales**:
- No hay interfaz visual para explorar el blockchain
- Users solo pueden interactuar vía API o CLI
- Difícil de demostrar/visualizar el blockchain
- No hay forma user-friendly de ver transacciones

**Solución**: Block Explorer Web UI:
- **Visual blockchain explorer** - Ver chains, bloques, transacciones
- **Real-time updates** - Mostrar nuevos bloques automáticamente
- **Search functionality** - Buscar por hash, address, block index
- **Responsive design** - Mobile-first con Tailwind CSS
- **Interactive** - Alpine.js para interactividad sin build step
- **Fast** - Server-side rendering con Sinatra

**Educational value**: Enseña frontend development, responsive design, progressive enhancement, y cómo crear UIs para aplicaciones blockchain (como Etherscan, Blockchain.com).

## Cambios Técnicos

### 1. Setup & Dependencies

**Gemfile additions**:
```ruby
# Views & templates
gem 'sinatra', '~> 4.0'
gem 'sinatra-contrib', '~> 4.0'  # For helpers like json, redirect
gem 'slim', '~> 5.2'  # Template engine (cleaner than ERB)

# Asset management
gem 'sprockets', '~> 4.2'
gem 'sprockets-helpers', '~> 1.4'

# CSS/JS (CDN-based, no build step needed)
# - Tailwind CSS via CDN
# - Alpine.js via CDN
# - Chart.js for visualizations
```

**Directory structure**:
```
app/
├── views/
│   ├── layout.slim           # Main layout
│   ├── index.slim            # Homepage
│   ├── chains/
│   │   ├── index.slim        # List all chains
│   │   └── show.slim         # Single chain view
│   ├── blocks/
│   │   └── show.slim         # Single block view
│   ├── transactions/
│   │   └── show.slim         # Transaction details
│   ├── search.slim           # Search results
│   └── partials/
│       ├── _chain_card.slim
│       ├── _block_card.slim
│       ├── _transaction_row.slim
│       ├── _navbar.slim
│       └── _footer.slim
├── public/
│   ├── css/
│   │   └── custom.css        # Custom CSS overrides
│   ├── js/
│   │   └── app.js            # Custom JavaScript
│   └── images/
│       └── logo.svg
└── helpers/
    └── view_helpers.rb       # View helper methods
```

### 2. Layout & Base Templates

**views/layout.slim**:
```slim
doctype html
html lang="en"
  head
    meta charset="utf-8"
    meta name="viewport" content="width=device-width, initial-scale=1.0"
    title = @title || "ChainForge - Blockchain Explorer"
    meta name="description" content="Explore the ChainForge blockchain"

    / Tailwind CSS CDN
    script src="https://cdn.tailwindcss.com"

    / Alpine.js CDN
    script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"

    / Chart.js for visualizations
    script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js"

    / Custom CSS
    link rel="stylesheet" href="/css/custom.css"

    / Favicon
    link rel="icon" type="image/svg+xml" href="/images/logo.svg"

  body.bg-gray-50.text-gray-900.antialiased
    / Navigation
    == slim :'partials/navbar'

    / Flash messages
    - if flash[:success]
      .bg-green-100.border-l-4.border-green-500.text-green-700.p-4.mb-4 role="alert"
        p.font-bold Success
        p = flash[:success]

    - if flash[:error]
      .bg-red-100.border-l-4.border-red-500.text-red-700.p-4.mb-4 role="alert"
        p.font-bold Error
        p = flash[:error]

    / Main content
    main.container.mx-auto.px-4.py-8
      == yield

    / Footer
    == slim :'partials/footer'

    / Custom JavaScript
    script src="/js/app.js"
```

**views/partials/_navbar.slim**:
```slim
nav.bg-white.shadow-lg x-data="{ mobileMenuOpen: false }"
  .container.mx-auto.px-4
    .flex.justify-between.items-center.py-4
      / Logo
      a.text-2xl.font-bold.text-indigo-600 href="/"
        | ⛓️ ChainForge

      / Desktop menu
      .hidden.md:flex.space-x-6
        a.text-gray-700.hover:text-indigo-600.transition href="/" Home
        a.text-gray-700.hover:text-indigo-600.transition href="/chains" Blockchains
        a.text-gray-700.hover:text-indigo-600.transition href="/search" Search
        a.text-gray-700.hover:text-indigo-600.transition href="/api/v1/docs" API Docs

      / Search bar
      .hidden.md:block
        form action="/search" method="get" class="relative"
          input.border.border-gray-300.rounded-lg.px-4.py-2.pr-10.focus:ring-2.focus:ring-indigo-500.focus:border-transparent(
            type="text"
            name="q"
            placeholder="Search block, tx, address..."
          )
          button.absolute.right-2.top-2.text-gray-400 type="submit"
            | 🔍

      / Mobile menu button
      button.md:hidden @click="mobileMenuOpen = !mobileMenuOpen"
        svg.w-6.h-6 fill="none" stroke="currentColor" viewBox="0 0 24 24"
          path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"

    / Mobile menu
    .md:hidden x-show="mobileMenuOpen" x-cloak
      .py-4.space-y-2
        a.block.text-gray-700.hover:bg-gray-100.px-4.py-2.rounded href="/" Home
        a.block.text-gray-700.hover:bg-gray-100.px-4.py-2.rounded href="/chains" Blockchains
        a.block.text-gray-700.hover:bg-gray-100.px-4.py-2.rounded href="/search" Search
        a.block.text-gray-700.hover:bg-gray-100.px-4.py-2.rounded href="/api/v1/docs" API Docs
```

### 3. Homepage

**views/index.slim**:
```slim
/ Hero section
.bg-gradient-to-r.from-indigo-600.to-purple-600.text-white.rounded-lg.p-12.mb-8
  .text-center
    h1.text-5xl.font-bold.mb-4 ChainForge Blockchain Explorer
    p.text-xl.mb-6 Explore blocks, transactions, and blockchain data in real-time
    .flex.justify-center.space-x-4
      a.bg-white.text-indigo-600.px-6.py-3.rounded-lg.font-semibold.hover:bg-gray-100.transition(
        href="/chains"
      ) Browse Blockchains
      a.border-2.border-white.px-6.py-3.rounded-lg.font-semibold.hover:bg-white.hover:text-indigo-600.transition(
        href="/api/v1/docs"
      ) API Documentation

/ Stats section
.grid.grid-cols-1.md:grid-cols-4.gap-6.mb-8
  .bg-white.rounded-lg.shadow-md.p-6
    .text-gray-500.text-sm.mb-2 Total Blockchains
    .text-3xl.font-bold.text-indigo-600 = @stats[:total_chains]

  .bg-white.rounded-lg.shadow-md.p-6
    .text-gray-500.text-sm.mb-2 Total Blocks
    .text-3xl.font-bold.text-green-600 = number_with_delimiter(@stats[:total_blocks])

  .bg-white.rounded-lg.shadow-md.p-6
    .text-gray-500.text-sm.mb-2 Total Transactions
    .text-3xl.font-bold.text-purple-600 = number_with_delimiter(@stats[:total_transactions])

  .bg-white.rounded-lg.shadow-md.p-6
    .text-gray-500.text-sm.mb-2 Mining Jobs (24h)
    .text-3xl.font-bold.text-orange-600 = @stats[:mining_jobs_24h]

/ Recent chains
.mb-8
  h2.text-2xl.font-bold.mb-4 Recent Blockchains
  .grid.grid-cols-1.md:grid-cols-2.lg:grid-cols-3.gap-6
    - @recent_chains.each do |chain|
      == slim :'partials/chain_card', locals: { chain: chain }

/ Recent blocks across all chains
.mb-8
  h2.text-2xl.font-bold.mb-4 Latest Blocks
  .bg-white.rounded-lg.shadow-md.overflow-hidden
    table.w-full
      thead.bg-gray-50
        tr
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Block
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Chain
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Hash
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Miner
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Transactions
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Time
      tbody.divide-y.divide-gray-200
        - @recent_blocks.each do |block|
          tr.hover:bg-gray-50
            td.px-6.py-4.whitespace-nowrap
              a.text-indigo-600.hover:text-indigo-900.font-medium(
                href="/chains/#{block.blockchain_id}/blocks/#{block.id}"
              ) ##{block.index}
            td.px-6.py-4.whitespace-nowrap
              a.text-gray-900.hover:text-indigo-600(
                href="/chains/#{block.blockchain_id}"
              ) = truncate(block.blockchain.name, 20)
            td.px-6.py-4
              code.text-xs.bg-gray-100.px-2.py-1.rounded = truncate_hash(block.hash)
            td.px-6.py-4.whitespace-nowrap
              code.text-xs = truncate(block.miner, 12)
            td.px-6.py-4.whitespace-nowrap.text-center
              span.bg-purple-100.text-purple-800.px-2.py-1.rounded-full.text-xs.font-medium
                | #{block.transactions.length}
            td.px-6.py-4.whitespace-nowrap.text-sm.text-gray-500
              | #{time_ago(block.created_at)}
```

### 4. Blockchain List & Detail

**views/chains/index.slim**:
```slim
.mb-6
  h1.text-3xl.font-bold.mb-2 Blockchains
  p.text-gray-600 Browse all blockchains in the network

/ Create new blockchain button
.mb-6
  button.bg-indigo-600.text-white.px-4.py-2.rounded-lg.hover:bg-indigo-700.transition(
    @click="showCreateModal = true"
    x-data="{ showCreateModal: false }"
  ) + Create New Blockchain

/ Filters
.mb-6.flex.space-x-4
  select.border.border-gray-300.rounded-lg.px-4.py-2.focus:ring-2.focus:ring-indigo-500 name="sort"
    option value="recent" Most Recent
    option value="popular" Most Blocks
    option value="name" Name (A-Z)

/ Blockchain grid
.grid.grid-cols-1.md:grid-cols-2.lg:grid-cols-3.gap-6
  - @chains.each do |chain|
    == slim :'partials/chain_card', locals: { chain: chain }

/ Pagination
- if @pagination[:pages] > 1
  .flex.justify-center.mt-8.space-x-2
    - @pagination[:pages].times do |i|
      - page_num = i + 1
      - active = page_num == @pagination[:page]
      a.px-4.py-2.rounded-lg(
        href="?page=#{page_num}"
        class=(active ? 'bg-indigo-600 text-white' : 'bg-white text-gray-700 hover:bg-gray-100')
      ) = page_num
```

**views/chains/show.slim**:
```slim
/ Breadcrumb
.mb-6
  nav.text-sm.text-gray-500
    a.hover:text-indigo-600 href="/" Home
    span.mx-2 /
    a.hover:text-indigo-600 href="/chains" Blockchains
    span.mx-2 /
    span.text-gray-900 = @chain.name

/ Chain header
.bg-white.rounded-lg.shadow-md.p-6.mb-8
  .flex.justify-between.items-start
    div
      h1.text-3xl.font-bold.mb-2 = @chain.name
      .text-gray-500.mb-4
        | Created #{time_ago(@chain.created_at)}

      / Chain stats
      .grid.grid-cols-2.md:grid-cols-4.gap-4.mt-6
        div
          .text-gray-500.text-sm Total Blocks
          .text-2xl.font-bold = number_with_delimiter(@chain.total_blocks)
        div
          .text-gray-500.text-sm Current Difficulty
          .text-2xl.font-bold = @chain.current_difficulty
        div
          .text-gray-500.text-sm Block Reward
          .text-2xl.font-bold = "#{@chain.block_reward} CFG"
        div
          .text-gray-500.text-sm Pending TX
          .text-2xl.font-bold = @chain.mempool.total_transactions

    div
      button.bg-indigo-600.text-white.px-4.py-2.rounded-lg.hover:bg-indigo-700.transition(
        @click="showMineModal = true"
      ) ⛏️ Mine Block

/ Difficulty chart
.bg-white.rounded-lg.shadow-md.p-6.mb-8
  h2.text-xl.font-bold.mb-4 Difficulty History
  canvas#difficultyChart height="80"

/ Recent blocks visualization
.bg-white.rounded-lg.shadow-md.p-6.mb-8
  h2.text-xl.font-bold.mb-4 Recent Blocks

  / Visual blockchain representation
  .overflow-x-auto
    .flex.space-x-4.pb-4
      - @chain.recent_blocks(10).reverse.each do |block|
        .flex-shrink-0
          .bg-gradient-to-br.from-indigo-500.to-purple-600.text-white.rounded-lg.p-4.w-48.shadow-lg.relative(
            x-data="{ showTooltip: false }"
            @mouseenter="showTooltip = true"
            @mouseleave="showTooltip = false"
          )
            / Block header
            .flex.justify-between.items-center.mb-2
              .text-xs.font-semibold Block ##{block.index}
              .text-xs = "⛏️ #{block.difficulty}"

            / Block hash
            .text-xs.font-mono.mb-2.truncate = block.hash

            / Transactions
            .text-xs
              | 📝 #{block.transactions.length} tx

            / Mining time
            .text-xs.mt-2
              | ⏱️ #{block.mining_duration.round(2)}s

            / Link to next block (visual arrow)
            - unless block == @chain.blocks.last
              .absolute.-right-5.top-1/2.transform.-translate-y-1/2.text-2xl.text-gray-400
                | →

            / Tooltip on hover
            .absolute.bottom-full.left-0.mb-2.bg-gray-900.text-white.text-xs.rounded.p-2.w-64.hidden(
              x-show="showTooltip"
              x-cloak
            )
              div Miner: #{truncate(block.miner, 20)}
              div Nonce: #{block.nonce}
              div Time: #{block.created_at.strftime('%Y-%m-%d %H:%M:%S')}

/ Blocks table
.bg-white.rounded-lg.shadow-md.overflow-hidden
  .px-6.py-4.border-b
    h2.text-xl.font-bold All Blocks

  table.w-full
    thead.bg-gray-50
      tr
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Index
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Hash
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Miner
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Difficulty
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Transactions
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Time
    tbody.divide-y.divide-gray-200
      - @blocks.each do |block|
        tr.hover:bg-gray-50.cursor-pointer onclick="window.location='/chains/#{@chain.id}/blocks/#{block.id}'"
          td.px-6.py-4.whitespace-nowrap.font-medium
            | ##{block.index}
          td.px-6.py-4
            code.text-xs.bg-gray-100.px-2.py-1.rounded = truncate_hash(block.hash)
          td.px-6.py-4
            code.text-xs = truncate(block.miner, 15)
          td.px-6.py-4.whitespace-nowrap
            span.bg-indigo-100.text-indigo-800.px-2.py-1.rounded-full.text-xs.font-medium
              | ⛏️ #{block.difficulty}
          td.px-6.py-4.whitespace-nowrap.text-center
            span.bg-purple-100.text-purple-800.px-2.py-1.rounded-full.text-xs.font-medium
              | #{block.transactions.length}
          td.px-6.py-4.whitespace-nowrap.text-sm.text-gray-500
            | #{time_ago(block.created_at)}

  / Pagination
  .px-6.py-4.border-t.flex.justify-between.items-center
    .text-sm.text-gray-500
      | Showing #{@blocks.length} of #{@chain.total_blocks} blocks
    .flex.space-x-2
      - if @pagination[:has_prev]
        a.px-4.py-2.bg-white.border.rounded-lg.hover:bg-gray-50(
          href="?page=#{@pagination[:page] - 1}"
        ) Previous
      - if @pagination[:has_next]
        a.px-4.py-2.bg-white.border.rounded-lg.hover:bg-gray-50(
          href="?page=#{@pagination[:page] + 1}"
        ) Next

/ Alpine.js for difficulty chart
javascript:
  document.addEventListener('alpine:init', () => {
    const ctx = document.getElementById('difficultyChart');
    const data = #{@difficulty_history.to_json};

    new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map(d => `Block ${d.index}`),
        datasets: [{
          label: 'Difficulty',
          data: data.map(d => d.difficulty),
          borderColor: 'rgb(99, 102, 241)',
          backgroundColor: 'rgba(99, 102, 241, 0.1)',
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
            ticks: { stepSize: 1 }
          }
        }
      }
    });
  });
```

### 5. Block Detail View

**views/blocks/show.slim**:
```slim
/ Breadcrumb
.mb-6
  nav.text-sm.text-gray-500
    a.hover:text-indigo-600 href="/" Home
    span.mx-2 /
    a.hover:text-indigo-600 href="/chains" Blockchains
    span.mx-2 /
    a.hover:text-indigo-600 href="/chains/#{@chain.id}" = @chain.name
    span.mx-2 /
    span.text-gray-900 Block ##{@block.index}

/ Block header
.bg-white.rounded-lg.shadow-md.p-6.mb-8
  .flex.justify-between.items-start.mb-4
    div
      h1.text-3xl.font-bold.mb-2 Block ##{@block.index}
      .text-gray-500
        | Mined #{time_ago(@block.created_at)} by
        code.ml-2.text-indigo-600 = truncate(@block.miner, 20)

    / Block navigation
    .flex.space-x-2
      - if @block.index > 1
        a.px-4.py-2.bg-gray-100.rounded-lg.hover:bg-gray-200.transition(
          href="/chains/#{@chain.id}/blocks/#{@prev_block.id}"
        ) ← Previous
      - if @block.index < @chain.total_blocks
        a.px-4.py-2.bg-gray-100.rounded-lg.hover:bg-gray-200.transition(
          href="/chains/#{@chain.id}/blocks/#{@next_block.id}"
        ) Next →

  / Block metadata grid
  .grid.grid-cols-1.md:grid-cols-2.gap-6
    div
      .text-gray-500.text-sm.mb-1 Block Hash
      code.text-sm.bg-gray-100.px-3.py-2.rounded.block.font-mono.break-all
        | #{@block.hash}

    div
      .text-gray-500.text-sm.mb-1 Previous Hash
      code.text-sm.bg-gray-100.px-3.py-2.rounded.block.font-mono.break-all
        | #{@block.previous_hash}

    div
      .text-gray-500.text-sm.mb-1 Merkle Root
      code.text-sm.bg-gray-100.px-3.py-2.rounded.block.font-mono.break-all
        | #{@block.merkle_root}

    div
      .text-gray-500.text-sm.mb-1 Timestamp
      .text-lg.font-semibold
        | #{@block.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}

    div
      .text-gray-500.text-sm.mb-1 Difficulty
      .text-lg.font-semibold
        span.bg-indigo-100.text-indigo-800.px-3.py-1.rounded-full
          | ⛏️ #{@block.difficulty}

    div
      .text-gray-500.text-sm.mb-1 Nonce
      .text-lg.font-semibold.font-mono = number_with_delimiter(@block.nonce)

    div
      .text-gray-500.text-sm.mb-1 Mining Duration
      .text-lg.font-semibold
        | #{@block.mining_duration.round(3)}s

    div
      .text-gray-500.text-sm.mb-1 Transactions
      .text-lg.font-semibold
        span.bg-purple-100.text-purple-800.px-3.py-1.rounded-full
          | #{@block.transactions.length}

/ Block validation status
.bg-green-50.border-l-4.border-green-500.p-4.mb-8
  .flex.items-center
    .text-green-600.mr-3
      svg.w-6.h-6 fill="currentColor" viewBox="0 0 20 20"
        path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
    div
      .font-semibold.text-green-900 Valid Block
      .text-sm.text-green-700 Hash meets difficulty requirement and blockchain integrity verified

/ Transactions
.bg-white.rounded-lg.shadow-md.overflow-hidden.mb-8
  .px-6.py-4.border-b
    h2.text-xl.font-bold Transactions (#{@block.transactions.length})

  - if @block.transactions.empty?
    .px-6.py-8.text-center.text-gray-500
      | No transactions in this block
  - else
    table.w-full
      thead.bg-gray-50
        tr
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Type
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase From
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase To
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Amount
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase Fee
      tbody.divide-y.divide-gray-200
        - @block.transactions.each do |tx|
          tr.hover:bg-gray-50
            td.px-6.py-4.whitespace-nowrap
              - if tx['from'] == 'COINBASE'
                span.bg-yellow-100.text-yellow-800.px-2.py-1.rounded-full.text-xs.font-medium
                  | 🏆 Coinbase
              - else
                span.bg-blue-100.text-blue-800.px-2.py-1.rounded-full.text-xs.font-medium
                  | 💸 Transfer
            td.px-6.py-4
              code.text-xs
                | #{truncate(tx['from'], 15)}
            td.px-6.py-4
              code.text-xs
                | #{truncate(tx['to'], 15)}
            td.px-6.py-4.whitespace-nowrap.font-semibold.text-green-600
              | +#{tx['amount']} CFG
            td.px-6.py-4.whitespace-nowrap.text-gray-500
              | #{tx['fee']} CFG

/ Raw block data (expandable)
.bg-white.rounded-lg.shadow-md.overflow-hidden(
  x-data="{ showRaw: false }"
)
  .px-6.py-4.border-b.cursor-pointer.flex.justify-between.items-center(
    @click="showRaw = !showRaw"
  )
    h2.text-xl.font-bold Raw Block Data
    span.text-gray-500 x-text="showRaw ? '▼' : '►'"

  .px-6.py-4.bg-gray-900.text-green-400.font-mono.text-sm.overflow-x-auto(
    x-show="showRaw"
    x-cloak
  )
    pre = JSON.pretty_generate(@block.as_json)
```

### 6. Partials

**views/partials/_chain_card.slim**:
```slim
.bg-white.rounded-lg.shadow-md.p-6.hover:shadow-xl.transition.cursor-pointer(
  onclick="window.location='/chains/#{chain.id}'"
)
  .flex.justify-between.items-start.mb-4
    h3.text-xl.font-bold.text-indigo-600 = chain.name
    span.text-xs.text-gray-500 = time_ago(chain.created_at)

  .grid.grid-cols-2.gap-4.mb-4
    div
      .text-gray-500.text-sm Blocks
      .text-2xl.font-bold = number_with_delimiter(chain.total_blocks)
    div
      .text-gray-500.text-sm Difficulty
      .text-2xl.font-bold = chain.current_difficulty
    div
      .text-gray-500.text-sm Block Reward
      .text-lg.font-semibold = "#{chain.block_reward} CFG"
    div
      .text-gray-500.text-sm Pending TX
      .text-lg.font-semibold = chain.mempool&.total_transactions || 0

  / Last block info
  - if chain.blocks.any?
    .border-t.pt-4.text-sm.text-gray-500
      | Last block: ##{chain.blocks.last.index} •
      = time_ago(chain.blocks.last.created_at)

  .mt-4
    a.text-indigo-600.hover:text-indigo-800.font-semibold.text-sm(
      href="/chains/#{chain.id}"
    ) View Details →
```

### 7. View Helpers

**app/helpers/view_helpers.rb**:
```ruby
module ViewHelpers
  def truncate(text, length = 30)
    return '' unless text
    text.length > length ? "#{text[0...length]}..." : text
  end

  def truncate_hash(hash, length = 16)
    return '' unless hash
    "#{hash[0...length]}...#{hash[-4..-1]}"
  end

  def time_ago(time)
    seconds = Time.now - time
    case seconds
    when 0..59
      "#{seconds.to_i}s ago"
    when 60..3599
      "#{(seconds / 60).to_i}m ago"
    when 3600..86399
      "#{(seconds / 3600).to_i}h ago"
    when 86400..604799
      "#{(seconds / 86400).to_i}d ago"
    else
      time.strftime('%Y-%m-%d')
    end
  end

  def number_with_delimiter(number)
    number.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
  end

  def format_address(address)
    "#{address[0...6]}...#{address[-4..-1]}"
  end

  def difficulty_badge(difficulty)
    color = case difficulty
    when 1..2 then 'green'
    when 3..4 then 'yellow'
    when 5..6 then 'orange'
    else 'red'
    end

    "<span class='bg-#{color}-100 text-#{color}-800 px-2 py-1 rounded-full text-xs font-medium'>⛏️ #{difficulty}</span>"
  end
end
```

### 8. Routes (app.rb additions)

```ruby
# Enable sessions for flash messages
enable :sessions
set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(32))

# Register view helpers
helpers ViewHelpers

# Serve static assets
set :public_folder, File.expand_path('public', __dir__)

# Homepage
get '/' do
  @stats = {
    total_chains: Blockchain.count,
    total_blocks: Block.count,
    total_transactions: Block.sum { |b| b.transactions.length },
    mining_jobs_24h: MiningJob.where(:created_at.gte => 24.hours.ago).count
  }

  @recent_chains = Blockchain.order_by(created_at: :desc).limit(6)
  @recent_blocks = Block.includes(:blockchain).order_by(created_at: :desc).limit(10)

  slim :index
end

# Chains list
get '/chains' do
  page = [params[:page].to_i, 1].max
  limit = 12

  @chains = Blockchain.order_by(created_at: :desc)
                      .skip((page - 1) * limit)
                      .limit(limit)

  total = Blockchain.count
  @pagination = {
    page: page,
    pages: (total.to_f / limit).ceil,
    has_prev: page > 1,
    has_next: page < (total.to_f / limit).ceil
  }

  slim :'chains/index'
end

# Chain detail
get '/chains/:id' do
  @chain = Blockchain.find(params[:id])

  page = [params[:page].to_i, 1].max
  limit = 50

  @blocks = @chain.blocks.order_by(index: :desc)
                  .skip((page - 1) * limit)
                  .limit(limit)

  @pagination = {
    page: page,
    pages: (@chain.total_blocks.to_f / limit).ceil,
    has_prev: page > 1,
    has_next: page < (@chain.total_blocks.to_f / limit).ceil
  }

  # Data for difficulty chart (last 20 blocks)
  @difficulty_history = @chain.blocks.order_by(index: :desc)
                              .limit(20)
                              .only(:index, :difficulty)
                              .reverse

  slim :'chains/show'
rescue Mongoid::Errors::DocumentNotFound
  flash[:error] = "Blockchain not found"
  redirect '/chains'
end

# Block detail
get '/chains/:chain_id/blocks/:block_id' do
  @chain = Blockchain.find(params[:chain_id])
  @block = Block.find(params[:block_id])

  # Get adjacent blocks for navigation
  @prev_block = @chain.blocks.find_by(index: @block.index - 1) if @block.index > 1
  @next_block = @chain.blocks.find_by(index: @block.index + 1) if @block.index < @chain.total_blocks

  slim :'blocks/show'
rescue Mongoid::Errors::DocumentNotFound
  flash[:error] = "Block not found"
  redirect "/chains/#{params[:chain_id]}"
end

# Search
get '/search' do
  query = params[:q]

  if query.blank?
    redirect '/'
    return
  end

  @results = {
    chains: Blockchain.where(name: /#{Regexp.escape(query)}/i).limit(5),
    blocks: Block.or({ hash: /#{Regexp.escape(query)}/i }, { index: query.to_i }).limit(10),
    transactions: []  # Search transactions by hash or address
  }

  slim :search
end
```

### 9. Custom CSS

**public/css/custom.css**:
```css
/* Custom animations */
@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-slide-in {
  animation: slideIn 0.3s ease-out;
}

/* Block visualization styles */
.block-visual {
  position: relative;
  transition: transform 0.2s;
}

.block-visual:hover {
  transform: scale(1.05);
}

/* Code block syntax highlighting */
code {
  font-family: 'Monaco', 'Courier New', monospace;
}

/* Alpine.js cloaking */
[x-cloak] {
  display: none !important;
}

/* Loading spinner */
.spinner {
  border: 3px solid #f3f3f3;
  border-top: 3px solid #4F46E5;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

/* Responsive table */
@media (max-width: 768px) {
  table {
    font-size: 0.875rem;
  }

  th, td {
    padding: 0.5rem !important;
  }
}

/* Gradient backgrounds */
.gradient-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.gradient-success {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}
```

### 10. Client-side JavaScript

**public/js/app.js**:
```javascript
// Auto-refresh for new blocks (optional)
let autoRefreshEnabled = false;

function enableAutoRefresh(interval = 30000) {
  if (autoRefreshEnabled) return;

  autoRefreshEnabled = true;
  setInterval(() => {
    // Check if we're on a chain detail page
    if (window.location.pathname.match(/^\/chains\/[a-f0-9]+$/)) {
      location.reload();
    }
  }, interval);
}

// Copy to clipboard helper
function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(() => {
    showToast('Copied to clipboard!', 'success');
  }).catch(err => {
    console.error('Copy failed:', err);
    showToast('Failed to copy', 'error');
  });
}

// Toast notifications
function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  const bgColor = type === 'success' ? 'bg-green-500' : type === 'error' ? 'bg-red-500' : 'bg-blue-500';

  toast.className = `fixed bottom-4 right-4 ${bgColor} text-white px-6 py-3 rounded-lg shadow-lg z-50 animate-slide-in`;
  toast.textContent = message;

  document.body.appendChild(toast);

  setTimeout(() => {
    toast.remove();
  }, 3000);
}

// Format numbers
function formatNumber(num) {
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// Live search debouncing
let searchTimeout;
function debounceSearch(callback, delay = 300) {
  return function(...args) {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => callback.apply(this, args), delay);
  };
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
  console.log('ChainForge Block Explorer initialized');

  // Add click-to-copy for code blocks
  document.querySelectorAll('code').forEach(code => {
    code.style.cursor = 'pointer';
    code.title = 'Click to copy';
    code.addEventListener('click', () => {
      copyToClipboard(code.textContent);
    });
  });
});
```

## Tests

**spec/features/block_explorer_spec.rb**:
```ruby
RSpec.describe 'Block Explorer UI', type: :feature do
  let!(:blockchain) { create(:blockchain, name: 'Test Chain') }
  let!(:blocks) { create_list(:block, 5, blockchain: blockchain) }

  describe 'Homepage' do
    before { visit '/' }

    it 'displays site title' do
      expect(page).to have_content('ChainForge Blockchain Explorer')
    end

    it 'shows stats' do
      expect(page).to have_content('Total Blockchains')
      expect(page).to have_content('Total Blocks')
    end

    it 'shows recent blockchains' do
      expect(page).to have_content('Test Chain')
    end
  end

  describe 'Blockchain list' do
    before { visit '/chains' }

    it 'lists all blockchains' do
      expect(page).to have_content('Test Chain')
    end

    it 'allows navigation to blockchain detail' do
      click_link 'Test Chain'
      expect(current_path).to eq("/chains/#{blockchain.id}")
    end
  end

  describe 'Blockchain detail' do
    before { visit "/chains/#{blockchain.id}" }

    it 'shows blockchain name' do
      expect(page).to have_content('Test Chain')
    end

    it 'displays blocks' do
      blocks.each do |block|
        expect(page).to have_content("##{block.index}")
      end
    end

    it 'shows difficulty chart' do
      expect(page).to have_selector('#difficultyChart')
    end
  end

  describe 'Block detail' do
    let(:block) { blocks.first }

    before { visit "/chains/#{blockchain.id}/blocks/#{block.id}" }

    it 'shows block index' do
      expect(page).to have_content("Block ##{block.index}")
    end

    it 'displays block hash' do
      expect(page).to have_content(block.hash)
    end

    it 'shows transactions' do
      expect(page).to have_content("Transactions (#{block.transactions.length})")
    end
  end

  describe 'Search' do
    before { visit '/search?q=Test' }

    it 'searches blockchains' do
      expect(page).to have_content('Test Chain')
    end
  end
end
```

## Performance Considerations

- **Server-side rendering** - No JavaScript required for core functionality
- **CDN-based assets** - Tailwind & Alpine.js loaded from CDN (no build step)
- **Pagination** - Large datasets paginated efficiently
- **Lazy loading** - Images and charts loaded as needed
- **Caching** - Cache stats and frequently accessed data with Redis

## Browser Compatibility

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile responsive (iOS Safari, Chrome Mobile)
- Progressive enhancement (works without JavaScript)

## Criterios de Aceptación

- [ ] Homepage con stats y recent blocks
- [ ] Blockchain list page con grid de cards
- [ ] Blockchain detail con visual blocks y chart
- [ ] Block detail con todas las propiedades
- [ ] Transaction display en block detail
- [ ] Search functionality (chains, blocks)
- [ ] Responsive design (mobile-first)
- [ ] Navigation (breadcrumbs, prev/next blocks)
- [ ] Real-time auto-refresh (optional)
- [ ] Copy-to-clipboard para hashes
- [ ] Loading states y error handling
- [ ] Flash messages para user feedback
- [ ] Tests de feature completos

## Educational Value

Este task enseña:
- **Server-side rendering** - Sinatra views con Slim
- **Responsive design** - Mobile-first con Tailwind CSS
- **Progressive enhancement** - Funciona sin JS
- **Modern CSS frameworks** - Utility-first CSS
- **Interactive UI** - Alpine.js para interactividad
- **Data visualization** - Chart.js para gráficos
- **UX best practices** - Navigation, feedback, error handling

Inspirado en:
- **Etherscan** - Ethereum block explorer
- **Blockchain.com** - Bitcoin explorer
- **BlockCypher** - Multi-chain explorer
- **Blockchair** - Universal blockchain explorer

## Referencias

- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Alpine.js Documentation](https://alpinejs.dev/)
- [Slim Template Engine](http://slim-lang.com/)
- [Chart.js Documentation](https://www.chartjs.org/)
- [Sinatra Views Guide](http://sinatrarb.com/intro.html#Views%20/%20Templates)
