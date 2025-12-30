# ChainForge API Documentation

Complete API reference for ChainForge v2.0.

## Base URL

```
http://localhost:1910/api/v1
```

## Authentication

None required (educational project).

## Rate Limiting

All endpoints are rate-limited per IP address:

| Endpoint | Limit | Window |
|----------|-------|--------|
| All | 60 requests | 60 seconds |
| POST /chain | 10 requests | 60 seconds |
| POST /chain/:id/block | 30 requests | 60 seconds |

**Rate Limit Response (429):**
```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```

## Content Type

All requests and responses use `application/json`.

## Error Handling

### HTTP Status Codes

- `200` - Success
- `400` - Validation Error
- `404` - Not Found
- `429` - Rate Limit Exceeded
- `500` - Server Error

### Error Response Format

**Validation Error (400):**
```json
{
  "errors": {
    "field_name": ["error message 1", "error message 2"]
  }
}
```

**Rate Limit (429):**
```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```

**Server Error (500):**
```json
{
  "error": "Error message"
}
```

---

## Endpoints

### 1. Create Blockchain

Creates a new blockchain instance with genesis block.

**Endpoint:** `POST /api/v1/chain`

**Rate Limit:** 10 requests/minute per IP

**Request:**
```bash
curl -X POST http://localhost:1910/api/v1/chain
```

**Response (200):**
```json
{
  "id": "507f1f77bcf86cd799439011"
}
```

**Response Fields:**
- `id` (string): Unique blockchain identifier (MongoDB ObjectId)

**Example:**
```bash
# Create blockchain
curl -X POST http://localhost:1910/api/v1/chain

# Response
{"id":"674f8a2b1c3d4e5f6a7b8c9d"}
```

---

### 2. Add Block (Mine)

Mines and adds a new block to the blockchain using Proof of Work.

**Endpoint:** `POST /api/v1/chain/:id/block`

**Rate Limit:** 30 requests/minute per IP

**Request Parameters:**

| Parameter | Type | Required | Validation | Default |
|-----------|------|----------|------------|---------|
| `data` | string | Yes | Non-empty | - |
| `difficulty` | integer | No | 1-10 | `DEFAULT_DIFFICULTY` env var (2) |

**Request:**
```bash
curl -X POST http://localhost:1910/api/v1/chain/507f1f77bcf86cd799439011/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Transaction data", "difficulty": 3}'
```

**Response (200):**
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "block_id": "507f191e810c19729de860ea",
  "block_hash": "000a1b2c3d4e5f6789abcdef",
  "nonce": 1542,
  "difficulty": 3
}
```

**Response Fields:**
- `chain_id` (string): Blockchain identifier
- `block_id` (string): New block identifier
- `block_hash` (string): Mined block hash (starts with N zeros)
- `nonce` (integer): Number of mining iterations
- `difficulty` (integer): Difficulty level used

**Validation Errors (400):**
```json
{
  "errors": {
    "data": ["must be filled"],
    "difficulty": ["must be between 1 and 10"]
  }
}
```

**Mining Time:**
- Difficulty 1-2: < 1 second
- Difficulty 3-4: Few seconds
- Difficulty 5-6: Minutes
- Difficulty 7+: Hours or more

**Example:**
```bash
# Mine block with default difficulty
curl -X POST http://localhost:1910/api/v1/chain/674f8a2b1c3d4e5f6a7b8c9d/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Hello World"}'

# Response
{
  "chain_id": "674f8a2b1c3d4e5f6a7b8c9d",
  "block_id": "674f8b3c2d4e5f6g7h8i9j0k",
  "block_hash": "00a1b2c3d4e5f6789...",
  "nonce": 157,
  "difficulty": 2
}
```

---

### 3. Get Block Details

Retrieves complete block information including mining data.

**Endpoint:** `GET /api/v1/chain/:id/block/:block_id`

**Rate Limit:** 60 requests/minute (global)

**Request:**
```bash
curl http://localhost:1910/api/v1/chain/507f1f77bcf86cd799439011/block/507f191e810c19729de860ea
```

**Response (200):**
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "block": {
    "id": "507f191e810c19729de860ea",
    "index": 1,
    "data": "Transaction data",
    "hash": "000a1b2c3d4e5f6789abcdef",
    "previous_hash": "00f8a2b1c3d4e5f67",
    "nonce": 1542,
    "difficulty": 3,
    "timestamp": 1699564821,
    "valid_hash": true
  }
}
```

**Response Fields:**
- `chain_id` (string): Blockchain identifier
- `block.id` (string): Block identifier
- `block.index` (integer): Block position in chain (starts at 0)
- `block.data` (string): Stored data
- `block.hash` (string): Block's SHA256 hash
- `block.previous_hash` (string): Previous block's hash
- `block.nonce` (integer): Mining nonce value
- `block.difficulty` (integer): Difficulty level used
- `block.timestamp` (integer): Unix timestamp
- `block.valid_hash` (boolean): Whether hash meets difficulty requirement

**Error (404):**
```json
{
  "error": "Block not found"
}
```

**Example:**
```bash
# Get block details
curl http://localhost:1910/api/v1/chain/674f8a2b1c3d4e5f6a7b8c9d/block/674f8b3c2d4e5f6g7h8i9j0k

# Response includes full mining info
{
  "chain_id": "674f8a2b1c3d4e5f6a7b8c9d",
  "block": {
    "id": "674f8b3c2d4e5f6g7h8i9j0k",
    "index": 1,
    "data": "Hello World",
    "hash": "00a1b2c3d4e5f6789...",
    "previous_hash": "0f9e8d7c6b5a4...",
    "nonce": 157,
    "difficulty": 2,
    "timestamp": 1731729600,
    "valid_hash": true
  }
}
```

---

### 4. Validate Block Data

Validates if provided data matches the block's stored hash.

**Endpoint:** `POST /api/v1/chain/:id/block/:block_id/valid`

**Rate Limit:** 60 requests/minute (global)

**Request Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `data` | string | Yes | Data to validate |

**Request:**
```bash
curl -X POST http://localhost:1910/api/v1/chain/507f1f77bcf86cd799439011/block/507f191e810c19729de860ea/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "Transaction data"}'
```

**Response (200):**
```json
{
  "chain_id": "507f1f77bcf86cd799439011",
  "block_id": "507f191e810c19729de860ea",
  "valid": true
}
```

**Response Fields:**
- `chain_id` (string): Blockchain identifier
- `block_id` (string): Block identifier
- `valid` (boolean): Whether data matches block's hash

**Validation Errors (400):**
```json
{
  "errors": {
    "data": ["must be filled"]
  }
}
```

**Example:**
```bash
# Validate correct data
curl -X POST http://localhost:1910/api/v1/chain/674f8a2b1c3d4e5f6a7b8c9d/block/674f8b3c2d4e5f6g7h8i9j0k/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "Hello World"}'

# Response
{"chain_id":"674f8a2b1c3d4e5f6a7b8c9d","block_id":"674f8b3c2d4e5f6g7h8i9j0k","valid":true}

# Validate incorrect data
curl -X POST http://localhost:1910/api/v1/chain/674f8a2b1c3d4e5f6a7b8c9d/block/674f8b3c2d4e5f6g7h8i9j0k/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "Wrong Data"}'

# Response
{"chain_id":"674f8a2b1c3d4e5f6a7b8c9d","block_id":"674f8b3c2d4e5f6g7h8i9j0k","valid":false}
```

---

## Common Workflows

### Create and Mine Blocks

```bash
# 1. Create blockchain
CHAIN_ID=$(curl -s -X POST http://localhost:1910/api/v1/chain | jq -r '.id')

# 2. Mine first block (difficulty 2)
BLOCK1=$(curl -s -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "First block"}')

# 3. Mine second block (difficulty 3)
BLOCK2=$(curl -s -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Second block", "difficulty": 3}')

# 4. Get block details
curl http://localhost:1910/api/v1/chain/$CHAIN_ID/block/$(echo $BLOCK1 | jq -r '.block_id')

# 5. Validate block data
curl -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block/$(echo $BLOCK1 | jq -r '.block_id')/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "First block"}'
```

### Handle Rate Limiting

```bash
# Check rate limit headers (if implemented)
curl -i http://localhost:1910/api/v1/chain

# Wait and retry on 429
while true; do
  response=$(curl -s -w "%{http_code}" -X POST http://localhost:1910/api/v1/chain)
  code=${response: -3}
  if [ "$code" = "429" ]; then
    echo "Rate limited, waiting 60 seconds..."
    sleep 60
  else
    break
  fi
done
```

### Handle Validation Errors

```bash
# Validate input before sending
data="my data"
difficulty=5

if [ -z "$data" ]; then
  echo "Error: data cannot be empty"
  exit 1
fi

if [ "$difficulty" -lt 1 ] || [ "$difficulty" -gt 10 ]; then
  echo "Error: difficulty must be between 1-10"
  exit 1
fi

# Send request
curl -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block \
  -H 'Content-Type: application/json' \
  -d "{\"data\": \"$data\", \"difficulty\": $difficulty}"
```

---

## Client Libraries

### Ruby Client Example

```ruby
require 'httparty'

class ChainForgeClient
  BASE_URL = 'http://localhost:1910/api/v1'

  def create_chain
    response = HTTParty.post("#{BASE_URL}/chain")
    JSON.parse(response.body)
  end

  def mine_block(chain_id, data, difficulty = nil)
    body = { data: data }
    body[:difficulty] = difficulty if difficulty

    response = HTTParty.post(
      "#{BASE_URL}/chain/#{chain_id}/block",
      body: body.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    JSON.parse(response.body)
  end

  def get_block(chain_id, block_id)
    response = HTTParty.get("#{BASE_URL}/chain/#{chain_id}/block/#{block_id}")
    JSON.parse(response.body)
  end

  def validate_block(chain_id, block_id, data)
    response = HTTParty.post(
      "#{BASE_URL}/chain/#{chain_id}/block/#{block_id}/valid",
      body: { data: data }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    JSON.parse(response.body)
  end
end

# Usage
client = ChainForgeClient.new
chain = client.create_chain
block = client.mine_block(chain['id'], 'Hello World', 2)
details = client.get_block(chain['id'], block['block_id'])
validation = client.validate_block(chain['id'], block['block_id'], 'Hello World')
```

### Python Client Example

```python
import requests

class ChainForgeClient:
    BASE_URL = 'http://localhost:1910/api/v1'

    def create_chain(self):
        response = requests.post(f'{self.BASE_URL}/chain')
        return response.json()

    def mine_block(self, chain_id, data, difficulty=None):
        payload = {'data': data}
        if difficulty:
            payload['difficulty'] = difficulty

        response = requests.post(
            f'{self.BASE_URL}/chain/{chain_id}/block',
            json=payload
        )
        return response.json()

    def get_block(self, chain_id, block_id):
        response = requests.get(
            f'{self.BASE_URL}/chain/{chain_id}/block/{block_id}'
        )
        return response.json()

    def validate_block(self, chain_id, block_id, data):
        response = requests.post(
            f'{self.BASE_URL}/chain/{chain_id}/block/{block_id}/valid',
            json={'data': data}
        )
        return response.json()

# Usage
client = ChainForgeClient()
chain = client.create_chain()
block = client.mine_block(chain['id'], 'Hello World', difficulty=2)
details = client.get_block(chain['id'], block['block_id'])
validation = client.validate_block(chain['id'], block['block_id'], 'Hello World')
```

### JavaScript Client Example

```javascript
class ChainForgeClient {
  constructor(baseUrl = 'http://localhost:1910/api/v1') {
    this.baseUrl = baseUrl;
  }

  async createChain() {
    const response = await fetch(`${this.baseUrl}/chain`, {
      method: 'POST'
    });
    return response.json();
  }

  async mineBlock(chainId, data, difficulty = null) {
    const payload = { data };
    if (difficulty) payload.difficulty = difficulty;

    const response = await fetch(`${this.baseUrl}/chain/${chainId}/block`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    return response.json();
  }

  async getBlock(chainId, blockId) {
    const response = await fetch(
      `${this.baseUrl}/chain/${chainId}/block/${blockId}`
    );
    return response.json();
  }

  async validateBlock(chainId, blockId, data) {
    const response = await fetch(
      `${this.baseUrl}/chain/${chainId}/block/${blockId}/valid`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data })
      }
    );
    return response.json();
  }
}

// Usage
(async () => {
  const client = new ChainForgeClient();
  const chain = await client.createChain();
  const block = await client.mineBlock(chain.id, 'Hello World', 2);
  const details = await client.getBlock(chain.id, block.block_id);
  const validation = await client.validateBlock(chain.id, block.block_id, 'Hello World');
})();
```

---

## Versioning

Current API version: **v1**

**URL Pattern:** `/api/v1/*`

Future versions will use `/api/v2/*`, `/api/v3/*`, etc.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for API changes.

---

## Support

- GitHub Issues: https://github.com/Perafan18/chain_forge/issues
- Documentation: See README.md, CLAUDE.md
