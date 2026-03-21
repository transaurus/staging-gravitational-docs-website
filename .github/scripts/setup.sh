#!/bin/bash
# Generated setup script for: https://github.com/gravitational/docs-website
# Docusaurus 3.9.2, Yarn Classic 1.22.22, Node >=22 (engines field)

set -e

REPO_URL="https://github.com/gravitational/docs-website"
BRANCH="main"

echo "[INFO] Cloning repository (no submodules - content is huge)..."
if [ -d "source-repo" ]; then
    rm -rf source-repo
fi

git clone --depth 1 --branch "$BRANCH" --no-recurse-submodules "$REPO_URL" source-repo
cd source-repo

echo "[INFO] Current Node version: $(node -v)"

# Install Node 22 via nvm (required by engines: >=22.0)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
    echo "[INFO] Installing Node 22 via nvm..."
    nvm install 22
    nvm use 22
else
    echo "[WARN] nvm not found, using system node: $(node -v)"
fi

echo "[INFO] Node version: $(node -v)"
echo "[INFO] NPM version: $(npm -v)"

# Ensure yarn classic is available
if ! command -v yarn &> /dev/null; then
    echo "[INFO] Installing yarn classic..."
    npm install -g yarn@1.22.22
fi
echo "[INFO] Yarn version: $(yarn --version)"

echo "[INFO] Installing dependencies..."
yarn install --frozen-lockfile

# Create stub files required for Docusaurus config to load
# (content submodules are not cloned, so we stub the generated files)
echo "[INFO] Creating stub files for Docusaurus config..."

# sidebars.json - required for current version (18.x is the current/default)
echo '{}' > sidebars.json

# versions.json - non-current versions (current = 19.x in docs/, others are versioned)
# getCurrentVersion() returns most recent = 19.x; versioned = 17.x, 18.x
echo '["17.x","18.x"]' > versions.json

# versioned_sidebars for non-current versions (17.x and 18.x)
mkdir -p versioned_sidebars
echo '{}' > versioned_sidebars/version-17.x-sidebars.json
echo '{}' > versioned_sidebars/version-18.x-sidebars.json

# Create docs directory (current version docs = 19.x) with stub doc
mkdir -p docs
echo '# Placeholder' > docs/index.mdx

# Create versioned_docs directories with stub docs
mkdir -p versioned_docs/version-17.x
echo '# Placeholder' > versioned_docs/version-17.x/index.mdx
mkdir -p versioned_docs/version-18.x
echo '# Placeholder' > versioned_docs/version-18.x/index.mdx

# Create data directory (for navbar/events JSON if referenced)
mkdir -p data
echo '{}' > data/navbar.json
echo '[]' > data/events.json

# Create stub content configs to satisfy loadConfig calls
# (config-docs.ts reads content/<version>/docs/config.json for redirects/variables)
# Current = 19.x (docs/), versioned = 17.x, 18.x
for VERSION in 17.x 18.x 19.x; do
    mkdir -p "content/${VERSION}/docs"
    echo '{}' > "content/${VERSION}/docs/config.json"
    mkdir -p "content/${VERSION}/docs/pages"
done

# Set up .env from .env.example (Sanity config - not critical for write-translations)
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    cp .env.example .env
fi

echo "[INFO] Running write-translations..."
yarn write-translations

echo "[INFO] Verifying i18n output..."
if [ -d "i18n" ]; then
    find i18n -type f -name "*.json" | head -20
    COUNT=$(find i18n -type f -name "*.json" | wc -l)
    echo "[INFO] Generated $COUNT JSON files"
else
    echo "[ERROR] i18n directory not found"
    exit 1
fi

echo "[INFO] Setup completed successfully!"
