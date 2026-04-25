# OwnDelivery — Infrastructure

Docker Compose + deploy scripts for the OwnDelivery platform.

## Репозиторії проєкту

| Репо | Опис |
|------|------|
| [own-delivery-infra](https://github.com/raid3r/own-delivery-infra) | Docker Compose, скрипти, документація (цей репо) |
| [own-delivery-backend](https://github.com/raid3r/own-delivery-backend) | Backend API — .NET 8 ASP.NET Core |
| [own-delivery-courier-app](https://github.com/raid3r/own-delivery-courier-app) | Courier web app — Vue 3 + Vite |
| [own-delivery-design](https://github.com/raid3r/own-delivery-design) | Design system — Storybook + прототипи |

---

## Розгортання на чистій машині розробника

### 1. Встановити інструменти

**Docker:**
```bash
# Ubuntu / Debian
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Додати себе до групи docker (щоб не писати sudo)
sudo usermod -aG docker $USER
newgrp docker

# Перевірити
docker compose version
```

**Node.js 24 (через nvm):**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc

nvm install 24
nvm use 24
node -v   # має бути v24.x.x
```

**git:**
```bash
sudo apt-get install -y git
```

---

### 2. Клонувати всі репозиторії

```bash
mkdir -p ~/projects/own-delivery-workspace
cd ~/projects/own-delivery-workspace

git clone https://github.com/raid3r/own-delivery-infra.git
git clone https://github.com/raid3r/own-delivery-backend.git
git clone https://github.com/raid3r/own-delivery-courier-app.git
git clone https://github.com/raid3r/own-delivery-design.git
```

Структура після клонування:
```
own-delivery-workspace/
  own-delivery-infra/        ← Docker Compose, скрипти
  own-delivery-backend/      ← .NET 8 API
  own-delivery-courier-app/  ← Vue 3 фронтенд
  own-delivery-design/       ← Design / Storybook
```

---

### 3. Налаштувати змінні середовища

```bash
cd ~/projects/own-delivery-workspace/own-delivery-infra

cp .env.example .env
```

Відкрити `.env` і заповнити два обов'язкових поля:

```bash
# Пароль для SQL Server (мін. 8 символів, велика літера + цифра)
MSSQL_SA_PASSWORD=YourStrongPassword!123

# JWT-ключ (мін. 32 символи)
# Згенерувати: openssl rand -base64 32
Jwt__Key=REPLACE_WITH_32_CHAR_SECRET_KEY_HERE
```

> Решта значень у `.env.example` вже правильні для локальної розробки.

---

### 4. Підготувати директорію для бази даних

SQL Server у контейнері працює від системного користувача UID 10001:

```bash
mkdir -p ~/projects/own-delivery-workspace/own-delivery-infra/volumes/mssql
sudo chown -R 10001:0 ~/projects/own-delivery-workspace/own-delivery-infra/volumes/mssql
```

---

### 5. Встановити залежності фронтенду

```bash
cd ~/projects/own-delivery-workspace/own-delivery-courier-app
cp .env.example .env
npm install
```

---

### 6. Запустити бекенд і базу даних

```bash
cd ~/projects/own-delivery-workspace/own-delivery-infra

docker compose \
  -f docker/docker-compose.yml \
  -f docker/docker-compose.dev.yml \
  --env-file .env \
  up --build db backend
```

Перший запуск займає **3–5 хвилин** (завантаження образів + компіляція .NET).  
Наступні запуски — ~30 секунд (шари кешовані).

Готовність визначається по рядку в логах:
```
own-delivery-backend | Application started.
```

Swagger UI: **http://localhost:8095/swagger**

---

### 7. Запустити фронтенд

В окремому терміналі:

```bash
cd ~/projects/own-delivery-workspace/own-delivery-courier-app
npm run dev
```

Courier app: **http://localhost:5190**

---

### Зупинка

```bash
cd ~/projects/own-delivery-workspace/own-delivery-infra

# Зупинити (дані БД зберігаються)
docker compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml --env-file .env down

# Зупинити і видалити всі дані БД
./scripts/dev-backend-stop.sh --clean
```

---

## Сервіси і порти

| Сервіс | Порт | URL |
|--------|------|-----|
| Backend API | 8095 | http://localhost:8095/swagger |
| SQL Server | 1433 | `localhost,1433` |
| Courier App (Vite dev) | 5190 | http://localhost:5190 |
| Storybook (Design) | 6006 | http://localhost:6006 |

---

## Скрипти

| Скрипт | Опис |
|--------|------|
| `scripts/setup-env.sh` | Копіює `.env.example` → `.env` |
| `scripts/dev-backend-stop.sh` | Зупиняє БД; `--clean` видаляє дані |
| `scripts/watch-backend.sh` | Запускає бекенд нативно з `dotnet watch` |
| `scripts/deploy-backend.sh` | Деплой бекенду з GitHub |
| `scripts/deploy-design.sh` | Деплой Storybook з GitHub |
| `scripts/deploy-all.sh` | Деплой усіх сервісів |

Детальна документація по локальній розробці: [docs/local-development.md](docs/local-development.md)

---

## Часті проблеми

**`permission denied` при старті SQL Server**
```bash
sudo chown -R 10001:0 ~/projects/own-delivery-workspace/own-delivery-infra/volumes/mssql
```

**`docker: permission denied`**
```bash
sudo usermod -aG docker $USER && newgrp docker
```

**Порти 8095 або 1433 вже зайняті**
```bash
# Змінити у own-delivery-infra/.env
BACKEND_PORT=8096
```

**Бекенд не відповідає після старту**
```bash
docker logs own-delivery-backend --tail 20
```
