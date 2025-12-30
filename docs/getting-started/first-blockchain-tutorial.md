# First Blockchain Tutorial

A comprehensive, step-by-step tutorial that explains blockchain concepts as you build your first blockchain with ChainForge.

## Tutorial Overview

In this tutorial, you'll:
1. Understand what blockchains are and how they work
2. Create a blockchain instance
3. Mine blocks with Proof of Work
4. Explore chain integrity and immutability
5. Experiment with different mining difficulties
6. Learn how tampering is detected

**Time Required:** 15-20 minutes

**Prerequisites:**
- ChainForge installed ([Installation Guide](installation.md))
- Basic understanding of HTTP requests
- `curl` or API client (Postman, Insomnia)

## Part 1: Understanding Blockchains

### What is a Blockchain?

A blockchain is a **distributed ledger** - a digital record of transactions organized into blocks and linked together in a chain. Think of it as a digital notebook where:

- Each page is a "block"
- Pages are numbered sequentially (index)
- Each page references the previous page's fingerprint (hash)
- You can only add pages, never remove or modify them
- Everyone can verify the pages haven't been tampered with

### Key Concepts

**Block**: A container for data with metadata
- `index`: Position in the chain (0, 1, 2, ...)
- `data`: Information stored in the block
- `timestamp`: When the block was created
- `hash`: Cryptographic fingerprint of the block
- `previous_hash`: Link to the previous block's hash
- `nonce`: Number used to meet Proof of Work requirement
- `difficulty`: Mining difficulty (how many leading zeros)

**Hash**: A cryptographic fingerprint (SHA256)
- Fixed length (64 characters)
- Unique for each input
- Changing even 1 character completely changes the hash
- Impossible to reverse (can't get data from hash)

**Proof of Work (PoW)**: Mining algorithm that requires computational work
- Must find a nonce that produces a valid hash
- Valid hash starts with required number of zeros
- Higher difficulty = more zeros = more attempts = more secure

**Chain Integrity**: Validation that ensures data hasn't been tampered with
- Each block links to the previous block
- Changing any data invalidates the hash
- Invalid hash breaks the chain

## Part 2: Create Your Blockchain

### Step 1: Start ChainForge

```bash
# Using Docker
docker-compose up

# Or local installation
ruby main.rb -p 1910
```

Verify it's running:
```bash
curl http://localhost:1910
# Output: Hello to ChainForge!
```

### Step 2: Create a Blockchain Instance

```bash
curl -X POST http://localhost:1910/api/v1/chain
```

**Response:**
```json
{
  "id": "674c8a1b2e4f5a0012345678"
}
```

**What just happened?**

1. ChainForge created a new MongoDB collection for this blockchain
2. Generated a **genesis block** (the first block):
   ```json
   {
     "index": 0,
     "data": "Genesis Block",
     "hash": "calculated_hash_here",
     "previous_hash": null,
     "nonce": 0,
     "difficulty": 0,
     "timestamp": 1699564821
   }
   ```
3. Genesis blocks are special:
   - Always index 0
   - No previous_hash (they're first)
   - NOT mined (no Proof of Work requirement)
   - Auto-created when blockchain is instantiated

Save the blockchain ID for subsequent requests!

## Part 3: Mining Your First Block

### Step 3: Add a Block with Low Difficulty

Let's start with difficulty 1 (easy mining):

```bash
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "My first transaction", "difficulty": 1}'
```

**Response:**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8b2c3e5f6a0012345679",
  "block_hash": "0a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef012345678",
  "nonce": 7,
  "difficulty": 1
}
```

**Mining process breakdown:**

The system performed these steps:

1. **Validation**: Checked that `data` is provided and `difficulty` is 1-10 ✓
2. **Block Creation**: Created a new block with:
   - index: 1 (next available)
   - data: "My first transaction"
   - previous_hash: (genesis block's hash)
   - difficulty: 1
   - nonce: 0 (starting point)

3. **Mining Algorithm** (Proof of Work):
   ```
   Target: Hash must start with "0" (one leading zero)

   Attempt 1: nonce=0
     hash = SHA256("1" + timestamp + "My first transaction" + previous_hash + "0")
     hash = "a1b2c3d4..."  ✗ (doesn't start with "0")

   Attempt 2: nonce=1
     hash = SHA256("1" + timestamp + "My first transaction" + previous_hash + "1")
     hash = "9f8e7d6c..."  ✗ (doesn't start with "0")

   ...

   Attempt 7: nonce=7
     hash = SHA256("1" + timestamp + "My first transaction" + previous_hash + "7")
     hash = "0a1b2c3d..."  ✓ (starts with "0"!)
   ```

4. **Block Saved**: Block stored in MongoDB with nonce=7

**Why different nonce values each time?**
The timestamp changes every second, so even the same data produces different hashes!

### Step 4: View the Complete Block

```bash
curl http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block/674c8b2c3e5f6a0012345679
```

**Response:**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block": {
    "id": "674c8b2c3e5f6a0012345679",
    "index": 1,
    "data": "My first transaction",
    "hash": "0a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef012345678",
    "previous_hash": "genesis_block_hash_here",
    "nonce": 7,
    "difficulty": 1,
    "timestamp": 1699564821,
    "valid_hash": true
  }
}
```

**Field explanations:**

- `index: 1` - Second block in the chain (0 = genesis)
- `hash: 0a1b2...` - Starts with "0" (meets difficulty 1)
- `previous_hash: genesis_hash` - Links to genesis block
- `nonce: 7` - Took 7 attempts to find valid hash
- `valid_hash: true` - Hash meets difficulty requirement

## Part 4: Exploring Mining Difficulty

### Step 5: Mine with Difficulty 2

Now let's try difficulty 2 (requires "00"):

```bash
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Second block with higher difficulty", "difficulty": 2}'
```

**Response:**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8c3d4e6f7a001234567a",
  "block_hash": "00abc123def456789abcdef0123456789abcdef0123456789abcdef012345678",
  "nonce": 142,
  "difficulty": 2
}
```

**Notice:**
- Hash starts with "00" (2 leading zeros)
- Nonce: 142 (many more attempts than difficulty 1)
- Mining took longer (~1-2 seconds)

**Why exponentially harder?**

| Difficulty | Target Pattern | Probability per Attempt | Avg Attempts |
|-----------|---------------|------------------------|--------------|
| 1 | 0* | 1/16 (6.25%) | ~16 |
| 2 | 00* | 1/256 (0.39%) | ~256 |
| 3 | 000* | 1/4096 (0.024%) | ~4096 |
| 4 | 0000* | 1/65536 (0.0015%) | ~65536 |

Each additional zero multiplies attempts by 16!

### Step 6: Mine with Difficulty 3

Let's push it further:

```bash
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Third block - even harder", "difficulty": 3}'
```

**This will take several seconds!** Watch the process:

```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8d4e5f7g8a001234567b",
  "block_hash": "000def123abc456789abcdef0123456789abcdef0123456789abcdef012345678",
  "nonce": 3847,
  "difficulty": 3
}
```

**Observations:**
- Hash: "000..." (3 leading zeros)
- Nonce: 3847 (thousands of attempts!)
- Time: Several seconds of CPU work

**Bitcoin comparison:**
- Bitcoin uses ~19 leading zeros (as of 2023)
- Requires specialized hardware (ASICs)
- Difficulty adjusts every 2 weeks to maintain ~10 min block time
- ChainForge difficulty is fixed (educational simplification)

## Part 5: Chain Integrity and Validation

### Step 7: Understanding Chain Structure

Your blockchain now looks like this:

```
Blockchain: 674c8a1b2e4f5a0012345678

Block 0 (Genesis)
├─ index: 0
├─ hash: abc123...
├─ previous_hash: null
└─ nonce: 0 (not mined)
    │
    ↓ (previous_hash link)
    │
Block 1
├─ index: 1
├─ hash: 0a1b2c... (difficulty 1)
├─ previous_hash: abc123... ← links to Block 0
└─ nonce: 7
    │
    ↓ (previous_hash link)
    │
Block 2
├─ index: 2
├─ hash: 00abc1... (difficulty 2)
├─ previous_hash: 0a1b2c... ← links to Block 1
└─ nonce: 142
    │
    ↓ (previous_hash link)
    │
Block 3
├─ index: 3
├─ hash: 000def... (difficulty 3)
├─ previous_hash: 00abc1... ← links to Block 2
└─ nonce: 3847
```

### Step 8: Validate Block Data (Correct)

Verify Block 1's data is unchanged:

```bash
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block/674c8b2c3e5f6a0012345679/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "My first transaction"}'
```

**Response:**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8b2c3e5f6a0012345679",
  "valid": true
}
```

**Validation process:**
1. Retrieve block from database
2. Recalculate hash using provided data: `SHA256(1 + timestamp + "My first transaction" + previous_hash + 7)`
3. Compare calculated hash with stored hash
4. If match: `valid: true` ✓

### Step 9: Validate Block Data (Tampered)

Now try with wrong data to see tampering detection:

```bash
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block/674c8b2c3e5f6a0012345679/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "Tampered data!"}'
```

**Response:**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8b2c3e5f6a0012345679",
  "valid": false
}
```

**Why invalid?**
1. Recalculates hash: `SHA256(1 + timestamp + "Tampered data!" + previous_hash + 7)`
2. Calculated hash: `9xyz...` (completely different!)
3. Stored hash: `0a1b2c...`
4. Hashes don't match → `valid: false` ✗

**Key insight:** Changing even one character produces a completely different hash!

## Part 6: Immutability in Action

### Understanding Why Blockchains Are Immutable

**Scenario:** An attacker wants to change Block 1's data from "My first transaction" to "Fraudulent transaction"

**What would need to happen:**

1. **Change Block 1 data:**
   ```
   Old: "My first transaction" → hash: 0a1b2c...
   New: "Fraudulent transaction" → hash: 9xyz... ✗
   ```
   Problem: Hash no longer starts with "0" (doesn't meet difficulty 1)

2. **Re-mine Block 1:**
   Find new nonce to get valid hash starting with "0"
   ```
   After re-mining: hash: 0def456...
   ```

3. **Block 2 is now invalid:**
   ```
   Block 2:
   ├─ previous_hash: 0a1b2c... (old Block 1 hash)
   └─ Stored hash: 00abc1...

   Problem: previous_hash doesn't match Block 1's new hash (0def456)
   ```

4. **Re-mine Block 2:**
   Update previous_hash and re-mine
   ```
   After re-mining: hash: 00ghi789...
   ```

5. **Block 3 is now invalid:**
   Same problem - previous_hash doesn't match

6. **Re-mine ALL subsequent blocks:**
   Must re-mine Block 3, Block 4, Block 5, ... (entire chain!)

**Computational Security:**
- Each block took time to mine (PoW)
- Attacker must re-mine faster than network adds new blocks
- In real blockchains, this requires >51% of network computing power
- Practically impossible for established blockchains like Bitcoin

### ChainForge's Integrity Validation

ChainForge validates chain integrity before adding new blocks:

```ruby
# Pseudocode from src/blockchain.rb
def valid?
  blocks.each_with_index do |block, index|
    # Check 1: Hash matches calculated hash
    return false unless block.hash == block.calculate_hash

    # Check 2: Hash meets difficulty requirement
    return false unless block.valid_hash?

    # Check 3: Links to previous block (skip genesis)
    if index > 0
      return false unless block.previous_hash == blocks[index - 1].hash
    end
  end

  true
end
```

If validation fails, ChainForge rejects new blocks until integrity is restored.

## Part 7: Advanced Experiments

### Experiment 1: Default Difficulty

Omit the `difficulty` parameter to use default (from `DEFAULT_DIFFICULTY` env var):

```bash
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Using default difficulty"}'
```

**Response:**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8e5f6g8h9a001234567c",
  "block_hash": "00abc...",
  "nonce": 234,
  "difficulty": 2
}
```

Default difficulty is 2 (set in `.env` file).

### Experiment 2: Multiple Independent Blockchains

Create multiple blockchains to see they're independent:

```bash
# Create first blockchain
curl -X POST http://localhost:1910/api/v1/chain
# Response: {"id": "blockchain_1_id"}

# Create second blockchain
curl -X POST http://localhost:1910/api/v1/chain
# Response: {"id": "blockchain_2_id"}

# Add block to first blockchain
curl -X POST http://localhost:1910/api/v1/chain/blockchain_1_id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Blockchain 1 data"}'

# Add block to second blockchain
curl -X POST http://localhost:1910/api/v1/chain/blockchain_2_id/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Blockchain 2 data"}'
```

Each blockchain has its own genesis block and independent chain!

### Experiment 3: Rate Limiting

Try exceeding rate limits to see protection in action:

```bash
# Create many blockchains rapidly (limit: 10/minute)
for i in {1..15}; do
  curl -X POST http://localhost:1910/api/v1/chain
done
```

**Response (after 10 requests):**
```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```
**HTTP Status:** 429 (Too Many Requests)

### Experiment 4: Input Validation

Try invalid inputs:

**Missing data:**
```bash
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block \
  -H 'Content-Type: application/json' \
  -d '{"difficulty": 2}'
```

**Response:**
```json
{
  "errors": {
    "data": ["must be filled"]
  }
}
```
**HTTP Status:** 400 (Bad Request)

**Invalid difficulty:**
```bash
curl -X POST http://localhost:1910/api/v1/chain/674c8a1b2e4f5a0012345678/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "test", "difficulty": 15}'
```

**Response:**
```json
{
  "errors": {
    "difficulty": ["must be between 1 and 10"]
  }
}
```

## Part 8: Recap and Next Steps

### What You've Learned

✅ **Blockchain Basics:**
- Blocks contain data and link via hashes
- Genesis blocks start each chain
- Chains are append-only (immutable)

✅ **Proof of Work:**
- Mining finds nonce producing valid hash
- Difficulty determines leading zeros required
- Higher difficulty = exponentially more work

✅ **Chain Integrity:**
- Hash chaining links blocks together
- Tampering invalidates hashes
- Breaking chain requires re-mining all subsequent blocks

✅ **Security Features:**
- Rate limiting prevents abuse
- Input validation prevents malformed data
- PoW makes tampering computationally expensive

### Key Takeaways

1. **Immutability through computation**: PoW makes changing history expensive
2. **Hash chaining**: Each block depends on all previous blocks
3. **Verifiability**: Anyone can validate block data
4. **Decentralization** (in real blockchains): No single point of control

### Next Steps

**Explore Further:**
1. [API Reference](../api/reference.md) - Complete endpoint documentation
2. [Proof of Work Deep Dive](../architecture/proof-of-work.md) - Mining algorithm details
3. [Architecture Overview](../architecture/overview.md) - System design
4. [API Examples](../api/examples.md) - Code examples in multiple languages

**Build Something:**
- Create a simple blockchain explorer web app
- Implement a transaction system on top of ChainForge
- Write scripts to automate blockchain creation
- Build a visualization tool for the blockchain

**Learn More:**
- Study Bitcoin's whitepaper (Satoshi Nakamoto, 2008)
- Research Ethereum's smart contracts
- Explore consensus mechanisms (PoW, PoS, etc.)
- Learn about Merkle trees and their role in blockchains

## Troubleshooting

**Q: Mining is taking forever!**
A: Lower the difficulty (1-3 for development). Difficulty 5+ can take minutes.

**Q: I get "Blockchain not found" errors**
A: Double-check your blockchain ID. Each blockchain has a unique ID.

**Q: Rate limit errors**
A: Wait 1 minute for the rate limit window to reset.

**Q: MongoDB connection errors**
A: Ensure MongoDB is running: `mongosh --eval "db.version()"`

For more help, see [Troubleshooting Guide](../guides/troubleshooting.md).

---

**Congratulations!** You've completed the comprehensive blockchain tutorial. You now understand how blockchains work and how ChainForge implements these concepts!
