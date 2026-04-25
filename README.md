# OwnDelivery — Infrastructure

Docker Compose + deploy scripts for the OwnDelivery platform.

## Quick start

```bash
./scripts/setup-env.sh   # copy .env.example → .env, fill secrets
./scripts/deploy-all.sh  # pull, build, migrate, start all services
```

Локальна розробка: [docs/local-development.md](docs/local-development.md)
Full documentation: [docs/deployment.md](docs/deployment.md)

## Services

| Service | Image | Port |
|---------|-------|------|
| SQL Server 2022 | `mcr.microsoft.com/mssql/server:2022-latest` | 1433 |
| Backend API (.NET 8) | `own-delivery-backend:latest` | 8080 |
| Design / Storybook | `own-delivery-design:latest` | 6006 |
| Nginx reverse proxy | `nginx:1.27-alpine` | 80 / 443 |

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/setup-env.sh` | First-time env setup |
| `scripts/deploy-all.sh` | Deploy everything |
| `scripts/deploy-backend.sh` | Deploy backend only |
| `scripts/deploy-design.sh` | Deploy design/Storybook only |
| `scripts/deploy-courier-app.sh` | Build courier mobile app |
