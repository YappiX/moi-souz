# Мой Союз — запуск без Docker (API NestJS + Prisma/SQLite, Admin Next.js)

Готовый код для локальной разработки и сервера (Debian/Ubuntu) без Docker.

## Быстрый старт локально
Откройте два терминала.

### 1) API
cd api
npm install
npx prisma db push
npm run start:dev

### 2) Admin
cd admin
npm install
# (опционально) cp .env.local.example .env.local
npm run dev

## Продакшен (Debian 12 / Ubuntu 22.04)
См. папку deploy/: systemd-сервисы и конфиг Nginx на myunion.pro.