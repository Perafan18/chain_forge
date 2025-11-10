### ChainForge — Dev Guidelines (verified 2025-11-09 22:57 local)

These notes capture project-specific setup, testing, and dev practices validated on a clean environment with Docker-provided MongoDB.

#### Tech stack
- Ruby 3.2.2 (Bundler 2.4.13)
- Sinatra 4.x, Mongoid 7.0.x, MongoDB
- RSpec, SimpleCov, RuboCop (+ rubocop-rspec)
- dotenv for env loading; Rack::Attack middleware (disabled in test)

---

### Build & Configuration

- Install deps (verified):
  ```bash
  gem install bundler -v 2.4.13
  bundle install
  ```

- Required env vars (used by `config/mongoid.yml`):
  - `ENVIRONMENT` — `development` or `test`. Defaults: app → `development`; specs set `test` in `spec/spec_helper.rb`.
  - `MONGO_DB_NAME` — DB name (e.g., `chain_forge_dev`, `chain_forge_test`).
  - `MONGO_DB_HOST` — Mongo host (e.g., `127.0.0.1` or `db` inside compose).
  - `MONGO_DB_PORT` — Mongo port (e.g., `27017`).

- Mongoid loading points:
  - App: `Mongoid.load!("./config/mongoid.yml", ENV['ENVIRONMENT'] || :development)` in `main.rb`.
  - Specs: `Mongoid.load!("./config/mongoid.yml", :test)` in `spec/spec_helper.rb` (and `ENV['ENVIRONMENT']='test'`).

- Docker (recommended for a clean Mongo):
  ```bash
  docker-compose up -d
  # Exposes app on :1910 and Mongo on :27017
  ```
  - Service names: `app`, `db`. The app uses `ruby main.rb -p 1910` per `Dockerfile`.

- Run app locally (outside Docker):
  ```bash
  ENVIRONMENT=development \
  MONGO_DB_NAME=chain_forge_dev \
  MONGO_DB_HOST=127.0.0.1 \
  MONGO_DB_PORT=27017 \
  bundle exec ruby main.rb -p 1910
  ```
  - Note: `before` block in `main.rb` sets `content_type :json` for POSTs; the root route sets `:html` explicitly.
  - Rack::Attack is enabled except when `ENVIRONMENT=test`.

---

### Testing

- Verified baseline (unit-level specs only):
  ```bash
  ENVIRONMENT=test \
  MONGO_DB_NAME=chain_forge_test \
  MONGO_DB_HOST=127.0.0.1 \
  MONGO_DB_PORT=27017 \
  bundle exec rspec spec/block_spec.rb spec/blockchain_spec.rb
  ```
  Result observed: 10 examples, 0 failures.

- Full suite:
  ```bash
  ENVIRONMENT=test MONGO_DB_NAME=chain_forge_test MONGO_DB_HOST=127.0.0.1 MONGO_DB_PORT=27017 \
  bundle exec rspec
  ```
  Note: API specs (`spec/api_spec.rb`) may be sensitive to content-type behavior or rack/test mounting. The app sets JSON content-type for POSTs globally and again in the `/api/v1` namespace, which generally aligns with expectations.

- Focused runs and filters:
  - Single file: `bundle exec rspec spec/block_spec.rb`
  - Single example: `bundle exec rspec spec/block_spec.rb:37`
  - By name: `bundle exec rspec -e 'validates the blockchain'`

- Adding a new spec (workflow verified end-to-end):
  1) Create a file, e.g. `spec/demo_math_spec.rb`:
     ```ruby
     # frozen_string_literal: true
     require 'rspec'

     RSpec.describe 'Math demo' do
       it 'adds numbers' do
         expect(1 + 1).to eq(2)
       end
     end
     ```
  2) Run it:
     ```bash
     ENVIRONMENT=test MONGO_DB_NAME=chain_forge_test MONGO_DB_HOST=127.0.0.1 MONGO_DB_PORT=27017 \
     bundle exec rspec spec/demo_math_spec.rb
     ```
     Expected: 1 example, 0 failures (observed).
  3) Remove the file when done:
     ```bash
     rm spec/demo_math_spec.rb
     ```

- Coverage:
  ```bash
  COVERAGE=true ENVIRONMENT=test MONGO_DB_NAME=chain_forge_test MONGO_DB_HOST=127.0.0.1 MONGO_DB_PORT=27017 \
  bundle exec rspec
  # Report: coverage/index.html
  ```
  - `spec/spec_helper.rb` preloads SimpleCov when `COVERAGE` is set and applies filters/groups; minimum coverage is set to 80%.

- Test data & MongoDB:
  - Specs persist via Mongoid; use a dedicated test DB (`MONGO_DB_NAME=chain_forge_test`).
  - No cleaning strategy is configured. For isolation across runs, consider dropping the test DB between runs or adding `database_cleaner-mongoid`.

- Running tests inside container (optional):
  ```bash
  docker-compose exec app bash
  # inside container
  ENVIRONMENT=test MONGO_DB_NAME=chain_forge_test MONGO_DB_HOST=db MONGO_DB_PORT=27017 bundle exec rspec
  ```

---

### Code & Project Notes

- Structure:
  - `src/block.rb` — `Block` model with SHA256 hashing, PoW attributes (`nonce`, `difficulty`), and `valid_data?`.
  - `src/blockchain.rb` — Chain aggregate; `add_genesis_block`, `add_block`, `last_block`, `integrity_valid?`.
  - `main.rb` — Sinatra app; routes:
    - `GET /` — hello text (HTML content-type).
    - `POST /api/v1/chain` — creates a chain.
    - `POST /api/v1/chain/:id/block` — validates payload via `BlockDataContract` and mines a block.
    - `POST /api/v1/chain/:id/block/:block_id/valid` — validates provided data against stored block.
    - `GET /api/v1/chain/:id/block/:block_id` — returns block details including `valid_hash` and mining metadata.
  - `src/validators.rb` — Dry-validation contracts (e.g., `BlockDataContract`).
  - `config/mongoid.yml` — uses only `MONGO_DB_*` envs; no auth block.
  - `config/rack_attack.rb` — Rack::Attack throttling; disabled when `ENVIRONMENT=test`.

- API behavior specifics:
  - `before` in app namespace sets `content_type :json` for API routes; POSTs also get JSON via global `before`. If rack/test expectations change, ensure tests mount `Sinatra::Application` and set `CONTENT_TYPE` for JSON posts (as in specs).

- Linting:
  ```bash
  bundle exec rubocop
  ```
  - Target Ruby: 3.2; spec/config dirs are relaxed on Metrics.

- Debugging tips:
  - Time-sensitive assertions use `created_at.to_i` in hashing; compare against integer timestamps to avoid flakiness.
  - Quick IRB with models loaded:
    ```bash
    ENVIRONMENT=development MONGO_DB_NAME=chain_forge_dev MONGO_DB_HOST=127.0.0.1 MONGO_DB_PORT=27017 \
    bundle exec irb -r ./src/blockchain -r ./src/block
    ```

- Troubleshooting:
  - Connection refused on Mongo: ensure `docker-compose up -d` is running or that `MONGO_DB_HOST/PORT` are correct.
  - Content-Type mismatches in API tests: check the global/namespace `content_type :json` and `CONTENT_TYPE` header in requests.
  - Rack::Attack blocks: ensure `ENVIRONMENT=test` for specs; middleware disabled in that env.
