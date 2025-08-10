# Установка на Debian 12 без Docker (Nginx + systemd)

1) Пакеты:
apt update && apt -y upgrade
apt -y install git unzip curl ca-certificates build-essential nginx certbot python3-certbot-nginx
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt -y install nodejs

adduser app --disabled-password --gecos ""
usermod -aG sudo app
mkdir -p /var/www/moi-souz && chown -R app:app /var/www/moi-souz

2) Скопируйте архив и распакуйте в /var/www/moi-souz/

3) Сборка:
sudo -u app -H bash -lc 'cd /var/www/moi-souz/api && npm ci && npx prisma db push && npm run build'
sudo -u app -H bash -lc 'cd /var/www/moi-souz/admin && npm ci && npm run build'

4) systemd:
cp deploy/systemd/moi-souz-api.service /etc/systemd/system/moi-souz-api.service
cp deploy/systemd/moi-souz-admin.service /etc/systemd/system/moi-souz-admin.service
systemctl daemon-reload
systemctl enable --now moi-souz-api moi-souz-admin

5) Nginx и HTTPS:
cp deploy/nginx/moi-souz.conf /etc/nginx/sites-available/moi-souz.conf
ln -sf /etc/nginx/sites-available/moi-souz.conf /etc/nginx/sites-enabled/moi-souz.conf
nginx -t && systemctl reload nginx
certbot --nginx -d myunion.pro -d www.myunion.pro