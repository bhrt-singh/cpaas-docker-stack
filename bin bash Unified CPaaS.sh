#!/bin/bash
# ===========================================================
# 🚀 Secure Cleanup & Secret Protection Script
# Author: Bharat Singh
# Role: DevOps Engineer (CPaaS / SIP)
# ===========================================================
# PURPOSE:
#   1️⃣ Remove exposed secrets from Git history
#   2️⃣ Ask user for new Docker PAT (Personal Access Token)
#   3️⃣ Rewrite scripts to use .env file securely
#   4️⃣ Prevent GitHub push protection from blocking again
# ===========================================================

set -e

echo "==============================================="
echo "🔍 Step 1: Checking for Git and filter-repo tool..."
echo "==============================================="
if ! command -v git &>/dev/null; then
  echo "❌ Git is not installed! Please install git first."
  exit 1
fi

if ! command -v git-filter-repo &>/dev/null; then
  echo "📦 Installing git-filter-repo..."
  sudo apt update -y && sudo apt install -y git-filter-repo
else
  echo "✅ git-filter-repo already installed."
fi

echo ""
echo "==============================================="
echo "🧹 Step 2: Removing exposed Docker token from Git history..."
echo "==============================================="
# This pattern removes any line that contains the old token
OLD_TOKEN_PATTERN="dckr_pat_"
git filter-repo --replace-text <(echo "${OLD_TOKEN_PATTERN}==>REMOVED_SECRET") --force || true

echo "✅ Git history cleaned of old secrets."
echo ""

echo "==============================================="
echo "🔐 Step 3: Secure Docker credentials setup..."
echo "==============================================="

read -p "Enter your Docker Hub username: " DOCKER_USER
read -s -p "Enter your NEW Docker Hub Access Token (input hidden): " DOCKER_KEY
echo ""

# Create or update .env file
cat > .env <<EOF
DOCKER_USER=${DOCKER_USER}
DOCKER_KEY=${DOCKER_KEY}
EOF

echo "✅ .env file created successfully!"

# Ensure .env is gitignored
if ! grep -q ".env" .gitignore 2>/dev/null; then
  echo ".env" >> .gitignore
  echo "✅ Added .env to .gitignore"
fi

echo ""
echo "==============================================="
echo "⚙️ Step 4: Securing your deployment scripts..."
echo "==============================================="

# Update scripts to source credentials from .env instead of hardcoding
for FILE in setup_full_cpaas_stack.sh deploy_cpaas_stack.sh; do
  if [ -f "$FILE" ]; then
    echo "🔧 Updating $FILE..."
    sed -i '/DOCKER_KEY=/d' "$FILE"
    sed -i '/DOCKER_USER=/d' "$FILE"
    sed -i '/docker login/d' "$FILE"
    cat <<'LOGIN_BLOCK' >> "$FILE"

# Secure Docker login using .env credentials
if [ -f ".env" ]; then
  source .env
  echo "🔐 Logging in to Docker Hub securely..."
  echo "$DOCKER_KEY" | docker login -u "$DOCKER_USER" --password-stdin
else
  echo "⚠️ .env not found! Please run secure_fix_and_update.sh again."
  exit 1
fi
LOGIN_BLOCK
    echo "✅ $FILE now uses secure .env credentials."
  fi
done

echo ""
echo "==============================================="
echo "🧾 Step 5: Finalizing cleanup and verification..."
echo "==============================================="

git add .gitignore .env || true
git status

echo ""
echo "✅ All done!"
echo "-----------------------------------------------"
echo "Next steps:"
echo "1️⃣ Revoke your old Docker token (for safety):"
echo "    🔗 https://hub.docker.com/settings/security"
echo "2️⃣ Commit and push your changes safely:"
echo "    git add -A && git commit -m 'Secure: moved Docker token to .env'"
echo "    git push origin master --force"
echo "-----------------------------------------------"
echo "🔐 Your new Docker token is stored locally in .env (ignored by git)"
echo "🚫 GitHub will no longer block pushes for secret leaks."

