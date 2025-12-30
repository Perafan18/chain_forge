# Quick Start Tutorial

Get your first blockchain running in 5 minutes! This tutorial assumes you've completed the [Installation Guide](installation.md).

## Prerequisites

- ChainForge installed and running
- `curl` command-line tool (or Postman/Insomnia)
- MongoDB running

## Step 1: Start the Server

```bash
# If using Docker
docker-compose up

# If using local installation
ruby main.rb -p 1910
```

Verify the server is running:
```bash
curl http://localhost:1910
```

Expected output:
```
Hello to ChainForge!
```

## Step 2: Create Your First Blockchain

```bash
curl -X POST http://localhost:1910/api/v1/chain
```

**Response:**
```json
{
  "id": "674c8a1b2e4f5a0012345678"
}
```

Save this `id` - you'll need it for the next steps!

**What happened?**
- ChainForge created a new blockchain instance in MongoDB
- Automatically generated a genesis block (index 0)
- Genesis block is NOT mined (no Proof of Work required)
- The blockchain is now ready to accept new blocks

## Step 3: Add Your First Block (Mining!)

Replace `<blockchain_id>` with the ID from Step 2:

```bash
curl -X POST http://localhost:1910/api/v1/chain/<blockchain_id>/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Hello, Blockchain!", "difficulty": 2}'
```

**Response:**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8b2c3e5f6a0012345679",
  "block_hash": "00a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef012345678",
  "nonce": 142,
  "difficulty": 2
}
```

**What happened?**
1. ChainForge validated your input (data and difficulty)
2. Created a new block with index 1
3. Linked it to the genesis block (previous_hash)
4. Started mining (Proof of Work algorithm)
5. Tried different nonce values (0, 1, 2, ..., 142)
6. Found nonce 142 produces a hash starting with "00" (2 leading zeros)
7. Saved the block to MongoDB

**Mining explained:**
- Difficulty 2 means hash must start with "00"
- System increments nonce until hash meets requirement
- Higher difficulty = more leading zeros = more attempts = more time

## Step 4: View Your Block

```bash
curl http://localhost:1910/api/v1/chain/<blockchain_id>/block/<block_id>
```

**Response:**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block": {
    "id": "674c8b2c3e5f6a0012345679",
    "index": 1,
    "data": "Hello, Blockchain!",
    "hash": "00a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef012345678",
    "previous_hash": "genesis_block_hash_here",
    "nonce": 142,
    "difficulty": 2,
    "timestamp": 1699564821,
    "valid_hash": true
  }
}
```

**Block fields explained:**
- `index`: Block position in chain (0 = genesis, 1 = first block, etc.)
- `data`: Your stored data
- `hash`: Block's SHA256 hash (starts with "00" for difficulty 2)
- `previous_hash`: Links to previous block's hash
- `nonce`: Number that produces valid hash (142 attempts)
- `difficulty`: Mining difficulty used (2 = "00")
- `timestamp`: Unix timestamp when block was created
- `valid_hash`: Whether hash meets difficulty requirement

## Step 5: Add More Blocks

Add a second block:

```bash
curl -X POST http://localhost:1910/api/v1/chain/<blockchain_id>/block \
  -H 'Content-Type: application/json' \
  -d '{"data": "Second block data", "difficulty": 3}'
```

This time with difficulty 3 (hash must start with "000"). Mining will take longer!

**Expected mining times:**
| Difficulty | Average Time | Leading Zeros |
|-----------|-------------|---------------|
| 1-2 | < 1 second | 0 or 00 |
| 3-4 | Few seconds | 000 or 0000 |
| 5-6 | Minutes | 00000 or 000000 |
| 7+ | Hours+ | 0000000+ |

## Step 6: Validate Block Data

Verify that your block data hasn't been tampered with:

```bash
curl -X POST http://localhost:1910/api/v1/chain/<blockchain_id>/block/<block_id>/valid \
  -H 'Content-Type: application/json' \
  -d '{"data": "Hello, Blockchain!"}'
```

**Response (Valid):**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8b2c3e5f6a0012345679",
  "valid": true
}
```

**Response (Invalid - tampered data):**
```json
{
  "chain_id": "674c8a1b2e4f5a0012345678",
  "block_id": "674c8b2c3e5f6a0012345679",
  "valid": false
}
```

**What's being validated?**
- ChainForge recalculates the block's hash using the provided data
- Compares it with the stored hash
- If they match: data is unchanged (valid)
- If they don't match: data was tampered with (invalid)

## Congratulations! 🎉

You've just:
- ✅ Created a blockchain instance
- ✅ Mined your first block with Proof of Work
- ✅ Added multiple blocks with different difficulties
- ✅ Validated block data integrity
- ✅ Experienced how mining difficulty affects time

## Understanding What You Built

### Blockchain Structure

```
Blockchain ID: 674c8a1b2e4f5a0012345678
├── Block 0 (Genesis)
│   ├── index: 0
│   ├── hash: genesis_hash
│   ├── previous_hash: null
│   └── (not mined)
│
├── Block 1
│   ├── index: 1
│   ├── data: "Hello, Blockchain!"
│   ├── hash: 00a1b2c3... (starts with "00")
│   ├── previous_hash: genesis_hash
│   ├── nonce: 142
│   └── difficulty: 2
│
└── Block 2
    ├── index: 2
    ├── data: "Second block data"
    ├── hash: 000d4e5f... (starts with "000")
    ├── previous_hash: 00a1b2c3...
    ├── nonce: 1823
    └── difficulty: 3
```

### Chain Integrity

The blockchain is secure because:

1. **Hash Chaining**: Each block links to previous block's hash
2. **Proof of Work**: Each hash must meet difficulty requirement
3. **Immutability**: Changing any data invalidates the hash
4. **Cascade Effect**: Invalid hash breaks all subsequent blocks

**Example of tampering:**
```
Original Block 1: data="Hello" → hash=00abc...
Tampered Block 1: data="Goodbye" → hash=99xyz... ❌ (doesn't match stored hash)
Result: Block 1 invalid, entire chain from Block 1 onward is invalid
```

## Next Steps

### Learn More

1. [First Blockchain Tutorial](first-blockchain-tutorial.md) - Detailed walkthrough with explanations
2. [API Reference](../api/reference.md) - Complete endpoint documentation
3. [Proof of Work Deep Dive](../architecture/proof-of-work.md) - Understanding the mining algorithm

### Experiment

Try these challenges:

1. **Low Difficulty Mining**: Create blocks with difficulty 1
   ```bash
   curl -X POST http://localhost:1910/api/v1/chain/<id>/block \
     -H 'Content-Type: application/json' \
     -d '{"data": "Easy mining!", "difficulty": 1}'
   ```

2. **High Difficulty Mining**: Try difficulty 4 (will take longer)
   ```bash
   curl -X POST http://localhost:1910/api/v1/chain/<id>/block \
     -H 'Content-Type: application/json' \
     -d '{"data": "Hard mining!", "difficulty": 4}'
   ```

3. **Multiple Blockchains**: Create multiple independent blockchains
   ```bash
   curl -X POST http://localhost:1910/api/v1/chain
   curl -X POST http://localhost:1910/api/v1/chain
   ```

4. **Data Validation**: Try validating with wrong data to see `valid: false`
   ```bash
   curl -X POST http://localhost:1910/api/v1/chain/<id>/block/<bid>/valid \
     -H 'Content-Type: application/json' \
     -d '{"data": "Wrong data!"}'
   ```

### Integration Examples

Check out [API Examples](../api/examples.md) for code in:
- Python
- JavaScript (Node.js)
- Ruby
- curl scripts

## Common Questions

**Q: Can I delete blocks?**
A: No! Blockchains are append-only. You can only add new blocks.

**Q: Can I modify existing blocks?**
A: No! Blocks are immutable. Changing data invalidates the hash and breaks the chain.

**Q: Why does mining take so long with high difficulty?**
A: Higher difficulty requires more leading zeros, which is exponentially harder. Each additional zero multiplies attempts by ~16.

**Q: What happens if I use the wrong blockchain ID?**
A: You'll get a 404 error: `Blockchain not found`

**Q: Can multiple blockchains exist?**
A: Yes! Each `POST /api/v1/chain` creates an independent blockchain instance.

**Q: What's the maximum difficulty?**
A: Difficulty ranges from 1-10. Values outside this range return a validation error.

## Rate Limiting

Be aware of API rate limits:

| Endpoint | Limit | Window |
|----------|-------|--------|
| All endpoints | 60 requests | 1 minute |
| Create blockchain | 10 requests | 1 minute |
| Add block (mining) | 30 requests | 1 minute |

If you exceed limits, you'll receive:
```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```
**HTTP Status:** 429 (Too Many Requests)

## Troubleshooting

**Error:** `{"errors": {"data": ["must be filled"]}}`
**Solution:** Include `data` field in request body

**Error:** `{"errors": {"difficulty": ["must be between 1 and 10"]}}`
**Solution:** Use difficulty value between 1-10

**Error:** Connection refused
**Solution:** Verify server is running (`ruby main.rb -p 1910`)

**Error:** MongoDB connection error
**Solution:** Verify MongoDB is running (`mongosh --eval "db.version()"`)

For more issues, see [Troubleshooting Guide](../guides/troubleshooting.md).

---

**Ready to dive deeper?** Continue to the [First Blockchain Tutorial](first-blockchain-tutorial.md) for a comprehensive walkthrough with detailed explanations!
