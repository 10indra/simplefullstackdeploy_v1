#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

#!/usr/bin/env bash
#set -Eeuo pipefail

########################################
# GLOBAL CONFIG
########################################
DOMAINS=("app1.local" "app2.local" "app3.local")
BASE_DIR="/opt/webapps"
START_PORT=8443
LOG="/var/log/full_deploy.log"
USER_NAME="${SUDO_USER:-$(whoami)}"

exec > >(tee -a "$LOG") 2>&1

########################################
# COLORS
########################################
g(){ echo -e "\e[32m$1\e[0m"; }
y(){ echo -e "\e[33m$1\e[0m"; }
r(){ echo -e "\e[31m$1\e[0m"; }

step(){ g "▶ $1"; }
fail(){ r "[ERROR] $1"; exit 1; }

trap 'fail "FAILED line $LINENO"' ERR
[[ $EUID -ne 0 ]] && fail "Run as root"

########################################
# RETRY
########################################
retry(){
for i in {1..5}; do
 "$@" && return
 y "Retry $i..."
 sleep 2
done
return 1
}

########################################
# INSTALL DOCKER
########################################
install_docker(){

if command -v docker >/dev/null; then
 step "Docker already installed"
 return
fi

step "Installing Docker"

apt update -y
apt install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
> /etc/apt/sources.list.d/docker.list

apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl restart docker

usermod -aG docker "$USER_NAME" || true
}

########################################
# HARDENING
########################################
harden(){

step "System hardening"

apt install -y ufw fail2ban jq htop net-tools sysstat

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

systemctl enable fail2ban
systemctl start fail2ban

cat > /etc/docker/daemon.json <<EOF
{
 "log-driver": "json-file",
 "log-opts": {
  "max-size": "50m",
  "max-file": "3"
 }
}
EOF

systemctl restart docker
}

########################################
# CHECK DOCKER
########################################
check_docker(){
step "Validating docker"
retry docker info >/dev/null || fail "Docker failed"
docker compose version >/dev/null || fail "Compose missing"
}

########################################
# PORT CHECK
########################################
port_free(){
! ss -lnt | grep -q ":$1 "
}

########################################
# WAIT CONTAINER
########################################
wait_container(){
NAME=$1
for i in {1..30}; do
 sleep 2
 docker ps --format '{{.Names}}' | grep -q "^$NAME$" && return
done
docker logs "$NAME" || true
fail "Container $NAME failed"
}

########################################
# FIX PERMISSION (CRITICAL)
########################################
fix_perm(){
APP=$1
chown -R 33:33 "$APP"
chmod -R 775 "$APP/storage"
chmod -R 775 "$APP/bootstrap/cache"
}

########################################
# DEPLOY APP
########################################
deploy_app(){

NAME=$1
PORT=$2
PROJ=$(echo "$NAME" | tr . _)

step "Deploy $NAME → $PORT"

port_free "$PORT" || fail "Port $PORT already used"

mkdir -p "$BASE_DIR/$NAME"
cd "$BASE_DIR/$NAME"

#################################
# COMPOSE
#################################
cat > docker-compose.yml <<EOF
services:

 php:
  image: php:8.4-fpm
  container_name: ${PROJ}_php
  user: "33:33"
  working_dir: /var/www/html
  volumes:
   - ./app:/var/www/html
  command: sh -c "chmod -R 775 storage bootstrap/cache || true && php-fpm"
  restart: unless-stopped
  healthcheck:
   test: ["CMD","php","-v"]
   interval: 30s
   timeout: 5s
   retries: 3

 db:
  image: mysql:8
  container_name: ${PROJ}_db
  environment:
   MYSQL_ROOT_PASSWORD: strongpass
   MYSQL_DATABASE: laravel
  volumes:
   - dbdata:/var/lib/mysql
  restart: unless-stopped

 nginx:
  image: nginx:alpine
  container_name: ${PROJ}_nginx
  ports:
   - "${PORT}:443"
  volumes:
   - ./app:/var/www/html
   - ./nginx.conf:/etc/nginx/nginx.conf
   - ./certs:/certs
  depends_on:
   - php
  restart: unless-stopped

volumes:
 dbdata:
EOF

#################################
# NGINX CONFIG
#################################
cat > nginx.conf <<EOF
events {}
http {
 server {
  listen 443 ssl;
  server_name ${NAME};

  ssl_certificate /certs/cert.pem;
  ssl_certificate_key /certs/key.pem;

  root /var/www/html/public;
  index index.php;

  location / {
   try_files \$uri \$uri/ /app-id.php /index.php?\$query_string;
  }

  location ~ \.php$ {
   include fastcgi_params;
   fastcgi_pass php:9000;
   fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
  }
 }
}
EOF

#################################
# CERT
#################################
mkdir -p certs
openssl req -x509 -nodes -days 365 \
-newkey rsa:2048 \
-keyout certs/key.pem \
-out certs/cert.pem \
-subj "/CN=$NAME" >/dev/null 2>&1

#################################
# INSTALL LARAVEL
#################################
if [ ! -d app ]; then
 step "Installing Laravel $NAME"
 retry docker run --rm -v "$(pwd)":/app composer create-project laravel/laravel app
 fix_perm app
fi

#################################
# RUNTIME INFO PAGE (NEW FEATURE)
#################################
cat > app/public/app-id.php <<'EOF'
<?php
$ip = gethostbyname(gethostname());
?>
<!DOCTYPE html>
<html>
<head>
<title>APP INFO</title>
<style>
body{
 font-family:Arial;
 background:#0d1117;
 color:#00ff9c;
 display:flex;
 justify-content:center;
 align-items:center;
 height:100vh;
 margin:0;
}
.box{
 text-align:center;
 border:2px solid #00ff9c;
 padding:40px;
 border-radius:14px;
 box-shadow:0 0 25px #00ff9c;
 background:#020409;
}
td{padding:6px 14px}
.label{color:#7affc1}
</style>
</head>
<body>
<div class="box">
<h2>Application Environment</h2>
<table>
<tr><td class="label">Domain</td><td><?=$_SERVER['SERVER_NAME']?></td></tr>
<tr><td class="label">Container</td><td><?=gethostname()?></td></tr>
<tr><td class="label">IP</td><td><?=$ip?></td></tr>
<tr><td class="label">Time</td><td><?=date("Y-m-d H:i:s")?></td></tr>
<tr><td class="label">PHP</td><td><?=phpversion()?></td></tr>
</table>
<br>
<b>Environment Ready ✅</b>
</div>
</body>
</html>
EOF

#################################
# ENSURE PERMISSION EVERY RUN
#################################
fix_perm app

#################################
# START
#################################
step "Starting containers"
docker compose -p "$PROJ" up -d

wait_container "${PROJ}_php"
wait_container "${PROJ}_nginx"

g "✔ $NAME running"
cd ..
}

########################################
# MAIN
########################################
install_docker
harden
check_docker

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

PORT=$START_PORT

for d in "${DOMAINS[@]}"; do
 deploy_app "$d" "$PORT"
 PORT=$((PORT+1))
done

g "======================================"
g "ALL 3 APPS SUCCESSFULLY DEPLOYED"
g "======================================"

