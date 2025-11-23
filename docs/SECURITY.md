# Security Policy

## Overview

ChainForge is an **educational project** NOT intended for production use. It demonstrates blockchain security concepts but lacks production-grade security features.

## Security Features

### Rate Limiting

API endpoints are protected by Rack::Attack:

| Scope | Limit | Window | Action |
|-------|-------|--------|--------|
| All endpoints | 60 requests | 1 minute | 429 response |
| POST /api/v1/chain | 10 requests | 1 minute | 429 response |
| POST /api/v1/chain/:id/block | 30 requests | 1 minute | 429 response |

**Limitations:**
- Memory-based (resets on restart)
- Per-IP enforcement only
- Not suitable for distributed systems
- Can be bypassed with multiple IPs

### Input Validation

All API inputs validated via dry-validation:

**Validated Fields:**
- `data`: Must be non-empty string
- `difficulty`: Must be integer 1-10

**Protection Against:**
- Type confusion attacks
- Invalid data injection
- Out-of-range values

**Error Response (400):**
```json
{
  "errors": {
    "data": ["must be filled"],
    "difficulty": ["must be between 1 and 10"]
  }
}
```

### Cryptographic Security

**Block Integrity:**
- SHA256 hashing (256-bit security)
- Proof of Work verification
- Hash chaining (immutability)

**Proof of Work:**
- Computational cost to modify blocks
- Difficulty-based security level
- Prevents easy chain tampering

**Limitations:**
- Single SHA256 (Bitcoin uses double)
- Fixed difficulty (no dynamic adjustment)
- No distributed consensus

## Known Vulnerabilities

### Authentication & Authorization
**Issue:** No authentication system
**Impact:** Anyone can use API
**Risk:** High
**Mitigation:** Use only in trusted environments

### Data Encryption
**Issue:** No encryption at rest or in transit
**Impact:** Data visible in MongoDB and network
**Risk:** High
**Mitigation:** Never store sensitive data

### HTTPS
**Issue:** No TLS/SSL enforcement
**Impact:** Man-in-the-middle attacks possible
**Risk:** High
**Mitigation:** Run behind HTTPS proxy in production

### MongoDB Security
**Issue:** No authentication configured
**Impact:** Database accessible without credentials
**Risk:** High
**Mitigation:** Configure MongoDB authentication in production

### Denial of Service
**Issue:** Simple in-memory rate limiting
**Impact:** Can be exhausted with multiple IPs
**Risk:** Medium
**Mitigation:** Use Redis-backed rate limiting in production

### Code Injection
**Issue:** No sanitization beyond type checking
**Impact:** Potentially malicious data stored
**Risk:** Low (stored, not executed)
**Mitigation:** Validate data content, not just type

## Reporting Vulnerabilities

### Security Issues

If you discover a security vulnerability:

**DO NOT** open a public GitHub issue

Instead:
1. Email: [your-email@example.com]
2. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if known)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Assessment**: Within 1 week
- **Fix**: Depends on severity
- **Disclosure**: After fix is deployed

### Severity Levels

**Critical**: Remote code execution, data breach
- Response: Immediate (same day)

**High**: Authentication bypass, DoS
- Response: 1-3 days

**Medium**: Information disclosure
- Response: 1-2 weeks

**Low**: Minor issues
- Response: Best effort

## Security Best Practices

### Development

```bash
# Never commit sensitive data
git add .env  # ❌ Wrong
git add .env.example  # ✅ Correct

# Use environment variables
difficulty = 2  # ❌ Wrong
difficulty = ENV.fetch('DEFAULT_DIFFICULTY', '2').to_i  # ✅ Correct

# Validate all inputs
data = params[:data]  # ❌ Wrong
validation = BlockDataContract.new.call(params)  # ✅ Correct
```

### Deployment

**Never expose to public internet without:**
- ✅ Reverse proxy with HTTPS
- ✅ MongoDB authentication
- ✅ Firewall rules
- ✅ Rate limiting (Redis-backed)
- ✅ Authentication system
- ✅ Input sanitization
- ✅ Monitoring and logging

### MongoDB Security

```yaml
# docker-compose.yml (production)
mongodb:
  environment:
    MONGO_INITDB_ROOT_USERNAME: admin
    MONGO_INITDB_ROOT_PASSWORD: ${MONGO_PASSWORD}
  volumes:
    - mongodb_data:/data/db
  networks:
    - internal  # Not exposed to public
```

### Reverse Proxy (nginx)

```nginx
server {
    listen 443 ssl;
    server_name api.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location /api/ {
        proxy_pass http://localhost:1910;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Rate limiting
        limit_req zone=api burst=10 nodelay;
    }
}
```

## Out of Scope

The following are known educational limitations and NOT security bugs:

- No peer-to-peer networking
- No distributed consensus
- No transaction signing
- No authentication/authorization
- No HTTPS enforcement
- Simple rate limiting
- No encryption at rest
- No input sanitization beyond type checking
- No SQL injection protection (using MongoDB)
- No XSS protection (API only, no web interface)

## Security Checklist

### Before Deploying

- [ ] Configure MongoDB authentication
- [ ] Set up HTTPS with valid certificates
- [ ] Implement reverse proxy (nginx/apache)
- [ ] Configure firewall rules
- [ ] Use Redis-backed rate limiting
- [ ] Set strong DEFAULT_DIFFICULTY (4+)
- [ ] Enable logging and monitoring
- [ ] Never store sensitive data
- [ ] Implement authentication
- [ ] Regular security updates (`bundle update`)

### Monitoring

Monitor for:
- Unusual traffic patterns
- Rate limit violations
- Mining attempts with high difficulty
- Database connection errors
- Authentication failures (if implemented)

## Compliance

### GDPR / Privacy

ChainForge stores:
- IP addresses (rate limiting)
- User-provided data in blocks
- Timestamps

**Recommendations:**
- Don't store personal data
- Implement data deletion
- Add privacy policy
- Obtain user consent

### Data Retention

- Blockchain data is immutable
- Cannot delete blocks once created
- Consider implications before storing data

## Security Resources

### Learning

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Ruby on Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [MongoDB Security Checklist](https://docs.mongodb.com/manual/administration/security-checklist/)

### Tools

- **bundler-audit**: Check for vulnerable gems
- **brakeman**: Static security analysis (Rails)
- **RuboCop**: Security cops
- **OWASP ZAP**: Penetration testing

### Commands

```bash
# Check for vulnerable dependencies
gem install bundler-audit
bundle audit check --update

# Security-focused linting
bundle exec rubocop --only Security
```

## Educational Context

ChainForge demonstrates blockchain security concepts:

**✅ What it teaches:**
- Cryptographic hashing
- Proof of Work security
- Chain immutability
- Rate limiting basics
- Input validation

**❌ What it doesn't cover:**
- Distributed consensus security
- Cryptographic key management
- Network security
- Advanced DoS protection
- Data encryption

Use this project to learn fundamentals, then study production systems (Bitcoin, Ethereum) for comprehensive security.

## Updates

This security policy is reviewed and updated with each major release.

**Last Updated:** 2025-11-09
**Version:** 2.0.0
