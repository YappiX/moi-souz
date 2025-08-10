#!/usr/bin/env bash
set -Eeuo pipefail

###
# MoiSouz one-shot installer for Debian 12 (bookworm) — no Docker
# - Installs Node 20, Nginx, Certbot
# - Deploys NestJS API (Prisma/SQLite) and Next.js Admin as systemd services
# - Configures Nginx reverse proxy for domain
#
# USAGE EXAMPLES:
#   # Using an already uploaded archive on the server
#   sudo bash install-moisouz-debian12.sh --domain myunion.pro --email you@domain.com --archive /var/www/moi-souz/moi-souz-nodocker.zip
#
#   # Or deploy from a git repo (must contain api/ and admin/ at the root)
#   sudo bash install-moisouz-debian12.sh --domain myunion.pro --email you@domain.com --git https://github.com/you/your-repo.git
#
# Notes:
# - Run as root (or with sudo).
# - If --email omitted, HTTPS step will be skipped (HTTP only).
###

DOMAIN=""
EMAIL=""
ARCHIVE_PATH=""
GIT_REPO=""
PROJECT_USER="app"
PROJECT_DIR="/var/www/moi-souz"
WWW_DOMAIN=""  # will default to "www.$DOMAIN"
INSTALL_NODE="yes"
ENABLE_UFW="no"
ISSUE_CERT="auto"  # auto | yes | no

function usage() {
  cat <<EOF
Usage: $0 --domain <domain> [--email <email>] [--archive <path.zip> | --git <repo-url>] [--user app] [--dir /var/www/moi-souz] [--no-node] [--ufw] [--no-https]

Options:
  --domain       Your domain (e.g., myunion.pro) [required]
  --email        Email for Let's Encrypt / Certbot (optional, enables HTTPS if provided)
  --archive      Path to moi-souz-nodocker.zip already present on the server
  --git          Git repository with 'api/' and 'admin/' at the root (alternative to --archive)
  --user         System user to own and run the app (default: app)
  --dir          Project directory (default: /var/www/moi-souz)
  --no-node      Do not install Node.js (assume present)
  --ufw          Enable UFW with 'OpenSSH' + 'Nginx Full'
  --no-https     Skip Let's Encrypt certificate issuance

Examples:
  sudo $0 --domain myunion.pro --email admin@myunion.pro --archive /var/www/moi-souz/moi-souz-nodocker.zip
  sudo $0 --domain myunion.pro --git https://github.com/you/repo.git --no-https
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="${2:-}"; shift 2 ;;
    --email) EMAIL="${2:-}"; shift 2 ;;
    --archive) ARCHIVE_PATH="${2:-}"; shift 2 ;;
    --git) GIT_REPO="${2:-}"; shift 2 ;;
    --user) PROJECT_USER="${2:-}"; shift 2 ;;
    --dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    --no-node) INSTALL_NODE="no"; shift ;;
    --ufw) ENABLE_UFW="yes"; shift ;;
    --no-https) ISSUE_CERT="no"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo "ERROR: --domain is required"; usage; exit 1
fi
if [[ -z "$ARCHIVE_PATH" && -z "$GIT_REPO" ]]; then
  # default archive path if exists
  if [[ -f "$PROJECT_DIR/moi-souz-nodocker.zip" ]]; then
    ARCHIVE_PATH="$PROJECT_DIR/moi-souz-nodocker.zip"
    echo "INFO: Using archive at $ARCHIVE_PATH"
  else
    echo "ERROR: Provide either --archive path.zip or --git repo-url"; usage; exit 1
  fi
fi
if [[ -z "$EMAIL" && "$ISSUE_CERT" == "auto" ]]; then
  ISSUE_CERT="no"
fi
if [[ -n "$EMAIL" && "$ISSUE_CERT" == "auto" ]]; then
  ISSUE_CERT="yes"
fi

WWW_DOMAIN="www.${DOMAIN}"

echo "==> Settings:"
echo "   DOMAIN:        $DOMAIN"
echo "   WWW_DOMAIN:    $WWW_DOMAIN"
echo "   PROJECT_USER:  $PROJECT_USER"
echo "   PROJECT_DIR:   $PROJECT_DIR"
echo "   ARCHIVE_PATH:  ${ARCHIVE_PATH:-<git>}"
echo "   GIT_REPO:      ${GIT_REPO:-<none>}"
echo "   Install Node:  $INSTALL_NODE"
echo "   Enable UFW:    $ENABLE_UFW"
echo "   Issue HTTPS:   $ISSUE_CERT (email: ${EMAIL:-none})"

echo "==> Step 1: apt packages"
export DEBIAN_FRONTEND=noninteractive
apt update
apt -y upgrade
apt -y install git unzip curl ca-certificates build-essential nginx
if [[ "$ISSUE_CERT" != "no" ]]; then
  apt -y install certbot python3-certbot-nginx
fi
if [[ "$ENABLE_UFW" == "yes" ]]; then
  apt -y install ufw || true
  ufw allow OpenSSH || true
  ufw allow 'Nginx Full' || true
  ufw --force enable || true
fi

if [[ "$INSTALL_NODE" == "yes" ]]; then
  echo "==> Step 2: Node.js 20 (NodeSource)"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt -y install nodejs
fi

echo "==> Step 3: app user and directories"
if ! id -u "$PROJECT_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$PROJECT_USER"
fi
mkdir -p "$PROJECT_DIR"
chown -R "$PROJECT_USER:$PROJECT_USER" "$PROJECT_DIR"

echo "==> Step 4: project files"
if [[ -n "$ARCHIVE_PATH" ]]; then
  if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "ERROR: archive not found at $ARCHIVE_PATH"
    exit 1
  fi
  sudo -u "$PROJECT_USER" bash -lc "unzip -o '$ARCHIVE_PATH' -d '$PROJECT_DIR'"
elif [[ -n "$GIT_REPO" ]]; then
  sudo -u "$PROJECT_USER" bash -lc "cd '$PROJECT_DIR' && rm -rf src && git clone '$GIT_REPO' src && rsync -a src/ ./ && rm -rf src/.git"
fi

# Ensure admin env points to /api for reverse proxy
sudo -u "$PROJECT_USER" bash -lc "echo 'NEXT_PUBLIC_API_URL=/api' > '$PROJECT_DIR/admin/.env.local'"

echo "==> Step 5: build API"
sudo -u "$PROJECT_USER" bash -lc "cd '$PROJECT_DIR/api' && npm ci && npx prisma db push && npm run build"

echo "==> Step 6: build Admin"
sudo -u "$PROJECT_USER" bash -lc "cd '$PROJECT_DIR/admin' && npm ci && npm run build"

echo "==> Step 7: systemd services"
cat >/etc/systemd/system/moi-souz-api.service <<EOF
[Unit]
Description=MoiSouz API (NestJS)
After=network.target

[Service]
User=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR/api
Environment=NODE_ENV=production
Environment=PORT=4000
Environment=HOST=127.0.0.1
ExecStart=/usr/bin/node dist/main.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/moi-souz-admin.service <<EOF
[Unit]
Description=MoiSouz Admin (Next.js)
After=network.target

[Service]
User=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR/admin
Environment=NODE_ENV=production
Environment=PORT=3000
ExecStart=/usr/bin/node node_modules/next/dist/bin/next start -p 3000 -H 127.0.0.1
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now moi-souz-api moi-souz-admin
systemctl --no-pager status moi-souz-api || true
systemctl --no-pager status moi-souz-admin || true

echo "==> Step 8: Nginx site for ${DOMAIN}"
cat >/etc/nginx/sites-available/moi-souz.conf <<EOF
server {
  listen 80;
  server_name ${DOMAIN} ${WWW_DOMAIN};

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  location /api/ {
    proxy_pass http://127.0.0.1:4000/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  location /uploads/ {
    proxy_pass http://127.0.0.1:4000/uploads/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
}
EOF

ln -sf /etc/nginx/sites-available/moi-souz.conf /etc/nginx/sites-enabled/moi-souz.conf
nginx -t
systemctl reload nginx

if [[ "$ISSUE_CERT" == "yes" ]]; then
  echo "==> Step 9: Let's Encrypt certificate via certbot"
  certbot --nginx -d "$DOMAIN" -d "$WWW_DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect || {
    echo "WARN: Certbot failed; continuing with HTTP only."
  }
else
  echo "==> Skipping HTTPS certificate issuance (no email or --no-https given)."
fi

echo "==> Done."
echo "Admin:  http://${DOMAIN}/"
echo "API:    http://${DOMAIN}/api/posts"
echo "Services: systemctl status moi-souz-api | moi-souz-admin"
echo "Nginx:    nginx -t && systemctl reload nginx"
