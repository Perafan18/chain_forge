# Security Design

Comprehensive analysis of ChainForge's security architecture, threat model, and protection mechanisms.

## Table of Contents

1. [Security Overview](#security-overview)
2. [Threat Model](#threat-model)
3. [Security Layers](#security-layers)
4. [Rate Limiting](#rate-limiting)
5. [Input Validation](#input-validation)
6. [Cryptographic Security](#cryptographic-security)
7. [Known Vulnerabilities](#known-vulnerabilities)
8. [Security Best Practices](#security-best-practices)
9. [Production Security](#production-security)

## Security Overview

ChainForge implements **multiple layers of security** appropriate for an educational blockchain project:

```
┌────────────────────────────────────────┐
│  Layer 5: Application Logic Security  │ ← Chain integrity validation
├────────────────────────────────────────┤
│  Layer 4: Cryptographic Security      │ ← SHA256 hashing, PoW
├────────────────────────────────────────┤
│  Layer 3: Input Validation            │ ← dry-validation schemas
├────────────────────────────────────────┤
│  Layer 2: Rate Limiting                │ ← Rack::Attack throttling
├────────────────────────────────────────┤
│  Layer 1: Transport Security           │ ← HTTP (HTTPS in production)
└────────────────────────────────────────┘
```

**Security Philosophy:**
- **Defense in Depth**: Multiple independent layers
- **Fail Securely**: Invalid requests rejected early
- **Educational Focus**: Balance security with simplicity
- **Not Production-Ready**: Missing auth, encryption, monitoring

## Threat Model

### Assets to Protect

1. **Blockchain Data Integrity**
   - Stored block data
   - Hash linkages
   - Proof of Work validations

2. **System Availability**
   - API responsiveness
   - Database resources
   - CPU/memory resources

3. **Data Consistency**
   - Chain integrity
   - Block ordering
   - Hash validity

### Threat Actors

#### 1. Malicious API User

**Capabilities:**
- Send HTTP requests to public API
- Provide arbitrary input data
- Attempt to bypass validation

**Goals:**
- Corrupt blockchain data
- Cause denial of service
- Inject malicious content

**Mitigations:**
- Rate limiting (Rack::Attack)
- Input validation (dry-validation)
- PoW requirement for block creation

#### 2. Internal Attacker (Database Access)

**Capabilities:**
- Direct MongoDB access
- Modify documents directly
- Bypass application logic

**Goals:**
- Alter historical blocks
- Invalidate chain integrity
- Corrupt genesis blocks

**Mitigations:**
- Chain integrity validation
- Hash verification
- PoW validation
- **Not mitigated:** Database access controls (educational project)

#### 3. Network Attacker

**Capabilities:**
- Intercept traffic (if HTTP)
- Man-in-the-middle attacks
- Eavesdrop on communications

**Goals:**
- Read sensitive data
- Modify requests/responses
- Impersonate users

**Mitigations (in production):**
- HTTPS/TLS encryption
- Certificate validation
- **Not mitigated in development:** HTTP only

### Out of Scope Threats

ChainForge is educational and doesn't protect against:

- ❌ **Distributed Attacks**: No P2P network
- ❌ **51% Attack**: Single server (not applicable)
- ❌ **Economic Attacks**: No financial incentives
- ❌ **Social Engineering**: No user accounts
- ❌ **Physical Security**: Development environment
- ❌ **Advanced Persistent Threats**: Not a high-value target

## Security Layers

### Layer 1: Transport Security

**Current State:** HTTP (unencrypted)

**Risks:**
- Eavesdropping on API requests/responses
- Man-in-the-middle attacks
- Data tampering in transit

**Mitigation (Development):**
- Run on localhost only
- Use private networks
- Document HTTP-only limitation

**Mitigation (Production):**
- Deploy with HTTPS/TLS
- Use valid SSL certificates
- Enforce HTTPS redirects
- Enable HSTS headers

### Layer 2: Rate Limiting

See [Rate Limiting](#rate-limiting) section below.

### Layer 3: Input Validation

See [Input Validation](#input-validation) section below.

### Layer 4: Cryptographic Security

See [Cryptographic Security](#cryptographic-security) section below.

### Layer 5: Application Logic Security

**Chain Integrity Validation:**

Before adding blocks, ChainForge validates the entire chain:

```ruby
# src/blockchain.rb:22-23
def add_block(data, difficulty: 2)
  integrity_valid? or raise 'Blockchain is not valid'
  # ... rest of method
end
```

**Validation Checks:**

```ruby
# src/blockchain.rb:47-53
def integrity_valid?
  blocks.each_cons(2).all? do |previous_block, current_block|
    # Check 1: Hash linkage
    previous_block._hash == current_block.previous_hash &&

    # Check 2: Data integrity
    current_block._hash == current_block.calculate_hash &&

    # Check 3: Proof of Work
    current_block.valid_hash?
  end
end
```

**Security Properties:**
- Detects tampered blocks immediately
- Prevents adding blocks to corrupted chains
- Validates PoW requirements
- O(n) complexity (scales with chain length)

## Rate Limiting

### Implementation: Rack::Attack

ChainForge uses **Rack::Attack** middleware for IP-based rate limiting.

**Source:** `config/rack_attack.rb`

### Configuration

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

### Rate Limits Table

| Endpoint Pattern | Method | Limit | Window | Purpose |
|-----------------|--------|-------|--------|---------|
| `/api/*` | All | 60 req | 1 min | Global protection |
| `/api/v1/chain` | POST | 10 req | 1 min | Prevent blockchain spam |
| `/api/v1/chain/:id/block` | POST | 30 req | 1 min | Prevent mining abuse |
| Other endpoints | All | Global only | - | Read operations |

### Custom Response

When rate limit exceeded:

```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```

**HTTP Status:** 429 (Too Many Requests)

**Implementation:**
```ruby
# config/rack_attack.rb
Rack::Attack.throttled_responder = lambda do |_request|
  [429, { 'Content-Type' => 'application/json' }, [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]]
end
```

### Security Analysis

**Strengths:**
- ✅ Prevents brute-force attacks
- ✅ Mitigates DoS attempts
- ✅ Protects expensive operations (mining)
- ✅ Per-IP granularity

**Weaknesses:**
- ❌ Memory-based (resets on restart)
- ❌ Single-server only (not distributed)
- ❌ Bypassable with IP rotation
- ❌ No persistent ban list
- ❌ Doesn't track across proxies

**Production Improvements:**
- Use Redis for distributed rate limiting
- Implement permanent bans for abuse
- Add CAPTCHA for suspicious IPs
- Monitor and alert on violations
- Consider API keys for accountability

### Disabled in Tests

```ruby
# main.rb:16
use Rack::Attack unless ENV['ENVIRONMENT'] == 'test'
```

**Reason:** Test suite needs to run without delays

## Input Validation

### Implementation: dry-validation

ChainForge uses **dry-validation** for schema-based input validation.

**Source:** `src/validators.rb`

### BlockDataContract

```ruby
class BlockDataContract < Dry::Validation::Contract
  params do
    required(:data).filled(:string)
    optional(:difficulty).filled(:integer, gteq?: 1, lteq?: 10)
  end
end
```

**Rules:**
1. `data`: **Required**, must be filled (non-empty) string
2. `difficulty`: **Optional**, if present must be integer 1-10

### Validation Flow

```
1. Client Request
   POST /api/v1/chain/:id/block
   Body: {"data": "test", "difficulty": 15}
   ↓
2. Parse JSON
   parse_json_body
   ↓
3. Validate Schema
   BlockDataContract.new.call(block_data)
   ↓
4. Check Result
   validation.failure?  # true (difficulty > 10)
   ↓
5. Return Errors
   halt 400, {"errors": {"difficulty": ["must be between 1 and 10"]}}
```

### Error Response Format

**Valid Request:**
```bash
curl -X POST http://localhost:1910/api/v1/chain/:id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "test", "difficulty": 3}'
```

Response: 200 OK (proceeds to mining)

**Invalid: Missing data:**
```bash
curl -X POST http://localhost:1910/api/v1/chain/:id/block \
  -H 'Content-Type: application/json' \
  -d '{"difficulty": 3}'
```

Response: 400 Bad Request
```json
{
  "errors": {
    "data": ["must be filled"]
  }
}
```

**Invalid: Out-of-range difficulty:**
```bash
curl -X POST http://localhost:1910/api/v1/chain/:id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "test", "difficulty": 15}'
```

Response: 400 Bad Request
```json
{
  "errors": {
    "difficulty": ["must be between 1 and 10"]
  }
}
```

**Invalid: Wrong type:**
```bash
curl -X POST http://localhost:1910/api/v1/chain/:id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "test", "difficulty": "high"}'
```

Response: 400 Bad Request
```json
{
  "errors": {
    "difficulty": ["must be an integer"]
  }
}
```

### Security Benefits

**Prevents:**
- ✅ Type confusion attacks
- ✅ NoSQL injection
- ✅ Resource exhaustion (difficulty > 10)
- ✅ Empty data blocks
- ✅ Malformed requests

**Provides:**
- ✅ Clear error messages
- ✅ Schema documentation
- ✅ Type safety
- ✅ Range enforcement

## Cryptographic Security

### SHA256 Hashing

**Algorithm:** SHA-256 (Secure Hash Algorithm 256-bit)

**Properties:**
- **Pre-image Resistance**: Can't find input from hash
- **Collision Resistance**: Virtually impossible to find two inputs with same hash
- **Avalanche Effect**: Small input change = completely different hash
- **Deterministic**: Same input always produces same output

**Usage in ChainForge:**

```ruby
# src/block.rb:45
Digest::SHA256.hexdigest("#{index}#{created_at.to_i}#{data}#{previous_hash}#{nonce}")
```

**Security Analysis:**

| Threat | SHA256 Mitigation |
|--------|------------------|
| Data tampering | Hash changes if data modified |
| Block forgery | Can't create valid hash without PoW |
| Chain corruption | Invalid hashes detected immediately |
| Collision attacks | Computationally infeasible (2^128 attempts) |
| Rainbow tables | Not applicable (unique inputs per block) |

**Known Weaknesses:**
- Quantum computing threat (future, theoretical)
- SHA1 is broken, but SHA256 still secure
- Length-extension attacks (not applicable to ChainForge)

### Proof of Work

**Security Purpose:** Computational cost to modify blockchain

**Difficulty Levels:**

| Difficulty | Avg Attempts | CPU Time | Security Level |
|-----------|-------------|----------|---------------|
| 1-2 | 16-256 | < 1s | Low (educational) |
| 3-4 | 4K-65K | Seconds | Medium (demonstration) |
| 5-6 | 1M-16M | Minutes | High (testing) |
| 7-10 | 268M+ | Hours+ | Very High (impractical) |

**Attack Scenario:**

Attacker wants to change Block 5 in a 10-block chain (difficulty 3):

```
Required Work:
- Re-mine Block 5: ~4,096 attempts
- Re-mine Block 6: ~4,096 attempts
- Re-mine Block 7: ~4,096 attempts
- Re-mine Block 8: ~4,096 attempts
- Re-mine Block 9: ~4,096 attempts
- Re-mine Block 10: ~4,096 attempts

Total: ~24,576 attempts (~10-15 seconds)
```

**Comparison with Bitcoin:**

```
Bitcoin (Difficulty ~19 leading zeros):
- Attack Block 5 in 10-block chain
- Each block: ~2^76 attempts (astronomical)
- Time: Years on supercomputers
- Cost: Millions of dollars in electricity
```

**Security Trade-off:**
- ChainForge: Educational (low difficulty acceptable)
- Production: Needs much higher difficulty + distributed consensus

## Known Vulnerabilities

ChainForge is an **educational project** and has known security limitations:

### 1. No Authentication/Authorization

**Vulnerability:**
- Any user can create blockchains
- Any user can add blocks to any chain
- No user accounts or permissions

**Risk:** Medium (for educational project)

**Mitigation:**
- Document as limitation
- Add authentication for production

**Example Attack:**
```bash
# Attacker can spam blockchains
for i in {1..100}; do
  curl -X POST http://localhost:1910/api/v1/chain
done
```

### 2. No Data Encryption at Rest

**Vulnerability:**
- MongoDB stores data in plaintext
- No field-level encryption
- Database backups are unencrypted

**Risk:** Low (for educational project with non-sensitive data)

**Mitigation:**
- MongoDB Enterprise supports encryption at rest
- Application-level encryption for sensitive fields
- Encrypt database backups

### 3. HTTP Only (No HTTPS)

**Vulnerability:**
- Traffic unencrypted in transit
- Man-in-the-middle attacks possible
- Credentials exposed (if auth added)

**Risk:** High (if deployed publicly)

**Mitigation:**
- Run on localhost only (development)
- Deploy with HTTPS (production)
- Use reverse proxy (nginx, Cloudflare)

### 4. In-Memory Rate Limiting

**Vulnerability:**
- Rate limits reset on restart
- No persistence of violations
- Single-server only

**Risk:** Medium (DoS protection incomplete)

**Mitigation:**
- Use Redis for distributed rate limiting
- Persist violation logs
- Implement IP banning

### 5. No Input Sanitization for Output

**Vulnerability:**
- Stored data returned as-is in JSON
- Potential for stored XSS (if data rendered in HTML)
- No content security policy

**Risk:** Low (JSON API, not HTML)

**Mitigation:**
- Sanitize/encode when rendering in HTML
- Implement Content Security Policy headers
- Validate on output, not just input

### 6. Difficulty Limit (Max 10)

**Vulnerability:**
- Low difficulty easy to brute-force
- Re-mining entire chain feasible

**Risk:** Low (educational project)

**Mitigation:**
- Increase max difficulty for production
- Implement dynamic difficulty adjustment
- Add distributed consensus

### 7. No Database Access Controls

**Vulnerability:**
- MongoDB typically runs without authentication (dev)
- Direct database access bypasses application logic
- No audit logging

**Risk:** High (if MongoDB exposed)

**Mitigation:**
- Enable MongoDB authentication
- Restrict network access (firewall)
- Implement audit logging
- Use connection string with credentials

### 8. No Request Signing

**Vulnerability:**
- Requests not cryptographically signed
- Cannot verify request origin
- Replay attacks possible

**Risk:** Medium (if authentication added)

**Mitigation:**
- Implement HMAC request signing
- Use nonces to prevent replay
- Add timestamps to requests

## Security Best Practices

### For Development

1. **Run Locally:**
   ```bash
   # Bind to localhost only
   ruby main.rb -p 1910 -o 127.0.0.1
   ```

2. **Use Firewall:**
   ```bash
   # Block external access to port 1910
   sudo ufw deny 1910/tcp
   sudo ufw allow from 127.0.0.1 to any port 1910
   ```

3. **Secure MongoDB:**
   ```bash
   # Enable auth in mongod.conf
   security:
     authorization: enabled
   ```

4. **Monitor Logs:**
   ```bash
   # Watch for suspicious activity
   tail -f logs/development.log | grep -i "error\|attack"
   ```

### For Testing

1. **Use Separate Database:**
   ```bash
   # .env.test
   MONGO_DB_NAME=chain_forge_test
   ENVIRONMENT=test
   ```

2. **Clean Up After Tests:**
   ```ruby
   # spec/spec_helper.rb
   config.after(:each) do
     Mongoid.purge!
   end
   ```

3. **Test Security Features:**
   ```ruby
   # Test rate limiting
   it 'enforces rate limits' do
     11.times { post '/api/v1/chain' }
     expect(last_response.status).to eq(429)
   end

   # Test input validation
   it 'rejects invalid difficulty' do
     post '/api/v1/chain/:id/block', {data: "test", difficulty: 15}.to_json
     expect(last_response.status).to eq(400)
   end
   ```

## Production Security

For production deployment, implement these additional security measures:

### 1. HTTPS/TLS

```ruby
# Use production server with SSL
# config.ru
require 'rack/ssl'
use Rack::SSL
```

### 2. Authentication

```ruby
# Add JWT authentication
require 'jwt'

before do
  authenticate_user! unless public_endpoint?
end

def authenticate_user!
  token = request.env['HTTP_AUTHORIZATION']&.split(' ')&.last
  payload = JWT.decode(token, ENV['JWT_SECRET'], true, algorithm: 'HS256')
  @current_user = User.find(payload['user_id'])
rescue JWT::DecodeError
  halt 401, {error: 'Unauthorized'}.to_json
end
```

### 3. Database Security

```yaml
# config/mongoid.yml production
production:
  clients:
    default:
      uri: <%= ENV['MONGODB_URI'] %>  # mongodb://user:pass@host:27017/db
      options:
        ssl: true
        ssl_verify: true
```

### 4. Rate Limiting with Redis

```ruby
# config/rack_attack.rb
Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(
  Redis.new(url: ENV['REDIS_URL'])
)
```

### 5. Security Headers

```ruby
# Add security headers
use Rack::Protection
use Rack::Protection::JsonCsrf

before do
  headers['X-Frame-Options'] = 'DENY'
  headers['X-Content-Type-Options'] = 'nosniff'
  headers['X-XSS-Protection'] = '1; mode=block'
  headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
end
```

### 6. Logging & Monitoring

```ruby
# Add request logging
require 'logger'
use Rack::CommonLogger, Logger.new('log/production.log')

# Log security events
logger.warn "Rate limit exceeded for IP: #{request.ip}"
logger.error "Invalid authentication attempt from: #{request.ip}"
```

### 7. Input Sanitization

```ruby
# Sanitize data before storage
require 'sanitize'

def sanitize_input(data)
  Sanitize.clean(data, Sanitize::Config::RESTRICTED)
end
```

### 8. Environment Variables

```bash
# Use secrets management
# .env.production (not in version control)
JWT_SECRET=<random-256-bit-secret>
MONGODB_URI=mongodb://user:pass@host:27017/db?authSource=admin
DEFAULT_DIFFICULTY=5
RACK_ENV=production
```

## Security Checklist

### Development
- [ ] Run on localhost only
- [ ] Use separate test database
- [ ] Enable MongoDB authentication
- [ ] Review code for SQL/NoSQL injection
- [ ] Test rate limiting
- [ ] Test input validation
- [ ] Document security limitations

### Production
- [ ] Deploy with HTTPS/TLS
- [ ] Implement authentication/authorization
- [ ] Use environment variables for secrets
- [ ] Enable database encryption at rest
- [ ] Configure firewall rules
- [ ] Set up monitoring/alerting
- [ ] Implement proper logging
- [ ] Add security headers
- [ ] Use Redis for rate limiting
- [ ] Regular security audits
- [ ] Vulnerability scanning
- [ ] Backup and recovery procedures

## Next Steps

- [Architecture Overview](overview.md) - System design
- [Proof of Work](proof-of-work.md) - Mining security
- [API Reference](../api/reference.md) - Endpoint security
- [Deployment Guide](../guides/deployment-guide.md) - Production deployment

---

**Found a security issue?** Please report it responsibly via the [SECURITY](../SECURITY.md) policy.
