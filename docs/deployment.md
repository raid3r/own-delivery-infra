# OwnDelivery — Deployment Guide

## Overview

| Repo | Stack | Deploy target |
|------|-------|---------------|
| `own-delivery-backend` | .NET 8 / ASP.NET Core / SQL Server | Docker container |
| `own-delivery-design` | Vue 3 / Storybook / Vite | Docker container (nginx static) |
| `own-delivery-courier-app` | React Native / Expo | EAS Build → App Store / Play Store |
| `own-delivery-infra` | Docker Compose / Nginx | Host machine |

All server-side services run via **Docker Compose** managed from this (`own-delivery-infra`) repo.

---

## Prerequisites

| Tool | Min version | Install |
|------|-------------|---------|
| Docker + Compose plugin | 24.x | https://docs.docker.com/get-docker/ |
| Git | 2.x | `apt install git` / `brew install git` |
| Node.js (courier app only) | 20 LTS | https://nodejs.org |
| EAS CLI (courier app, optional) | latest | `npm i -g eas-cli` |

---

## Directory Layout

```
own-delivery-workspace/
├── own-delivery-backend/      ← git repo (.NET 8 API)
├── own-delivery-courier-app/  ← git repo (React Native)
├── own-delivery-design/       ← git repo (Vue 3 design system)
└── own-delivery-infra/        ← git repo (this repo)
    ├── docker/
    │   ├── docker-compose.yml       # base compose
    │   ├── docker-compose.dev.yml   # dev overrides
    │   ├── docker-compose.prod.yml  # prod resource limits
    │   └── nginx/
    │       └── nginx.conf
    ├── scripts/
    │   ├── setup-env.sh
    │   ├── deploy-all.sh
    │   ├── deploy-backend.sh
    │   ├── deploy-design.sh
    │   └── deploy-courier-app.sh
    ├── docs/
    │   └── deployment.md            ← this file
    └── .env.example
```

---

## First-time Setup

### 1. Clone all repos

```bash
cd ~/projects/own-delivery-workspace   # or wherever you keep the workspace

git clone https://github.com/YOUR_ORG/own-delivery-infra
git clone https://github.com/YOUR_ORG/own-delivery-backend
git clone https://github.com/YOUR_ORG/own-delivery-design
git clone https://github.com/YOUR_ORG/own-delivery-courier-app
```

### 2. Configure environment

```bash
cd own-delivery-infra
./scripts/setup-env.sh
# Opens .env — fill in all values marked with REPLACE_WITH_*
nano .env
```

Key variables to set:

| Variable | Description |
|----------|-------------|
| `MSSQL_SA_PASSWORD` | SQL Server SA password (min 8 chars, mixed case + digit + symbol) |
| `JwtSettings__Secret` | 32+ character random string for JWT signing |
| `GITHUB_ORG` | Your GitHub organisation or username |

Generate a JWT secret:
```bash
openssl rand -base64 32
```

### 3. Deploy all services

```bash
# Production
./scripts/deploy-all.sh --branch main --env prod

# Development (hot-reload)
./scripts/deploy-all.sh --branch main --env dev
```

---

## Individual Service Deployment

### Backend API

```bash
# Deploy latest main
./scripts/deploy-backend.sh

# Deploy a specific branch
./scripts/deploy-backend.sh --branch feature/my-feature

# Rebuild image without pulling code
./scripts/deploy-backend.sh --skip-pull
```

**What it does:**
1. `git pull` from GitHub
2. `docker build` — multi-stage .NET 8 build
3. Waits for SQL Server healthcheck
4. Runs EF Core migrations
5. Restarts the `backend` container

### Design System (Storybook)

```bash
./scripts/deploy-design.sh
```

**What it does:**
1. `git pull` from GitHub
2. `docker build` — `npm run build-storybook` → nginx static
3. Restarts the `design` container

### Courier App (React Native)

```bash
# Build for all platforms via EAS
./scripts/deploy-courier-app.sh

# Build Android only
./scripts/deploy-courier-app.sh --platform android
```

**What it does:**
1. `git pull` from GitHub
2. `npm ci`
3. If `eas-cli` is installed → `eas build`; otherwise → `expo export`

---

## Docker Compose Commands

```bash
# From infra/docker/ or pass -f path
cd own-delivery-infra/docker

# Start everything
docker compose up -d

# Start with prod resource limits
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# View logs
docker compose logs -f backend
docker compose logs -f db

# Stop all
docker compose down

# Stop and remove volumes (⚠ deletes database data)
docker compose down -v

# Rebuild single service
docker compose up -d --build --no-deps backend
```

---

## Database Migrations

EF Core migrations are tracked in `own-delivery-backend/src/OwnDeliveryApiP33/Migrations/`.

**Apply manually** (when the deploy script migration step is skipped):

```bash
# From own-delivery-backend/
dotnet tool install -g dotnet-ef   # once

dotnet ef database update \
  --project src/OwnDeliveryApiP33 \
  --connection "Server=localhost,1433;Database=OwnDelivery;User Id=sa;Password=YourStrongPassword!123;TrustServerCertificate=true;"
```

**Create a new migration:**

```bash
dotnet ef migrations add <MigrationName> \
  --project src/OwnDeliveryApiP33
```

---

## Ports Summary

| Service | Default port | Override via |
|---------|-------------|--------------|
| SQL Server | 1433 | — |
| Backend API | 8080 | `BACKEND_PORT` |
| Design / Storybook | 6006 | `DESIGN_PORT` |
| Nginx HTTP | 80 | `NGINX_HTTP_PORT` |
| Nginx HTTPS | 443 | `NGINX_HTTPS_PORT` |

All ports are configurable in `.env`.

---

## URL Routing (via Nginx)

| Path | Proxied to |
|------|-----------|
| `/api/*` | `backend:8080` |
| `/design/*` | `design:6006` |
| `/health` | `backend:8080/health` |

---

## Environment Files

| File | Purpose | Committed |
|------|---------|-----------|
| `.env.example` | Template with all keys | Yes |
| `.env` | Real secrets (per server) | **No** (in .gitignore) |
| `appsettings.json` | Non-secret defaults | Yes |
| `appsettings.Development.json` | Local dev overrides | **No** |

---

## Adding GitHub Remotes

After creating repos on GitHub:

```bash
# Backend
cd own-delivery-backend
git remote add origin https://github.com/YOUR_ORG/own-delivery-backend.git
git push -u origin master

# Design
cd ../own-delivery-design
git remote add origin https://github.com/YOUR_ORG/own-delivery-design.git
git push -u origin master

# Courier App
cd ../own-delivery-courier-app
git remote add origin https://github.com/YOUR_ORG/own-delivery-courier-app.git
git push -u origin master

# Infra
cd ../own-delivery-infra
git remote add origin https://github.com/YOUR_ORG/own-delivery-infra.git
git push -u origin master
```

---

## Troubleshooting

### SQL Server won't start
- Check `MSSQL_SA_PASSWORD` meets complexity requirements (uppercase, lowercase, digit, symbol, min 8 chars)
- Check disk space: SQL Server needs ~2 GB

### Backend fails to connect to DB
- Ensure `db` container is healthy: `docker compose ps`
- Verify `ConnectionStrings__DefaultConnection` in `.env` uses hostname `db` (not `localhost`)

### Port already in use
- Change the port in `.env` (e.g. `BACKEND_PORT=8081`)
- Or stop the conflicting process: `sudo lsof -i :8080`

### Nginx returns 502
- Check that `backend` and `design` containers are running and healthy
- View nginx logs: `docker compose logs nginx`
