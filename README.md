# ChainForge

## Setup

### Install ruby 3.2.2

```bash
rbenv install 3.2.2
rbenv local 3.2.2
```

### Install dependencies

```bash
bundle install
```

## Test

```bash
bundle exec rspec
```

## Usage

```bash
ruby main.rb -p 1910
```

## API

### POST /chain

```bash
curl -X POST http://localhost:1910/chain
```

### POST /chain/:chain_id/block

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"data": "your_data"}' http://localhost:1910/chain/:chain_id/block
```

### POST /chain/:chain_id/block/:block_id/valid

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"data": "your_data"}' http://localhost:1910/chain/:chain_id/block/:block_id/valid
```
