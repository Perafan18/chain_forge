# Rate Limiting

Complete guide to understanding and working with ChainForge's rate limiting system.

## Table of Contents

1. [Overview](#overview)
2. [Rate Limits](#rate-limits)
3. [How It Works](#how-it-works)
4. [Handling Rate Limits](#handling-rate-limits)
5. [Best Practices](#best-practices)
6. [Monitoring](#monitoring)
7. [Production Considerations](#production-considerations)

## Overview

ChainForge uses **Rack::Attack** middleware to implement IP-based rate limiting. This protects the API from abuse, prevents resource exhaustion, and ensures fair usage across all clients.

**Key Features:**
- IP-based throttling (per client)
- Multiple limit tiers (global + endpoint-specific)
- 60-second rolling windows
- Automatic 429 responses when exceeded
- Disabled in test environment

## Rate Limits

### Limit Tiers

ChainForge enforces three levels of rate limits:

| Tier | Endpoint Pattern | Method | Limit | Window | Purpose |
|------|-----------------|--------|-------|--------|---------|
| **1. Global** | `/api/*` | All | 60 req | 60s | Overall API protection |
| **2. Chain Creation** | `/api/v1/chain` | POST | 10 req | 60s | Prevent blockchain spam |
| **3. Block Mining** | `/api/v1/chain/:id/block` | POST | 30 req | 60s | Prevent mining abuse |

**Note:** All limits are per IP address.

### Endpoint-Specific Limits

| Endpoint | Limit | Reason |
|----------|-------|--------|
| `POST /api/v1/chain` | 10/min | Creating blockchains is lightweight but should be limited |
| `POST /api/v1/chain/:id/block` | 30/min | Mining is CPU-intensive; prevent resource exhaustion |
| `GET /api/v1/chain/:id/block/:block_id` | Global only (60/min) | Read operations are fast |
| `POST /api/v1/chain/:id/block/:block_id/valid` | Global only (60/min) | Validation is fast |

### How Limits Stack

Clients are subject to **all applicable limits simultaneously**:

**Example 1: Creating Blockchains**
```
Request: POST /api/v1/chain

Limits Applied:
✓ Global: 60 requests/minute
✓ Chain Creation: 10 requests/minute

Effective Limit: 10/minute (whichever is reached first)
```

**Example 2: Mining Blocks**
```
Request: POST /api/v1/chain/:id/block

Limits Applied:
✓ Global: 60 requests/minute
✓ Block Mining: 30 requests/minute

Effective Limit: 30/minute (whichever is reached first)
```

**Example 3: Reading Blocks**
```
Request: GET /api/v1/chain/:id/block/:block_id

Limits Applied:
✓ Global: 60 requests/minute

Effective Limit: 60/minute
```

## How It Works

### Implementation

ChainForge uses **Rack::Attack** with in-memory storage.

**Source:** `config/rack_attack.rb`

**Middleware Configuration:**
```ruby
# main.rb:16
use Rack::Attack unless ENV['ENVIRONMENT'] == 'test'
```

### Throttle Rules

**Global Throttle:**
```ruby
throttle('api/ip', limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/api/')
end
```

**Chain Creation Throttle:**
```ruby
throttle('api/chain/create', limit: 10, period: 1.minute) do |req|
  req.ip if req.path == '/api/v1/chain' && req.post?
end
```

**Block Creation Throttle:**
```ruby
throttle('api/block/create', limit: 30, period: 1.minute) do |req|
  req.ip if req.path =~ /^\/api\/v1\/chain\/[^\/]+\/block$/ && req.post?
end
```

### IP Detection

Rack::Attack uses `request.ip` which:
- Checks `X-Forwarded-For` header (if behind proxy)
- Falls back to `REMOTE_ADDR`
- Returns the client's IP address

**For Development:**
- Localhost: `127.0.0.1` or `::1` (IPv6)
- All local requests share the same rate limit

**For Production:**
- Each client IP has independent limits
- Clients behind same NAT/proxy share limits

### Storage

**Memory-Based (Default):**
- Stores counters in Ruby process memory
- Fast lookups (no external dependencies)
- **Resets on server restart**
- **Not suitable for distributed systems**

**Production Alternative:**
- Use Redis for persistent, distributed storage
- See [Production Considerations](#production-considerations)

## Handling Rate Limits

### Response Format

When rate limit is exceeded, ChainForge returns:

**HTTP Status:** `429 Too Many Requests`

**Response Body:**
```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```

**Headers:**
```
Content-Type: application/json
```

### Client-Side Handling

#### curl Example

```bash
#!/bin/bash

response=$(curl -s -w "\n%{http_code}" -X POST http://localhost:1910/api/v1/chain)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" == "429" ]; then
  echo "Rate limited! Waiting 60 seconds..."
  sleep 60
  # Retry
  curl -X POST http://localhost:1910/api/v1/chain
else
  echo "Success: $body"
fi
```

#### Python Example

```python
import requests
import time

def create_blockchain_with_retry():
    max_retries = 3
    base_url = "http://localhost:1910/api/v1"

    for attempt in range(max_retries):
        try:
            response = requests.post(f"{base_url}/chain")

            if response.status_code == 429:
                print(f"Rate limited (attempt {attempt + 1}). Waiting 60s...")
                time.sleep(60)
                continue

            response.raise_for_status()
            return response.json()["id"]

        except requests.exceptions.HTTPError as e:
            if e.response.status_code != 429:
                raise

    raise Exception("Max retries exceeded")

# Usage
chain_id = create_blockchain_with_retry()
print(f"Blockchain created: {chain_id}")
```

#### JavaScript Example

```javascript
async function createBlockchainWithRetry() {
  const BASE_URL = "http://localhost:1910/api/v1";
  const maxRetries = 3;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const response = await fetch(`${BASE_URL}/chain`, {
      method: "POST"
    });

    if (response.status === 429) {
      console.log(`Rate limited (attempt ${attempt + 1}). Waiting 60s...`);
      await new Promise(resolve => setTimeout(resolve, 60000));
      continue;
    }

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    return data.id;
  }

  throw new Error("Max retries exceeded");
}

// Usage
createBlockchainWithRetry()
  .then(chainId => console.log("Blockchain created:", chainId))
  .catch(error => console.error("Error:", error));
```

#### Ruby Example

```ruby
require 'net/http'
require 'json'

def create_blockchain_with_retry(max_retries = 3)
  base_url = "http://localhost:1910/api/v1"
  uri = URI("#{base_url}/chain")

  max_retries.times do |attempt|
    response = Net::HTTP.post(uri, nil)

    case response.code.to_i
    when 429
      puts "Rate limited (attempt #{attempt + 1}). Waiting 60s..."
      sleep 60
      next
    when 200
      return JSON.parse(response.body)["id"]
    else
      raise "HTTP Error #{response.code}"
    end
  end

  raise "Max retries exceeded"
end

# Usage
chain_id = create_blockchain_with_retry
puts "Blockchain created: #{chain_id}"
```

## Best Practices

### 1. Implement Exponential Backoff

```python
import time

def exponential_backoff_retry(func, max_retries=5):
    """Retry with exponential backoff"""
    for attempt in range(max_retries):
        try:
            return func()
        except RateLimitError:
            if attempt == max_retries - 1:
                raise

            # Exponential backoff: 1s, 2s, 4s, 8s, 16s
            wait_time = 2 ** attempt
            print(f"Rate limited. Waiting {wait_time}s...")
            time.sleep(wait_time)
```

### 2. Batch Operations

**Bad:**
```python
# Creates 100 blockchains (will hit rate limit at 10)
for i in range(100):
    create_blockchain()  # Rate limited after 10!
```

**Good:**
```python
# Batch with delays
blockchains = []
for i in range(100):
    if i > 0 and i % 10 == 0:
        print(f"Created {i} blockchains. Waiting 60s...")
        time.sleep(60)

    blockchains.append(create_blockchain())
```

### 3. Cache Results

```python
import functools
import time

@functools.lru_cache(maxsize=128)
def get_block_cached(chain_id, block_id):
    """Cache block details to avoid repeated API calls"""
    return get_block(chain_id, block_id)

# First call: Makes API request
block1 = get_block_cached("674c...", "674d...")

# Second call: Returns cached result (no API call)
block2 = get_block_cached("674c...", "674d...")
```

### 4. Monitor Your Usage

```python
import requests

def track_rate_limits():
    """Track API usage to stay within limits"""
    call_timestamps = []

    def make_request(url, **kwargs):
        # Clean up timestamps older than 60s
        now = time.time()
        call_timestamps[:] = [ts for ts in call_timestamps if now - ts < 60]

        # Check if we're approaching limit
        if len(call_timestamps) >= 55:  # 55/60 = 91% of global limit
            print("Warning: Approaching rate limit!")
            wait_time = 60 - (now - call_timestamps[0])
            time.sleep(max(0, wait_time))

        # Make request
        response = requests.request(**kwargs)
        call_timestamps.append(time.time())

        return response

    return make_request

# Usage
api_call = track_rate_limits()
response = api_call("POST", "http://localhost:1910/api/v1/chain")
```

### 5. Use Appropriate Delays

```python
# For bulk operations, pace yourself
def create_blocks_paced(chain_id, count, delay=2):
    """Create blocks with delay to stay under rate limits"""
    blocks = []

    for i in range(count):
        block = add_block(chain_id, f"Block {i}")
        blocks.append(block)

        if i < count - 1:  # Don't delay after last block
            time.sleep(delay)

    return blocks

# Create 30 blocks in ~60 seconds (1 block every 2 seconds)
blocks = create_blocks_paced(chain_id, 30, delay=2)
```

## Monitoring

### Detecting Rate Limits

**Check HTTP Status:**
```python
response = requests.post(url)

if response.status_code == 429:
    print("Rate limit exceeded!")
    # Handle accordingly
```

**Log Rate Limit Occurrences:**
```python
import logging

logger = logging.getLogger(__name__)

def api_call_with_logging(func):
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except RateLimitError as e:
            logger.warning(f"Rate limit hit: {e}")
            raise
    return wrapper
```

### Tracking Metrics

```python
class APIMetrics:
    def __init__(self):
        self.total_requests = 0
        self.rate_limit_hits = 0
        self.successful_requests = 0

    def record_request(self, status_code):
        self.total_requests += 1

        if status_code == 429:
            self.rate_limit_hits += 1
        elif 200 <= status_code < 300:
            self.successful_requests += 1

    def print_stats(self):
        rate_limit_percentage = (
            100 * self.rate_limit_hits / self.total_requests
            if self.total_requests > 0 else 0
        )

        print(f"Total Requests: {self.total_requests}")
        print(f"Successful: {self.successful_requests}")
        print(f"Rate Limited: {self.rate_limit_hits} ({rate_limit_percentage:.1f}%)")

# Usage
metrics = APIMetrics()

for i in range(100):
    response = make_api_call()
    metrics.record_request(response.status_code)

metrics.print_stats()
```

## Production Considerations

### Limitations of Current Implementation

**In-Memory Storage:**
- ❌ Resets on server restart
- ❌ Not shared across multiple servers
- ❌ No persistence
- ❌ No historical data

**Single-Server Only:**
- Each server instance has independent counters
- Load-balanced deployments won't enforce limits correctly
- Users can bypass limits by targeting different servers

### Production Recommendations

#### 1. Use Redis for Distributed Rate Limiting

```ruby
# Gemfile
gem 'redis'
gem 'redis-rack-attack'

# config/rack_attack.rb
require 'redis'

Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(
  Redis.new(url: ENV['REDIS_URL'])
)

# Same throttle rules as before
throttle('api/ip', limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/api/')
end
```

**Benefits:**
- ✅ Persistent across restarts
- ✅ Shared across multiple servers
- ✅ Faster than database storage
- ✅ TTL support built-in

#### 2. Implement IP Whitelisting

```ruby
# config/rack_attack.rb
Rack::Attack.safelist('allow from localhost') do |req|
  '127.0.0.1' == req.ip || '::1' == req.ip
end

Rack::Attack.safelist('allow trusted IPs') do |req|
  # Allow specific IPs (monitoring, trusted clients)
  %w[192.168.1.100 10.0.0.50].include?(req.ip)
end
```

#### 3. Add Permanent Bans

```ruby
# config/rack_attack.rb
Rack::Attack.blocklist('block bad actors') do |req|
  # Block specific IPs permanently
  BLOCKED_IPS.include?(req.ip)
end

# Ban IPs after too many violations
Rack::Attack.blocklist('ban repeat offenders') do |req|
  Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 1.hour, bantime: 24.hours) do
    # Track requests that hit rate limits
    req.env['rack.attack.throttle_data']['api/ip'][:count] >= 60
  end
end
```

#### 4. Add Monitoring and Alerts

```ruby
# config/initializers/rack_attack.rb
ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |name, start, finish, request_id, payload|
  req = payload[:request]

  # Log to monitoring service
  logger.warn({
    message: 'Rate limit exceeded',
    ip: req.ip,
    path: req.path,
    matched: payload[:matched]
  })

  # Send alert if threshold exceeded
  if redis.incr("rate_limit_violations:#{req.ip}") > 100
    AlertService.notify("High rate limit violations from #{req.ip}")
  end
end
```

#### 5. Implement API Keys

```ruby
# For production, use API keys instead of IP-based limiting
throttle('api/key', limit: 1000, period: 1.hour) do |req|
  # Extract API key from header
  api_key = req.env['HTTP_X_API_KEY']

  # Return key for throttling (nil bypasses throttle)
  api_key if req.path.start_with?('/api/')
end
```

### Response Headers

Add rate limit info to responses:

```ruby
# config/rack_attack.rb
Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data']
  now = Time.now.to_i

  headers = {
    'Content-Type' => 'application/json',
    'X-RateLimit-Limit' => match_data[:limit].to_s,
    'X-RateLimit-Remaining' => '0',
    'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s
  }

  [429, headers, [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]]
end
```

**Example Response:**
```
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1699565400
Content-Type: application/json

{"error":"Rate limit exceeded. Please try again later."}
```

## Testing

### Disabled in Test Environment

```ruby
# main.rb:16
use Rack::Attack unless ENV['ENVIRONMENT'] == 'test'
```

**Why?**
- Tests run faster without rate limiting delays
- Predictable test execution
- No flaky tests from rate limit state

### Testing Rate Limits

```ruby
# spec/api_spec.rb
context 'rate limiting' do
  before do
    # Temporarily enable Rack::Attack for this test
    allow(ENV).to receive(:[]).with('ENVIRONMENT').and_return('development')
  end

  it 'enforces global rate limit' do
    61.times { post '/api/v1/chain' }
    expect(last_response.status).to eq(429)
  end

  it 'enforces chain creation limit' do
    11.times { post '/api/v1/chain' }
    expect(last_response.status).to eq(429)
  end
end
```

## Next Steps

- [API Reference](reference.md) - Complete endpoint documentation
- [API Examples](examples.md) - Integration examples with retry logic
- [Security Design](../architecture/security-design.md) - Security architecture

---

**Questions about rate limits?** Open an issue on GitHub or see [CONTRIBUTING](../CONTRIBUTING.md).
