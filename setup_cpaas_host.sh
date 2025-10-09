#!/bin/bash
# ===============================================================
#  Title   : CPaaS Host Setup Script
#  Author  : Bharat Singh
#  Purpose : Clone GitHub repo and prepare directory structure
#             for CPaaS IVR Docker stack as per docker-compose.yml
# ===============================================================

set -e  # Exit immediately if any command fails

echo "🚀 Starting CPaaS Host Setup..."

# --- Step 1: Clone GitHub Repo ---
REPO_URL="https://github.com/bhrt-singh/cpaas-docker-stack.git"
TARGET_DIR="/root/cpaas-docker-stack"

echo "📥 Cloning repository from $REPO_URL ..."
if [ -d "$TARGET_DIR" ]; then
    echo "⚠️  Directory $TARGET_DIR already exists. Pulling latest changes..."
    cd $TARGET_DIR && git pull
else
    git clone $REPO_URL $TARGET_DIR
fi

cd $TARGET_DIR
echo "✅ Repository ready at $TARGET_DIR"

# --- Step 2: Setup /root/docker directories ---
echo "📦 Setting up host directories under /root/docker..."
sudo mkdir -p /root/docker

sudo cp -r ./freeswitch ./backend ./prometheus ./grafana ./token /root/docker/

# --- Step 3: Setup /opt/caching directories ---
echo "🗂️  Preparing /opt/caching directory..."
sudo mkdir -p /opt/caching
sudo cp -r ./caching/* /opt/caching/

# --- Step 4: Adjust Permissions ---
echo "🔑 Setting permissions for Docker volumes..."
sudo chmod -R 777 /root/docker /opt/caching

echo "✅ Host directories prepared successfully!"
echo "--------------------------------------------------------------"
echo "🧩 Next Steps:"
echo "1️⃣  cd /root/cpaas-docker-stack"
echo "2️⃣  Run: docker-compose up -d"
echo "3️⃣  Verify containers: docker ps"
echo "--------------------------------------------------------------"

