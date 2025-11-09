# ChainForge — Development Guidelines

This document captures project-specific practices for building, testing, and extending ChainForge. It assumes an advanced Ruby developer familiar with Bundler, RSpec, Docker, and MongoDB.

## Build and Configuration

- Ruby: 3.2.2 (see `Gemfile` and `Dockerfile`).
- App stack: Sinatra 4.x, Mongoid 7.0.x, MongoDB.
- Environment configuration is consumed via `dotenv` and `Mongoid`:
  - `Mongoid.load!('./config/mongoid.yml', ENV['ENVIRONMENT'] || :development)` in `main.rb`
  - `Mongoid.load!('./config/mongoid.yml', ENV['ENVIRONMENT'] || :test)` in `spec/spec_helper.rb`
- Required ENV (both development and test environments):
  - `ENVIRONMENT` — one of `development` or `test` (symbol allowed by Mongoid). Defaults to `development` in app, `test` in specs when unset.
  - `MONGO_DB_NAME` — database name (e.g., `chain_forge_dev` or `chain_forge_test`).
  - `MONGO_DB_HOST` — MongoDB host (e.g., `127.0.0.1`).
  - `MONGO_DB_PORT` — MongoDB port (e.g., `27017`).
- Mongoid config (`config/mongoid.yml`) uses only these ENV variables (no auth block). Ensure the vars are set or use Docker.

### Installing dependencies

```bash
# Ruby 3.2.2 assumed
gem install bundler -v 2.4.13
bundle install
```

### Running via Docker (recommended for a clean Mongo)

```bash
docker-compose up -d
# Exposes app on :1910 and mongo on :27017 by default
```

### Running app locally

```bash
# Ensure MongoDB is reachable at MONGO_DB_HOST:MONGO_DB_PORT and DB exists/auto-creates
ENVIRONMENT=development \
MONGO_DB_NAME=chain_forge_dev \
MONGO_DB_HOST=127.0.0.1 \
MONGO_DB_PORT=27017 \
bundle exec ruby main.rb -p 1910
```

## Testing

RSpec is configured in `spec/spec_helper.rb` and loads Mongoid in `:test` unless `ENVIRONMENT` overrides.

### Baseline run (verified)

The following has been verified to pass for unit-level specs on a fresh run with MongoDB available (e.g., via `docker-compose up -d`):

```bash
ENVIRONMENT=test \
MONGO_DB_NAME=chain_forge_test \
MONGO_DB_HOST=127.0.0.1 \
MONGO_DB_PORT=27017 \
bundle exec rspec spec/block_spec.rb spec/blockchain_spec.rb
```

Notes:
- The full suite currently includes API specs that may fail depending on content-type behavior and rack/test expectations. If you want green runs while iterating on models, scope to the unit specs above or filter via `-e/--example` or `--pattern`.
- Full-suite run example (may include failing API specs today):

```bash
ENVIRONMENT=test MONGO_DB_NAME=chain_forge_test MONGO_DB_HOST=127.0.0.1 MONGO_DB_PORT=27017 \
bundle exec rspec
```

### Focused runs and filters

- Single file: `bundle exec rspec spec/block_spec.rb`
- Single example: `bundle exec rspec spec/block_spec.rb:37`
- By example name: `bundle exec rspec -e 'validates the blockchain'`

### Coverage

SimpleCov is available (loaded on demand). To enable coverage, set an env var before running:

```bash
COVERAGE=true ENVIRONMENT=test MONGO_DB_NAME=chain_forge_test MONGO_DB_HOST=127.0.0.1 MONGO_DB_PORT=27017 \
bundle exec rspec
# Coverage report will be in coverage/index.html
```

### Adding a new spec (demonstrated workflow)

The following process was executed and verified end-to-end; replicate as needed:

1. Create a new spec file under `spec/`, e.g. `spec/demo_math_spec.rb`:
   ```ruby
   # frozen_string_literal: true
   require 'rspec'

   RSpec.describe 'Math demo' do
     it 'adds numbers' do
       expect(1 + 1).to eq(2)
     end
   end
   ```
2. Run just that spec:
   ```bash
   ENVIRONMENT=test MONGO_DB_NAME=chain_forge_test MONGO_DB_HOST=127.0.0.1 MONGO_DB_PORT=27017 \
   bundle exec rspec spec/demo_math_spec.rb
   ```
   Expected: 1 example, 0 failures.
3. Remove the file once done (to keep repo clean):
   ```bash
   rm spec/demo_math_spec.rb
   ```

### Test data and MongoDB

- Specs create and persist documents via Mongoid (e.g., `Block`, `Blockchain`). Use a dedicated `MONGO_DB_NAME` for tests to avoid polluting dev data.
- No cleaning strategy is configured. If isolation becomes necessary, consider adding `database_cleaner-mongoid` or dropping the test DB between runs.

## Additional Development Notes

### API behavior

- `main.rb` sets `content_type :json` for POST requests in a `before` block. If API specs expect more strict headers (e.g., `application/json` vs `text/html`), ensure routes are executed in the same Rack env as tests (Sinatra + rack-test). If content-type mismatches persist, review middleware or how tests mount the app.

### Code style and linting

- RuboCop with `rubocop-rspec` is configured in `.rubocop.yml`.
  - Target Ruby: 3.2
  - Selected Metrics/Style cops are tuned; specs and config directories are largely excluded from method/ block length checks.
- Run lint:
  ```bash
  bundle exec rubocop
  ```

### Project structure

- Core domain:
  - `src/block.rb` — `Block` model with SHA256 hashing and `valid_data?` verification.
  - `src/blockchain.rb` — `Blockchain` aggregate with `add_genesis_block`, `add_block`, `integrity_valid?`.
- App entrypoint: `main.rb` (Sinatra routes for creating chains, adding blocks, validating block data).
- Tests: `spec/` directory with unit specs for `Block` and `Blockchain`, and API specs.

### Debugging tips

- Use focused RSpec runs (`-e`, `:line_number`).
- Inspect Mongo documents in a console by starting `irb` with the same environment:
  ```bash
  ENVIRONMENT=development MONGO_DB_NAME=chain_forge_dev MONGO_DB_HOST=127.0.0.1 MONGO_DB_PORT=27017 \
  bundle exec irb -r ./src/blockchain -r ./src/block
  ```
- When debugging hashing/time-sensitive assertions, compare against `created_at.to_i` (used in hash calculation).

### Docker notes

- The provided `docker-compose.yml` spins up `app` and `db`. The `app` container runs `ruby main.rb -p 1910` per `Dockerfile` CMD. For test runs, it’s simpler to run RSpec on the host and use the `db` service for Mongo.
- If you want to run tests inside the container, `docker-compose exec app bash` then run the same `ENVIRONMENT=test` commands with `MONGO_DB_HOST=db`.

---

This document reflects commands verified on 2025-11-08 23:58 local time. Keep it updated as the test suite and APIs evolve.