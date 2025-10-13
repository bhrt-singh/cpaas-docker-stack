#!/bin/bash
# ===========================================================
# 🤖 Robo Docker Recovery v2 + 🚀 Unified CPaaS Deployment
# Author: Bharat Singh
# Role: DevOps Engineer (SIP / CPaaS)
# ===========================================================

set -euo pipefail


# ===========================================================
# 🤖 ROBO DOCKER RECOVERY v2 SECTION (DO NOT MODIFY)
# ===========================================================

# Run as root check
if [ "$(id -u)" -ne 0 ]; then
  echo "❗ Please run as root or with sudo."
  exit 1
fi

echo "==============================================="
echo "🤖 Robo Docker Recovery v2 — starting"
echo "==============================================="

# Helper to print and run but continue on non-fatal commands
run() { echo "+ $*"; "$@"; }

# 1) Check systemd availability (docker requires systemd for service)
if ! command -v systemctl &>/dev/null; then
  echo "⚠️  systemctl not found. This script expects systemd-managed system."
  echo "Please run recovery on a systemd-based distro (Ubuntu, Debian with systemd)."
  exit 1
fi

# 2) Check if root filesystem is read-only; attempt remount rw if so
echo "🔍 Checking root filesystem mount mode..."
ROOT_RO_OPTIONS=$(findmnt -no OPTIONS / || true)
if echo "$ROOT_RO_OPTIONS" | grep -q "ro"; then
  echo "🚨 Root filesystem appears READ-ONLY (options: $ROOT_RO_OPTIONS). Attempting to remount read-write..."
  if mount -o remount,rw /; then
    echo "✅ Remounted / as read-write."
  else
    echo "❌ Failed to remount / as read-write. Please investigate (disk errors, fsck, cloud readonly mounts)."
    exit 1
  fi
else
  echo "✅ Root filesystem is writable."
fi

# 3) Ensure prerequisites exist
echo "📦 Installing prerequisites (ca-certificates, curl, gnupg, lsb-release, apt-transport-https)..."
apt update -y
apt install -y ca-certificates curl gnupg lsb-release apt-transport-https || true

# 4) Check if docker daemon unit exists
DOCKER_UNIT="/lib/systemd/system/docker.service"
if [ ! -f "$DOCKER_UNIT" ]; then
  echo "⚠️  docker.service unit not found at $DOCKER_UNIT. Will (re)install Docker Engine packages."
  NEED_REINSTALL=1
else
  NEED_REINSTALL=0
  echo "✅ docker.service unit exists."
fi

# 5) Quick check: does dockerd binary exist and docker info succeed?
DOCKER_BIN_OK=0
if command -v dockerd &>/dev/null; then
  echo "🔍 dockerd binary found: $(command -v dockerd)"
  if docker info >/dev/null 2>&1; then
    echo "✅ docker info responded (daemon appears healthy)."
    DOCKER_BIN_OK=1
  else
    echo "⚠️ docker CLI present but daemon not responding."
    DOCKER_BIN_OK=0
  fi
else
  echo "⚠️ dockerd binary not found on PATH."
  DOCKER_BIN_OK=0
fi

# 6) If reinstall required or daemon not responding, (re)install official Docker packages
if [ "$NEED_REINSTALL" -eq 1 ] || [ "$DOCKER_BIN_OK" -eq 0 ]; then
  echo "🧩 Installing / reinstalling Docker Engine from official repo..."

  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || {
    echo "❗ Failed to fetch Docker GPG key. Check network."
    exit 1
  }

  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

  apt update -y
  DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    docker-ce docker-ce-cli containerd.io docker-compose-plugin || {
      echo "❌ Failed to install docker packages. Showing apt logs..."
      grep -i -E "error|failed" /var/log/apt/term.log || true
      exit 1
    }

  systemctl daemon-reload || true
  systemctl enable containerd --now || true
  systemctl enable docker || true

  if systemctl start docker; then
    echo "✅ docker.service started."
  else
    echo "⚠️ docker.service failed to start. Inspecting logs..."
    journalctl -u docker --no-pager -n 200 || true
  fi
fi

# 7) Ensure /var/lib/docker exists and has correct perms
echo "🔍 Ensuring Docker data directory exists (/var/lib/docker)..."
if [ ! -d /var/lib/docker ]; then
  echo "⚠️ /var/lib/docker missing — creating..."
  mkdir -p /var/lib/docker
fi
chown root:root /var/lib/docker
chmod 711 /var/lib/docker
echo "✅ /var/lib/docker OK."

# 8) Ensure /opt is writable (this is where your compose mounts use /opt/caching)
echo "🔍 Ensuring /opt and /opt/caching exist and are writable..."
if [ ! -d /opt ]; then
  echo "⚠️ /opt missing — creating..."
  mkdir -p /opt
fi
if [ ! -w /opt ]; then
  echo "⚠️ /opt not writable — attempting chmod 755 /opt"
  chmod 755 /opt || true
fi
if [ ! -d /opt/caching ]; then
  echo "➕ Creating /opt/caching directory..."
  mkdir -p /opt/caching || {
    echo "❌ Failed to create /opt/caching. Attempting to remount root as rw and retry..."
    mount -o remount,rw / || {
      echo "❌ Remount rw failed. Manual intervention required."
      exit 1
    }
    mkdir -p /opt/caching || {
      echo "❌ Still failed to create /opt/caching. Manual check needed."
      exit 1
    }
  }
fi
chown root:root /opt/caching
chmod 755 /opt/caching
echo "✅ /opt and /opt/caching ready."

# 9) /var/run/docker.sock should be a socket, not a directory
if [ -e /var/run/docker.sock ] && [ ! -S /var/run/docker.sock ]; then
  echo "⚠️ /var/run/docker.sock exists but is not a socket. Backing up and removing..."
  mv /var/run/docker.sock /var/run/docker.sock.bak_$(date +%s) || true
fi
if [ ! -e /var/run/docker.sock ]; then
  echo "ℹ️ /var/run/docker.sock not present yet (will be created by dockerd)."
fi

# 10) Restart Docker & containerd to pick up fixes
echo "🔁 Restarting containerd and docker services..."
systemctl restart containerd || true
systemctl restart docker || true
sleep 3

# 11) Validate docker daemon
echo "🔍 Validating Docker daemon with 'docker info'..."
if docker info >/dev/null 2>&1; then
  echo "✅ Docker daemon is responding."
else
  echo "❌ docker info failed. Dumping docker and containerd logs for diagnosis:"
  journalctl -u docker --no-pager -n 200 || true
  journalctl -u containerd --no-pager -n 200 || true
  echo "❗ Docker daemon still not healthy. Manual intervention required."
  exit 1
fi

# 12) Show version and basic summary
echo "🐳 Docker version: $(docker --version 2>/dev/null || echo 'n/a')"
echo "🧾 Docker Compose version: $(docker compose version 2>/dev/null || echo 'n/a')"
echo "🧭 Docker server summary (storage/driver):"
docker info --format 'Server: {{.ServerVersion}} / StorageDriver: {{.Driver}}' || true

echo "==============================================="
echo "🎯 Robo Docker Recovery v2 completed successfully."
echo "You can now re-run your deployment. If you still see mount errors,"
echo "check kernel-level mount policies (cloud images may mount /opt as read-only),"
echo "and check 'df -h' and 'mount' output."
echo "==============================================="


# ===========================================================
# 🚀 UNIFIED CPAAS DEPLOYMENT SECTION (UNTOUCHED)
# ===========================================================

#!/bin/bash
# ===========================================================
# 🚀 Unified CPaaS Deployment Script (with Robo MongoDB Recovery + Tenant Domain Update + Service Log Capture)
# Author: Bharat Singh
# Role: DevOps Engineer (SIP / CPaaS)
# ===========================================================

set -e

# ---------------------------------------------
# 🧩 STEP 1: Install Dependencies
# ---------------------------------------------
echo "==============================================="
echo "📦 Installing Docker, Compose, and useful tools..."
echo "==============================================="

sudo apt update -y
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release jq net-tools htop vim git

if ! command -v docker &>/dev/null; then
  echo "🐳 Installing Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update -y
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "✅ Docker already installed."
fi

docker --version
docker compose version || echo "⚠️ Docker Compose plugin not found."

# ---------------------------------------------
# 🧩 STEP 2: Clone CPaaS Repository (Public)
# ---------------------------------------------
REPO_URL="https://github.com/bhrt-singh/cpaas-docker-stack.git"
REPO_DIR="/root/cpaas-docker-stack"

echo "==============================================="
echo "📂 Preparing CPaaS repository..."
echo "==============================================="

rm -f ~/.git-credentials /root/.git-credentials 2>/dev/null || true
git config --global --unset credential.helper 2>/dev/null || true
git config --system --unset credential.helper 2>/dev/null || true
git config --global --unset-all user.name 2>/dev/null || true
git config --global --unset-all user.email 2>/dev/null || true

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=true
unset SSH_ASKPASS
unset GIT_CRED_HELPER

if [ -d "$REPO_DIR" ]; then
  echo "🗑️ Removing existing repo directory: $REPO_DIR"
  rm -rf "$REPO_DIR"
fi

echo "🚀 Cloning fresh repository..."
git -c credential.helper= -c core.askPass=true clone "$REPO_URL" "$REPO_DIR" --depth=1 || {
  echo "❌ Git clone failed!"; exit 1;
}

cd "$REPO_DIR"
echo "✅ Repository cloned successfully."

# ---------------------------------------------
# 🧩 STEP 3: Docker Hub Login
# ---------------------------------------------
echo "==============================================="
echo "🔐 Logging in to Docker Hub..."
echo "==============================================="

login_attempts=0; max_attempts=3
while [ $login_attempts -lt $max_attempts ]; do
  read -p "Enter Docker username: " DOCKER_USER
  read -s -p "Enter Docker Access Token (hidden): " DOCKER_KEY; echo
  if echo "$DOCKER_KEY" | docker login -u "$DOCKER_USER" --password-stdin; then
    echo "✅ Docker login successful."
    break
  else
    echo "❌ Login failed, please try again."
    ((login_attempts++))
  fi
  [ $login_attempts -eq $max_attempts ] && echo "🚫 Too many login failures, exiting." && exit 1
done

# ---------------------------------------------
# 🧱 STEP 4: Prepare Directory Structure
# ---------------------------------------------
echo "==============================================="
echo "🗂 Creating directory structure for docker volumes..."
echo "==============================================="

mkdir -p /root/docker/backend/opt
mkdir -p /root/docker/certs
mkdir -p /root/docker/freeswitch
mkdir -p /opt/caching/upload/en

echo "✅ Directories created."

# ---------------------------------------------
# 🧩 STEP 5: Copy Files to Mounted Paths
# ---------------------------------------------
echo "==============================================="
echo "📦 Syncing repository files to host mount paths..."
echo "==============================================="

cp -r backend/opt/* /root/docker/backend/opt/ 2>/dev/null || true
cp -r backend/certs/* /root/docker/certs/ 2>/dev/null || true
cp -r freeswitch/* /root/docker/freeswitch/ 2>/dev/null || true
cp -r caching/* /opt/caching/ 2>/dev/null || true
cp -r certs/* /root/docker/certs/ 2>/dev/null || true

echo "✅ Files copied to runtime directories."

# ---------------------------------------------
# 🧠 STEP 6: Update docker-compose.yml
# ---------------------------------------------
echo "==============================================="
echo "🧠 Updating docker-compose.yml configuration..."
echo "==============================================="

read -p "🌐 Enter new domain (e.g. xcess-demo-cc.local): " NEW_DOMAIN
read -p "🖥️  Enter new IP for DOMAIN_NAME (e.g. 192.168.25.99): " NEW_IP

if [[ -z "$NEW_DOMAIN" || -z "$NEW_IP" ]]; then
  echo "❌ Both domain and IP are required."
  exit 1
fi

BACKUP_FILE="docker-compose.yml.bak_$(date +%F_%H-%M-%S)"
cp docker-compose.yml "$BACKUP_FILE"
echo "🗂 Backup created: $BACKUP_FILE"

sed -i \
  -e "s|NEXT_PUBLIC_SITE_URL=https://[^[:space:]]*:5000|NEXT_PUBLIC_SITE_URL=https://$NEW_DOMAIN:5000|g" \
  -e "s|BASE_URL=https://[^[:space:]]*:5000|BASE_URL=https://$NEW_DOMAIN:5000|g" \
  -e "s|WSS_URL=wss://[^[:space:]]*:7443|WSS_URL=wss://$NEW_DOMAIN:7443|g" \
  -e "s|DOMAIN_NAME=.*|DOMAIN_NAME=$NEW_IP|g" \
  docker-compose.yml

grep -E 'NEXT_PUBLIC_SITE_URL|BASE_URL|WSS_URL|DOMAIN_NAME' docker-compose.yml
cp docker-compose.yml /root/

echo "✅ docker-compose.yml updated and copied to /root"

# ---------------------------------------------
# 🧩 STEP 7: Start MongoDB Only (with Robo Recovery)
# ---------------------------------------------
echo "==============================================="
echo "🍃 Starting MongoDB service only..."
echo "==============================================="

cd /root
if ! docker compose up -d mongo; then
  echo "❌ MongoDB startup failed due to conflict or error. Triggering Robo Recovery..."
  
  echo "==============================================="
  echo "🤖 RoboScript: MongoDB Container Conflict Resolver"
  echo "==============================================="

  cd /root || { echo "❌ Cannot find /root directory!"; exit 1; }

  if [ ! -f "/root/docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found at /root"
    exit 1
  fi

  EXISTING_MONGO=$(docker ps -a --filter "name=ivr-mongo-container" --format "{{.ID}}")

  if [ -n "$EXISTING_MONGO" ]; then
    echo "⚠️  Existing MongoDB container detected (ID: $EXISTING_MONGO)"
    echo "🧹 Stopping and removing old MongoDB container..."
    docker stop "$EXISTING_MONGO" >/dev/null 2>&1 || true
    docker rm -f "$EXISTING_MONGO" >/dev/null 2>&1 || true
    echo "✅ Old MongoDB container removed."
  else
    echo "✅ No existing MongoDB container found."
  fi

  echo "🧽 Cleaning up dangling Docker networks & volumes..."
  docker network prune -f >/dev/null 2>&1 || true
  docker volume prune -f >/dev/null 2>&1 || true
  echo "✅ Cleanup complete."

  echo "🍃 Starting MongoDB container fresh..."
  docker compose up -d mongo || { echo "❌ Failed to start MongoDB."; exit 1; }

  sleep 8
fi

MONGO_CONTAINER=$(docker compose ps -q mongo)
if [ -z "$MONGO_CONTAINER" ]; then
  echo "❌ MongoDB container not found. Exiting..."
  exit 1
fi

STATUS=$(docker inspect --format='{{.State.Status}}' $MONGO_CONTAINER 2>/dev/null || echo "none")
if [ "$STATUS" != "running" ]; then
  echo "❌ MongoDB failed to start!"
  docker compose logs mongo | tail -n 50
  exit 1
else
  echo "✅ MongoDB container is running successfully."
fi

# ---------------------------------------------
##!/bin/bash
# 🧩 STEP 6: Update MongoDB Tenant Domain Automatically (Compatible with MongoDB 4.4.29)
# --------------------------------------------------------------------------------------

echo "==============================================="
echo "🧠 Updating tenant domain in MongoDB (v4.4.29)..."
echo "==============================================="

CONTAINER_NAME="ivr-mongo-container"
MONGO_USER="mongoadmin"
MONGO_PASS="secret"
MONGO_DB="db_pbxcc"
MONGO_URI="mongodb://${MONGO_USER}:${MONGO_PASS}@127.0.0.1:27017/${MONGO_DB}?authSource=admin"

# 💤 Smart wait loop: poll Mongo readiness
echo "⏳ Waiting for MongoDB to become ready (max 30 seconds)..."
WAIT_TIME=0
MAX_WAIT=30
READY=false

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
  if docker exec "$CONTAINER_NAME" mongo --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo "✅ MongoDB is ready after ${WAIT_TIME}s."
    READY=true
    break
  fi
  echo "⌛ MongoDB not yet ready... waiting 3 seconds..."
  sleep 3
  WAIT_TIME=$((WAIT_TIME+3))
done

if [ "$READY" = false ]; then
  echo "❌ MongoDB did not respond within $MAX_WAIT seconds."
  docker compose logs mongo | tail -n 30
  exit 1
fi

# 🧠 Perform tenant domain update with retry logic
echo "✏️  Attempting to update domain field for tenant 'demo' in MongoDB..."

MAX_RETRIES=3
RETRY_DELAY=5
RETRY_COUNT=0
UPDATE_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "🌀 Update attempt $((RETRY_COUNT+1)) of $MAX_RETRIES..."
  
  if docker exec -i "$CONTAINER_NAME" bash -c "
  mongo \"${MONGO_URI}\" --quiet --eval '
    var result = db.tenant.updateOne(
      { username: \"demo\" },
      { \$set: { domain: \"${NEW_IP}\" } }
    );
    if (result.matchedCount == 1) { printjson(result); quit(0); } else { quit(1); }
  '" >/dev/null 2>&1; then
    UPDATE_SUCCESS=true
    break
  else
    echo "⚠️  Update attempt $((RETRY_COUNT+1)) failed. Retrying in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
    RETRY_COUNT=$((RETRY_COUNT+1))
  fi
done

if [ "$UPDATE_SUCCESS" = true ]; then
  echo "✅ Tenant domain successfully updated to: ${NEW_IP}"
else
  echo "❌ All update attempts failed after $MAX_RETRIES retries."
  docker compose logs mongo | tail -n 50
  exit 1
fi

echo "==============================================="
echo "📊 Domain update step completed successfully."
echo "==============================================="



# ---------------------------------------------
# 🧩 STEP 7: Bring Up Remaining Services + Capture Latest Logs (with Auto Robo Conflict Fix)
# ---------------------------------------------
echo "==============================================="
echo "🚀 Starting remaining CPaaS services..."
echo "==============================================="

LOG_DIR="/root/cpaas_logs_$(date +%F_%H-%M-%S)"
mkdir -p "$LOG_DIR"

SERVICES=$(docker compose config --services | grep -v '^mongo$')

for SERVICE in $SERVICES; do
  echo ""
  echo "🔸 Starting service: $SERVICE"

  # Check if container with same name already exists
  CONFLICT_CONTAINER=$(docker ps -a --filter "name=ivr-${SERVICE}-container" --format "{{.ID}}")
  if [ -n "$CONFLICT_CONTAINER" ]; then
    echo "⚠️ Conflict detected! Container 'ivr-${SERVICE}-container' already exists."
    echo "🤖 Activating Robo Fix for $SERVICE..."

    docker stop "$CONFLICT_CONTAINER" >/dev/null 2>&1 || true
    docker rm -f "$CONFLICT_CONTAINER" >/dev/null 2>&1 || true
    echo "✅ Old container for $SERVICE removed."

    # Optional: prune old dangling networks/volumes
    docker network prune -f >/dev/null 2>&1 || true
    docker volume prune -f >/dev/null 2>&1 || true
    echo "🧹 Cleanup complete. Retrying container startup..."
  fi

  # Try to start service again
  docker compose up -d "$SERVICE" || {
    echo "❌ Failed to start service: $SERVICE even after recovery."
    continue
  }

  sleep 5
  CONTAINER_ID=$(docker compose ps -q "$SERVICE")
  STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_ID" 2>/dev/null || echo "none")

  if [ "$STATUS" == "running" ]; then
    echo "✅ $SERVICE is running successfully after Robo check."
  else
    echo "⚠️ $SERVICE may have failed to start. Check logs."
  fi

  docker compose logs "$SERVICE" > "$LOG_DIR/${SERVICE}.full.log" 2>&1
  tail -n 100 "$LOG_DIR/${SERVICE}.full.log" > "$LOG_DIR/${SERVICE}_latest.log"
  echo "🧾 Logs saved:"
  echo "   • Full log:    $LOG_DIR/${SERVICE}.full.log"
  echo "   • Last 100 ln: $LOG_DIR/${SERVICE}_latest.log"
done

# ------------------------------------------------
# 🗂️ Capture latest 100 lines from all running containers
# ------------------------------------------------
echo ""
echo "==============================================="
echo "📦 Capturing latest 100 log lines for all running containers..."
echo "==============================================="

ALL_CONTAINERS=$(docker ps --format '{{.Names}}')
for C in $ALL_CONTAINERS; do
  SAFE_NAME=$(echo "$C" | tr '/' '_' | tr ':' '_')
  echo "🪶 Saving logs for container: $C"
  docker logs --tail 100 "$C" &> "$LOG_DIR/${SAFE_NAME}_latest.log" || true
done

echo ""
echo "✅ All logs (latest 100 lines) captured under: $LOG_DIR"
echo "==============================================="
echo "🎯 All services initialized successfully (with Robo Conflict Handling)."
echo "==============================================="


# ---------------------------------------------
# ⚙️ STEP 8: Permissions
# ---------------------------------------------
echo "🔧 Setting permissions..."
chown -R root:root /root/docker /opt/caching
chmod -R 755 /root/docker /opt/caching

# ---------------------------------------------
# 🧾 STEP 9: Verification
# ---------------------------------------------
echo "==============================================="
echo "🧾 Final Structure Preview (Top 40 lines)"
echo "==============================================="
command -v tree >/dev/null 2>&1 || apt install tree -y >/dev/null 2>&1
tree /root/docker /opt/caching | head -n 40

# ---------------------------------------------
# 🎯 STEP 10: Completion Message
# ---------------------------------------------
echo "==============================================="
echo "🎉 CPaaS Deployment Setup Complete!"
echo "✅ Docker and dependencies installed"
echo "✅ Docker Hub login successful"
echo "✅ Repo cloned and directories synced"
echo "✅ MongoDB container started"
echo "✅ Tenant domain updated in MongoDB"
echo "✅ All other services started successfully"
echo "📦 Logs saved in: $LOG_DIR"
echo "📍 docker-compose.yml is ready at: /root/docker-compose.yml"
echo "👉 Next Step: cd /root && docker compose ps"
echo "==============================================="


# ---------------------------------------------
# 🧩 STEP 11: Smart Cleanup (Non-Destructive)
# ---------------------------------------------
echo ""
echo "==============================================="
echo "🧹 Smart Docker Cleanup — Safe Mode (Keep Running Containers)"
echo "==============================================="

# 1️⃣ Remove stopped containers only
STOPPED_CONTAINERS=$(docker ps -aq -f status=exited)
if [ -n "$STOPPED_CONTAINERS" ]; then
  echo "🧱 Removing stopped containers..."
  docker rm -f $STOPPED_CONTAINERS >/dev/null 2>&1 || true
else
  echo "✅ No stopped containers found."
fi

# 2️⃣ Remove dangling (untagged) images
DANGLING_IMAGES=$(docker images -f "dangling=true" -q)
if [ -n "$DANGLING_IMAGES" ]; then
  echo "🗑️ Removing dangling Docker images..."
  docker rmi -f $DANGLING_IMAGES >/dev/null 2>&1 || true
else
  echo "✅ No dangling images found."
fi

# 3️⃣ Prune unused Docker networks (safe, won’t touch active)
echo "🌐 Cleaning unused Docker networks..."
docker network prune -f >/dev/null 2>&1 || true

# 4️⃣ Remove unused volumes (safe mode)
echo "💾 Removing unused volumes..."
docker volume prune -f >/dev/null 2>&1 || true

# 5️⃣ Clean up build caches (Compose/BuildKit)
echo "🧰 Pruning build cache..."
docker builder prune -af >/dev/null 2>&1 || true

# 6️⃣ Clean temp directories (host-level)
echo "🧹 Cleaning temporary directories..."
find /tmp -type f -atime +3 -delete 2>/dev/null || true
find /var/tmp -type f -atime +3 -delete 2>/dev/null || true

# 7️⃣ Verify disk usage summary
echo ""
echo "==============================================="
echo "📊 Docker Disk Usage Summary (After Cleanup)"
echo "==============================================="
docker system df || true

# 8️⃣ Optional — check for any dead symlinks or logs > 7 days old
echo "🧾 Cleaning stale logs older than 7 days (except current run)..."
find /root -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true
find /root -maxdepth 1 -type d -name "cpaas_logs_*" -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

echo "✅ Smart cleanup completed successfully!"
echo "🟢 All running containers preserved."
echo "==============================================="
