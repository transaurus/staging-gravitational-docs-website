#!/usr/bin/env bash
set -euo pipefail

# prepare.sh for gravitational/docs-website
# Docusaurus 3.9.2, Yarn Classic 1.22.22, Node >=22
# Clones repo, installs deps, creates stub files needed before docusaurus commands.
# Does NOT run write-translations or build.

REPO_URL="https://github.com/gravitational/docs-website"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    echo "[INFO] Cloning repository (no submodules - content is huge)..."
    git clone --depth 1 --branch "$BRANCH" --no-recurse-submodules "$REPO_URL" "$REPO_DIR"
else
    echo "[INFO] $REPO_DIR already exists, skipping clone."
fi

cd "$REPO_DIR"

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
# config.json: config-docs.ts validates these; schema allows empty {}
# sidebar.json: prepare-files.mts copies these to versioned_sidebars/ and sidebars.json
for VERSION in 17.x 18.x 19.x; do
    mkdir -p "content/${VERSION}/docs"
    echo '{}' > "content/${VERSION}/docs/config.json"
    echo '{}' > "content/${VERSION}/docs/sidebar.json"
    mkdir -p "content/${VERSION}/docs/pages"
done

# 18.x is the default version; prepare-files.mts copies upcoming-releases.mdx
# from content/18.x/docs/pages/ to versioned_docs/version-17.x/ and docs/ (19.x).
# Without this file, copyFileSync throws ENOENT and the build fails.
echo '# Upcoming Releases' > content/18.x/docs/pages/upcoming-releases.mdx

# prepare-files.mts deletes versioned_docs/ and only creates version subdirs when
# copying MDX files from content/<ver>/docs/pages/. If pages/ is empty,
# the version subdir is never created and the subsequent copyFileSync(tags.yml) fails.
echo '# Placeholder' > content/17.x/docs/pages/index.mdx
echo '# Placeholder' > content/19.x/docs/pages/index.mdx

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

echo "[DONE] Repository is ready for docusaurus commands."
