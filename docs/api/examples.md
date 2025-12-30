# API Examples

Code examples for integrating with the ChainForge API in multiple programming languages.

## Table of Contents

1. [curl Examples](#curl-examples)
2. [Python Examples](#python-examples)
3. [JavaScript/Node.js Examples](#javascript-nodejs-examples)
4. [Ruby Examples](#ruby-examples)
5. [Complete Workflow Examples](#complete-workflow-examples)

## curl Examples

### Basic Operations

**Create a Blockchain:**
```bash
curl -X POST http://localhost:1910/api/v1/chain
```

**Add a Block (Low Difficulty):**
```bash
CHAIN_ID="674c8a1b2e4f5a0012345678"

curl -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Hello, Blockchain!", "difficulty": 2}'
```

**Get Block Details:**
```bash
CHAIN_ID="674c8a1b2e4f5a0012345678"
BLOCK_ID="674c8b2c3e5f6a0012345679"

curl http://localhost:1910/api/v1/chain/$CHAIN_ID/block/$BLOCK_ID
```

**Validate Block Data:**
```bash
CHAIN_ID="674c8a1b2e4f5a0012345678"
BLOCK_ID="674c8b2c3e5f6a0012345679"

curl -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block/$BLOCK_ID/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "Hello, Blockchain!"}'
```

### Complete Workflow Script

```bash
#!/bin/bash
# create_blockchain.sh

# Create blockchain
echo "Creating blockchain..."
RESPONSE=$(curl -s -X POST http://localhost:1910/api/v1/chain)
CHAIN_ID=$(echo $RESPONSE | jq -r '.id')
echo "Blockchain created: $CHAIN_ID"

# Add first block
echo "Mining first block..."
RESPONSE=$(curl -s -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "First block", "difficulty": 2}')
BLOCK1_ID=$(echo $RESPONSE | jq -r '.block_id')
echo "Block 1 mined: $BLOCK1_ID"

# Add second block
echo "Mining second block..."
RESPONSE=$(curl -s -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Second block", "difficulty": 3}')
BLOCK2_ID=$(echo $RESPONSE | jq -r '.block_id')
echo "Block 2 mined: $BLOCK2_ID"

# Get block details
echo "Getting block 1 details..."
curl -s http://localhost:1910/api/v1/chain/$CHAIN_ID/block/$BLOCK1_ID | jq

# Validate block data
echo "Validating block 1 data..."
curl -s -X POST http://localhost:1910/api/v1/chain/$CHAIN_ID/block/$BLOCK1_ID/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "First block"}' | jq

echo "Done!"
```

## Python Examples

### Using requests Library

**Installation:**
```bash
pip install requests
```

**Basic Example:**
```python
import requests
import json

BASE_URL = "http://localhost:1910/api/v1"

# Create blockchain
response = requests.post(f"{BASE_URL}/chain")
blockchain = response.json()
chain_id = blockchain["id"]
print(f"Created blockchain: {chain_id}")

# Add block
block_data = {
    "data": "Hello from Python!",
    "difficulty": 2
}
response = requests.post(
    f"{BASE_URL}/chain/{chain_id}/block",
    json=block_data
)
block = response.json()
block_id = block["block_id"]
print(f"Mined block: {block_id}")
print(f"Hash: {block['block_hash']}")
print(f"Nonce: {block['nonce']}")

# Get block details
response = requests.get(f"{BASE_URL}/chain/{chain_id}/block/{block_id}")
block_details = response.json()
print(json.dumps(block_details, indent=2))

# Validate block data
validation_data = {"data": "Hello from Python!"}
response = requests.post(
    f"{BASE_URL}/chain/{chain_id}/block/{block_id}/valid",
    json=validation_data
)
result = response.json()
print(f"Data valid: {result['valid']}")
```

### ChainForge Python Client Class

```python
import requests
from typing import Dict, Optional

class ChainForgeClient:
    """Python client for ChainForge API"""

    def __init__(self, base_url: str = "http://localhost:1910/api/v1"):
        self.base_url = base_url
        self.session = requests.Session()

    def create_blockchain(self) -> str:
        """Create a new blockchain and return its ID"""
        response = self.session.post(f"{self.base_url}/chain")
        response.raise_for_status()
        return response.json()["id"]

    def add_block(
        self,
        chain_id: str,
        data: str,
        difficulty: Optional[int] = None
    ) -> Dict:
        """Add a block to the blockchain"""
        payload = {"data": data}
        if difficulty is not None:
            payload["difficulty"] = difficulty

        response = self.session.post(
            f"{self.base_url}/chain/{chain_id}/block",
            json=payload
        )
        response.raise_for_status()
        return response.json()

    def get_block(self, chain_id: str, block_id: str) -> Dict:
        """Get block details"""
        response = self.session.get(
            f"{self.base_url}/chain/{chain_id}/block/{block_id}"
        )
        response.raise_for_status()
        return response.json()

    def validate_block_data(
        self,
        chain_id: str,
        block_id: str,
        data: str
    ) -> bool:
        """Validate block data"""
        response = self.session.post(
            f"{self.base_url}/chain/{chain_id}/block/{block_id}/valid",
            json={"data": data}
        )
        response.raise_for_status()
        return response.json()["valid"]

# Usage example
if __name__ == "__main__":
    client = ChainForgeClient()

    # Create blockchain
    chain_id = client.create_blockchain()
    print(f"Blockchain ID: {chain_id}")

    # Add blocks
    blocks = []
    for i in range(3):
        block = client.add_block(
            chain_id,
            data=f"Block {i+1} data",
            difficulty=2
        )
        blocks.append(block)
        print(f"Mined block {i+1}: {block['block_hash'][:16]}...")

    # Get block details
    block_details = client.get_block(chain_id, blocks[0]["block_id"])
    print(f"Block 1 details: {block_details}")

    # Validate data
    is_valid = client.validate_block_data(
        chain_id,
        blocks[0]["block_id"],
        "Block 1 data"
    )
    print(f"Block 1 data valid: {is_valid}")
```

### Error Handling Example

```python
import requests
from requests.exceptions import HTTPError

def create_block_with_retry(chain_id, data, difficulty=2, max_retries=3):
    """Create block with rate limit retry logic"""
    base_url = "http://localhost:1910/api/v1"

    for attempt in range(max_retries):
        try:
            response = requests.post(
                f"{base_url}/chain/{chain_id}/block",
                json={"data": data, "difficulty": difficulty}
            )
            response.raise_for_status()
            return response.json()

        except HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                print(f"Rate limited, retrying in 60s... (attempt {attempt+1})")
                time.sleep(60)
            elif e.response.status_code == 400:  # Validation error
                print(f"Validation error: {e.response.json()}")
                raise
            else:
                raise

    raise Exception("Max retries exceeded")
```

## JavaScript/Node.js Examples

### Using fetch (Node.js 18+)

**Basic Example:**
```javascript
const BASE_URL = "http://localhost:1910/api/v1";

// Create blockchain
async function createBlockchain() {
  const response = await fetch(`${BASE_URL}/chain`, {
    method: "POST"
  });
  const data = await response.json();
  return data.id;
}

// Add block
async function addBlock(chainId, blockData, difficulty = 2) {
  const response = await fetch(`${BASE_URL}/chain/${chainId}/block`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ data: blockData, difficulty })
  });
  return await response.json();
}

// Get block details
async function getBlock(chainId, blockId) {
  const response = await fetch(`${BASE_URL}/chain/${chainId}/block/${blockId}`);
  return await response.json();
}

// Validate block data
async function validateBlockData(chainId, blockId, data) {
  const response = await fetch(
    `${BASE_URL}/chain/${chainId}/block/${blockId}/valid`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ data })
    }
  );
  const result = await response.json();
  return result.valid;
}

// Usage
(async () => {
  try {
    // Create blockchain
    const chainId = await createBlockchain();
    console.log("Blockchain created:", chainId);

    // Add block
    const block = await addBlock(chainId, "Hello from JavaScript!", 2);
    console.log("Block mined:", block.block_id);
    console.log("Hash:", block.block_hash);
    console.log("Nonce:", block.nonce);

    // Get block details
    const blockDetails = await getBlock(chainId, block.block_id);
    console.log("Block details:", JSON.stringify(blockDetails, null, 2));

    // Validate data
    const isValid = await validateBlockData(
      chainId,
      block.block_id,
      "Hello from JavaScript!"
    );
    console.log("Data valid:", isValid);

  } catch (error) {
    console.error("Error:", error);
  }
})();
```

### ChainForge JavaScript Client Class

```javascript
class ChainForgeClient {
  constructor(baseUrl = "http://localhost:1910/api/v1") {
    this.baseUrl = baseUrl;
  }

  async createBlockchain() {
    const response = await fetch(`${this.baseUrl}/chain`, {
      method: "POST"
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    return data.id;
  }

  async addBlock(chainId, data, difficulty = null) {
    const payload = { data };
    if (difficulty !== null) payload.difficulty = difficulty;

    const response = await fetch(`${this.baseUrl}/chain/${chainId}/block`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  }

  async getBlock(chainId, blockId) {
    const response = await fetch(
      `${this.baseUrl}/chain/${chainId}/block/${blockId}`
    );
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  }

  async validateBlockData(chainId, blockId, data) {
    const response = await fetch(
      `${this.baseUrl}/chain/${chainId}/block/${blockId}/valid`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ data })
      }
    );
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const result = await response.json();
    return result.valid;
  }
}

// Usage
const client = new ChainForgeClient();

client.createBlockchain()
  .then(chainId => {
    console.log("Chain ID:", chainId);
    return client.addBlock(chainId, "Test data", 2);
  })
  .then(block => {
    console.log("Block mined:", block);
  })
  .catch(error => {
    console.error("Error:", error);
  });
```

### Using axios

**Installation:**
```bash
npm install axios
```

**Example:**
```javascript
const axios = require('axios');

const BASE_URL = "http://localhost:1910/api/v1";

async function main() {
  try {
    // Create blockchain
    const { data: blockchain } = await axios.post(`${BASE_URL}/chain`);
    const chainId = blockchain.id;
    console.log("Blockchain created:", chainId);

    // Add block
    const { data: block } = await axios.post(
      `${BASE_URL}/chain/${chainId}/block`,
      {
        data: "Hello from axios!",
        difficulty: 2
      }
    );
    console.log("Block mined:", block);

    // Get block
    const { data: blockDetails } = await axios.get(
      `${BASE_URL}/chain/${chainId}/block/${block.block_id}`
    );
    console.log("Block details:", blockDetails);

    // Validate
    const { data: validation } = await axios.post(
      `${BASE_URL}/chain/${chainId}/block/${block.block_id}/valid`,
      { data: "Hello from axios!" }
    );
    console.log("Valid:", validation.valid);

  } catch (error) {
    if (error.response) {
      console.error("API Error:", error.response.data);
    } else {
      console.error("Error:", error.message);
    }
  }
}

main();
```

## Ruby Examples

### Using net/http (Standard Library)

```ruby
require 'net/http'
require 'json'
require 'uri'

BASE_URL = "http://localhost:1910/api/v1"

# Create blockchain
def create_blockchain
  uri = URI("#{BASE_URL}/chain")
  response = Net::HTTP.post(uri, nil)
  JSON.parse(response.body)["id"]
end

# Add block
def add_block(chain_id, data, difficulty = 2)
  uri = URI("#{BASE_URL}/chain/#{chain_id}/block")
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = { data: data, difficulty: difficulty }.to_json

  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end

  JSON.parse(response.body)
end

# Get block
def get_block(chain_id, block_id)
  uri = URI("#{BASE_URL}/chain/#{chain_id}/block/#{block_id}")
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

# Validate block data
def validate_block_data(chain_id, block_id, data)
  uri = URI("#{BASE_URL}/chain/#{chain_id}/block/#{block_id}/valid")
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = { data: data }.to_json

  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end

  JSON.parse(response.body)["valid"]
end

# Usage
chain_id = create_blockchain
puts "Blockchain created: #{chain_id}"

block = add_block(chain_id, "Hello from Ruby!", 2)
puts "Block mined: #{block['block_id']}"
puts "Hash: #{block['block_hash']}"

block_details = get_block(chain_id, block['block_id'])
puts "Block details: #{JSON.pretty_generate(block_details)}"

is_valid = validate_block_data(chain_id, block['block_id'], "Hello from Ruby!")
puts "Data valid: #{is_valid}"
```

### Using httparty Gem

**Installation:**
```bash
gem install httparty
```

**Example:**
```ruby
require 'httparty'

class ChainForgeClient
  include HTTParty
  base_uri 'http://localhost:1910/api/v1'

  def create_blockchain
    response = self.class.post('/chain')
    response['id']
  end

  def add_block(chain_id, data, difficulty = nil)
    payload = { data: data }
    payload[:difficulty] = difficulty if difficulty

    response = self.class.post(
      "/chain/#{chain_id}/block",
      body: payload.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    response.parsed_response
  end

  def get_block(chain_id, block_id)
    response = self.class.get("/chain/#{chain_id}/block/#{block_id}")
    response.parsed_response
  end

  def validate_block_data(chain_id, block_id, data)
    response = self.class.post(
      "/chain/#{chain_id}/block/#{block_id}/valid",
      body: { data: data }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    response['valid']
  end
end

# Usage
client = ChainForgeClient.new

chain_id = client.create_blockchain
puts "Blockchain ID: #{chain_id}"

3.times do |i|
  block = client.add_block(chain_id, "Block #{i+1}", 2)
  puts "Mined block #{i+1}: #{block['block_hash'][0..15]}..."
end

block = client.add_block(chain_id, "Test data", 2)
is_valid = client.validate_block_data(chain_id, block['block_id'], "Test data")
puts "Valid: #{is_valid}"
```

## Complete Workflow Examples

### Multi-Block Mining Workflow (Python)

```python
import requests
import time

BASE_URL = "http://localhost:1910/api/v1"

def mine_blocks_workflow():
    # Create blockchain
    response = requests.post(f"{BASE_URL}/chain")
    chain_id = response.json()["id"]
    print(f"✓ Created blockchain: {chain_id}")

    # Mine 5 blocks with increasing difficulty
    blocks = []
    for i in range(1, 6):
        difficulty = min(i, 4)  # Cap at difficulty 4
        print(f"\n Mining block {i} (difficulty {difficulty})...")

        start_time = time.time()
        response = requests.post(
            f"{BASE_URL}/chain/{chain_id}/block",
            json={
                "data": f"Block {i}: Transaction data",
                "difficulty": difficulty
            }
        )
        elapsed = time.time() - start_time

        block = response.json()
        blocks.append(block)

        print(f"✓ Mined in {elapsed:.2f}s")
        print(f"  Block ID: {block['block_id']}")
        print(f"  Hash: {block['block_hash'][:32]}...")
        print(f"  Nonce: {block['nonce']}")

    # Validate all blocks
    print("\n Validating blocks...")
    for i, block in enumerate(blocks, 1):
        response = requests.post(
            f"{BASE_URL}/chain/{chain_id}/block/{block['block_id']}/valid",
            json={"data": f"Block {i}: Transaction data"}
        )
        is_valid = response.json()["valid"]
        status = "✓" if is_valid else "✗"
        print(f"{status} Block {i}: {'Valid' if is_valid else 'Invalid'}")

    print(f"\nTotal blocks mined: {len(blocks)}")

if __name__ == "__main__":
    mine_blocks_workflow()
```

### Data Integrity Test (JavaScript)

```javascript
const BASE_URL = "http://localhost:1910/api/v1";

async function testDataIntegrity() {
  // Create blockchain
  let response = await fetch(`${BASE_URL}/chain`, { method: "POST" });
  const { id: chainId } = await response.json();
  console.log("✓ Created blockchain:", chainId);

  // Add block
  const originalData = "Sensitive transaction data";
  response = await fetch(`${BASE_URL}/chain/${chainId}/block`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ data: originalData, difficulty: 2 })
  });
  const block = await response.json();
  console.log("✓ Mined block:", block.block_id);

  // Test 1: Validate with correct data
  response = await fetch(
    `${BASE_URL}/chain/${chainId}/block/${block.block_id}/valid`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ data: originalData })
    }
  );
  let result = await response.json();
  console.log(`\nTest 1 - Correct data: ${result.valid ? '✓ Valid' : '✗ Invalid'}`);

  // Test 2: Validate with tampered data
  response = await fetch(
    `${BASE_URL}/chain/${chainId}/block/${block.block_id}/valid`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ data: "Tampered data!" })
    }
  );
  result = await response.json();
  console.log(`Test 2 - Tampered data: ${result.valid ? '✗ Valid (FAIL)' : '✓ Invalid (PASS)'}`);

  // Test 3: Validate with slightly modified data
  response = await fetch(
    `${BASE_URL}/chain/${chainId}/block/${block.block_id}/valid`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ data: originalData + " " })  // Extra space
    }
  );
  result = await response.json();
  console.log(`Test 3 - Extra space: ${result.valid ? '✗ Valid (FAIL)' : '✓ Invalid (PASS)'}`);

  console.log("\n✓ Data integrity test complete!");
}

testDataIntegrity().catch(console.error);
```

## Error Handling Patterns

### Python Error Handling

```python
import requests
from requests.exceptions import HTTPError, ConnectionError, Timeout

def safe_api_call(func):
    """Decorator for safe API calls with error handling"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except ConnectionError:
            print("Error: Cannot connect to ChainForge API")
            return None
        except Timeout:
            print("Error: Request timed out")
            return None
        except HTTPError as e:
            if e.response.status_code == 400:
                print(f"Validation Error: {e.response.json()}")
            elif e.response.status_code == 429:
                print("Rate limit exceeded. Wait 60 seconds.")
            elif e.response.status_code == 404:
                print("Blockchain or block not found")
            else:
                print(f"HTTP Error {e.response.status_code}")
            return None
    return wrapper

@safe_api_call
def create_block_safe(chain_id, data, difficulty=2):
    response = requests.post(
        f"http://localhost:1910/api/v1/chain/{chain_id}/block",
        json={"data": data, "difficulty": difficulty}
    )
    response.raise_for_status()
    return response.json()
```

## Next Steps

- [API Reference](reference.md) - Complete endpoint documentation
- [Rate Limiting](rate-limiting.md) - Understanding rate limits
- [Quick Start Tutorial](../getting-started/quick-start.md) - Try the API yourself

---

**Have a code example to share?** Contribute via [CONTRIBUTING](../CONTRIBUTING.md)!
