# Installation Guide

This guide will walk you through installing ChainForge and all its dependencies on your local machine.

## Prerequisites

Before installing ChainForge, ensure you have the following installed:

### Required Software

- **Ruby 3.2.2** - Programming language
- **MongoDB** - Database for storing blockchain data
- **Git** - Version control (for cloning the repository)
- **Bundler** - Ruby dependency manager

### Optional Software

- **Docker** - For containerized deployment (recommended for beginners)
- **Docker Compose** - For multi-container orchestration
- **rbenv** or **rvm** - Ruby version managers (recommended)

## Installation Methods

Choose one of the following installation methods:

### Method 1: Docker Installation (Recommended for Beginners)

Docker provides the easiest installation path with minimal configuration.

#### Step 1: Install Docker

**macOS:**
```bash
# Install Docker Desktop
brew install --cask docker

# Start Docker Desktop application
open -a Docker
```

**Linux (Ubuntu/Debian):**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

**Windows:**
Download and install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop)

#### Step 2: Clone the Repository

```bash
git clone https://github.com/Perafan18/chain_forge.git
cd chain_forge
```

#### Step 3: Start the Application

```bash
# Start both ChainForge and MongoDB
docker-compose up

# Or run in detached mode (background)
docker-compose up -d
```

The application will be available at `http://localhost:1910`.

#### Verify Installation

```bash
# Test the application
curl http://localhost:1910

# Should return: "Hello to ChainForge!"
```

**That's it!** Skip to the [Quick Start Tutorial](quick-start.md) to create your first blockchain.

---

### Method 2: Local Installation (For Developers)

For developers who want to modify the code or run tests locally.

#### Step 1: Install Ruby 3.2.2

**Using rbenv (Recommended):**

```bash
# Install rbenv
brew install rbenv ruby-build  # macOS
# or
sudo apt install rbenv         # Linux

# Install Ruby 3.2.2
rbenv install 3.2.2

# Set Ruby version for this project
cd chain_forge
rbenv local 3.2.2

# Verify installation
ruby -v
# Should output: ruby 3.2.2
```

**Using rvm:**

```bash
# Install rvm
curl -sSL https://get.rvm.io | bash -s stable

# Install Ruby 3.2.2
rvm install 3.2.2

# Use Ruby 3.2.2
rvm use 3.2.2

# Verify installation
ruby -v
```

#### Step 2: Install MongoDB

**macOS:**

```bash
# Install MongoDB
brew tap mongodb/brew
brew install mongodb-community

# Start MongoDB service
brew services start mongodb-community

# Verify MongoDB is running
mongosh --eval "db.version()"
```

**Linux (Ubuntu/Debian):**

```bash
# Import MongoDB public key
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Install MongoDB
sudo apt update
sudo apt install -y mongodb-org

# Start MongoDB service
sudo systemctl start mongod
sudo systemctl enable mongod

# Verify MongoDB is running
mongosh --eval "db.version()"
```

**Windows:**

Download and install [MongoDB Community Server](https://www.mongodb.com/try/download/community)

#### Step 3: Clone the Repository

```bash
git clone https://github.com/Perafan18/chain_forge.git
cd chain_forge
```

#### Step 4: Install Ruby Dependencies

```bash
# Install Bundler if not already installed
gem install bundler

# Install project dependencies
bundle install
```

This will install:
- Sinatra (web framework)
- Mongoid (MongoDB ODM)
- RSpec (testing framework)
- RuboCop (code linter)
- Rack::Attack (rate limiting)
- dry-validation (input validation)
- And other dependencies

#### Step 5: Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env
```

Edit `.env` with your preferred text editor:

```bash
# .env file
MONGO_DB_NAME=chain_forge
MONGO_DB_HOST=localhost
MONGO_DB_PORT=27017
ENVIRONMENT=development
DEFAULT_DIFFICULTY=2
```

**Configuration Options:**

| Variable | Description | Default | Valid Values |
|----------|-------------|---------|--------------|
| `MONGO_DB_NAME` | Database name | chain_forge | Any string |
| `MONGO_DB_HOST` | MongoDB hostname | localhost | localhost, IP, hostname |
| `MONGO_DB_PORT` | MongoDB port | 27017 | 1-65535 |
| `ENVIRONMENT` | Runtime environment | development | development, test, production |
| `DEFAULT_DIFFICULTY` | Mining difficulty | 2 | 1-10 |

#### Step 6: Verify Installation

```bash
# Check Ruby version
ruby -v
# Should output: ruby 3.2.2

# Check MongoDB connection
mongosh --eval "db.version()"
# Should output MongoDB version

# Check bundle dependencies
bundle check
# Should output: "The Gemfile's dependencies are satisfied"
```

#### Step 7: Run the Application

```bash
# Start the server
ruby main.rb -p 1910
```

You should see output like:
```
== Sinatra (v4.0.0) has taken the stage on 1910 for development with backup from Puma
Puma starting in single mode...
* Listening on http://0.0.0.0:1910
```

#### Step 8: Test the Installation

Open a new terminal and run:

```bash
# Test basic connectivity
curl http://localhost:1910

# Should return: "Hello to ChainForge!"

# Create a test blockchain
curl -X POST http://localhost:1910/api/v1/chain

# Should return: {"id":"<blockchain_id>"}
```

---

## Troubleshooting

### Ruby Version Issues

**Error:** `Ruby version is not 3.2.2`

**Solution:**
```bash
# Using rbenv
rbenv install 3.2.2
rbenv local 3.2.2

# Using rvm
rvm install 3.2.2
rvm use 3.2.2
```

### MongoDB Connection Issues

**Error:** `Failed to connect to MongoDB`

**Solution:**
```bash
# Check if MongoDB is running
mongosh --eval "db.version()"

# If not running, start it:
# macOS
brew services start mongodb-community

# Linux
sudo systemctl start mongod

# Docker
docker-compose up mongodb
```

**Error:** `Connection refused on port 27017`

**Solution:**
- Verify MongoDB is running on the correct port
- Check your `.env` file has the correct `MONGO_DB_HOST` and `MONGO_DB_PORT`
- For Docker: Use `MONGO_DB_HOST=mongodb` instead of `localhost`

### Bundle Install Issues

**Error:** `An error occurred while installing <gem>`

**Solution:**
```bash
# Update RubyGems
gem update --system

# Update Bundler
gem install bundler

# Try again
bundle install
```

### Port Already in Use

**Error:** `Address already in use - bind(2) for "0.0.0.0" port 1910`

**Solution:**
```bash
# Find process using port 1910
lsof -ti:1910

# Kill the process
kill -9 $(lsof -ti:1910)

# Or use a different port
ruby main.rb -p 3000
```

### Permission Denied Errors

**Error:** `Permission denied`

**Solution:**
```bash
# Linux/macOS: Don't use sudo with gem/bundle
# Instead, configure bundler to install gems in user directory

bundle config set --local path 'vendor/bundle'
bundle install
```

## Verification Checklist

Before proceeding to the Quick Start tutorial, verify:

- [ ] Ruby 3.2.2 is installed: `ruby -v`
- [ ] MongoDB is running: `mongosh --eval "db.version()"`
- [ ] Dependencies are installed: `bundle check`
- [ ] Environment is configured: `.env` file exists
- [ ] Application starts: `ruby main.rb -p 1910`
- [ ] Basic connectivity works: `curl http://localhost:1910`

## Next Steps

Now that ChainForge is installed, proceed to:

1. [Quick Start Tutorial](quick-start.md) - Create your first blockchain in 5 minutes
2. [First Blockchain Tutorial](first-blockchain-tutorial.md) - Complete walkthrough with mining
3. [API Reference](../api/reference.md) - Learn the available endpoints

## Additional Resources

- [Development Setup Guide](../guides/development-setup.md) - For contributors and developers
- [Deployment Guide](../guides/deployment-guide.md) - For production deployment
- [Troubleshooting Guide](../guides/troubleshooting.md) - Common issues and solutions

---

**Need help?** Check the [Troubleshooting Guide](../guides/troubleshooting.md) or open an issue on GitHub.
