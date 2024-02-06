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
ruby app.rb -p 1910
```

## API

### POST /chain

```bash
curl -X POST http://localhost:1910/chain
```

### POST /chain/:chain_id/block

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"data": "your_data"}' http://localhost:1910/chain/65c196450bb5f7a56774438e/block
```

### POST /chain/:chain_id/block/:block_id/valid

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"data": "your_data"}' http://localhost:1910/chain/65c196450bb5f7a56774438e/block/65c19ca00bb5f7a928578c83/valid
```
