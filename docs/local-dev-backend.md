# Локальна розробка — Backend

## Передумови

| Інструмент | Встановити |
|-----------|-----------|
| .NET 8 SDK | `sudo apt install dotnet-sdk-8.0` або [dotnet.microsoft.com](https://dotnet.microsoft.com/download) |
| Docker | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| dotnet-ef (CLI для міграцій) | `dotnet tool install -g dotnet-ef` |

Перевірити:
```bash
dotnet --version   # 8.x.x
docker --version   # 24+
dotnet ef          # повинен вивести справку
```

---

## Швидкий старт

```bash
cd own-delivery-infra

# Перший запуск — налаштувати .env (один раз)
./scripts/setup-env.sh

# Запустити
./scripts/dev-backend-start.sh
```

Swagger відкриється на **http://localhost:5134/swagger**

---

## Детальний опис

### Запуск (звичайний режим)

```bash
./scripts/dev-backend-start.sh
```

Скрипт виконує:
1. Стартує контейнер `own-delivery-db` (SQL Server) якщо не запущений
2. Чекає поки DB стане `healthy` (до 60 сек)
3. Якщо немає `appsettings.Development.json` — створює його автоматично з паролем з `.env`
4. Застосовує EF Core міграції (`dotnet ef database update`)
5. Запускає `dotnet run` — сервер на **http://localhost:5134**

> `appsettings.Development.json` знаходиться в `.gitignore` — не потрапить в репозиторій.

### Запуск з hot-reload

```bash
./scripts/dev-backend-start.sh --watch
```

Використовує `dotnet watch` — сервер автоматично перезапускається при зміні `.cs` файлів.

### Зупинка

```bash
# У терміналі де запущений dotnet:
Ctrl+C

# Зупинити SQL Server контейнер (дані зберігаються):
./scripts/dev-backend-stop.sh

# Зупинити та повністю видалити базу даних:
./scripts/dev-backend-stop.sh --clean
```

---

## URL-адреси

| Ресурс | URL |
|--------|-----|
| Swagger UI | http://localhost:5134/swagger |
| API (HTTP) | http://localhost:5134 |
| API (HTTPS) | https://localhost:7138 |
| SQL Server | localhost:1433 |

---

## Підключення до бази даних вручну

```
Server:   localhost,1433
Database: OwnDelivery
Login:    sa
Password: (значення MSSQL_SA_PASSWORD з .env)
TrustServerCertificate: true
```

Через Azure Data Studio або DBeaver — тип підключення **Microsoft SQL Server**.

---

## Міграції

```bash
cd own-delivery-backend

# Застосувати всі нові міграції
dotnet ef database update --project src/OwnDeliveryApiP33

# Створити нову міграцію після зміни моделей
dotnet ef migrations add <НазваМіграції> --project src/OwnDeliveryApiP33

# Відкотити останню міграцію
dotnet ef database update <ПопередняМіграція> --project src/OwnDeliveryApiP33
```

---

## Troubleshooting

**`appsettings.Development.json` створено, але DB не підключається**
- Переконайтесь що `own-delivery-db` контейнер запущений: `docker ps | grep own-delivery-db`
- Пароль в `appsettings.Development.json` має збігатися з `MSSQL_SA_PASSWORD` у `.env`

**Порт 5134 вже зайнятий**
- Знайти і завершити процес: `sudo lsof -i :5134`
- Або змінити порт у `src/OwnDeliveryApiP33/Properties/launchSettings.json`

**`dotnet-ef` не знайдено**
```bash
dotnet tool install -g dotnet-ef
export PATH="$PATH:$HOME/.dotnet/tools"   # додати в ~/.bashrc
```

**SQL Server не стартує**
```bash
docker logs own-delivery-db
```
Найчастіша причина — пароль `MSSQL_SA_PASSWORD` не відповідає вимогам складності (мін. 8 символів, великі + малі + цифра + спецсимвол).
