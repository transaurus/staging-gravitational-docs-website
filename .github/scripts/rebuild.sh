#!/usr/bin/env bash
set -euo pipefail

# rebuild.sh for gravitational/docs-website
# Runs on existing source tree (no clone). Installs deps, runs pre-build steps, builds.
# Does NOT run write-translations.

# --- Node version ---
echo "[INFO] Current Node version: $(node -v)"
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

# --- Package manager ---
if ! command -v yarn &> /dev/null; then
    echo "[INFO] Installing yarn classic..."
    npm install -g yarn@1.22.22
fi
echo "[INFO] Yarn version: $(yarn --version)"

# --- Dependencies ---
echo "[INFO] Installing dependencies..."
yarn install --frozen-lockfile

# --- .env setup ---
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    cp .env.example .env
fi

# --- Stub files required before docusaurus commands ---
echo "[INFO] Creating stub files for Docusaurus config..."

# sidebars.json - required for current version (19.x is current/default)
echo '{}' > sidebars.json

# versions.json - non-current versions (current = 19.x; versioned = 17.x, 18.x)
echo '["18.x","17.x"]' > versions.json

# versioned_sidebars for non-current versions
mkdir -p versioned_sidebars
echo '{}' > versioned_sidebars/version-17.x-sidebars.json
echo '{}' > versioned_sidebars/version-18.x-sidebars.json

# docs directory (current version 19.x) with stub doc
mkdir -p docs
echo '# Placeholder' > docs/index.mdx

# versioned_docs directories with stub docs
mkdir -p versioned_docs/version-17.x
echo '# Placeholder' > versioned_docs/version-17.x/index.mdx
mkdir -p versioned_docs/version-18.x
echo '# Placeholder' > versioned_docs/version-18.x/index.mdx

# data directory (navbar/events JSON - populated by prepare-navigation-data)
mkdir -p data
echo '{}' > data/navbar.json
echo '[]' > data/events.json

# content configs and sidebars for all versions
for VERSION in 17.x 18.x 19.x; do
    mkdir -p "content/${VERSION}/docs"
    echo '{}' > "content/${VERSION}/docs/config.json"
    echo '{}' > "content/${VERSION}/docs/sidebar.json"
    mkdir -p "content/${VERSION}/docs/pages"
done

# 18.x default: prepare-files.mts copies upcoming-releases.mdx to other versions
echo '# Upcoming Releases' > content/18.x/docs/pages/upcoming-releases.mdx

# Stub docs so prepare-files.mts creates the version subdirs
echo '# Placeholder' > content/17.x/docs/pages/index.mdx
echo '# Placeholder' > content/19.x/docs/pages/index.mdx

# --- Build ---
# Skip yarn build (includes git-update which requires real submodules)
# Run prepare-files + prepare-navigation-data (falls back to stubs) + docusaurus build
echo "[INFO] Building..."
yarn prepare-files && yarn prepare-navigation-data && npx docusaurus build

echo "[DONE] Build complete."
