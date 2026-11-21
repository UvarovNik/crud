# Инструкции по деплою

## 1. Настройка GitHub Secrets

Перейдите в настройки репозитория:
`Settings` → `Secrets and variables` → `Actions` → `New repository secret`

Добавьте 3 секрета:

| Secret Name | Значение |
|---|---|
| `SERVER_HOST` | `194.113.34.240` |
| `SERVER_USER` | `vylarrja` |
| `SSH_PRIVATE_KEY` | Содержимое файла `~/.ssh/stocks_products_deploy` (без заголовка/конца ключа) |

**Получить приватный ключ:**
```bash
cat ~/.ssh/stocks_products_deploy
```

## 2. Настройка сервера

### Вариант A: Автоматический (рекомендуется)

Подключитесь к серверу и запустите скрипт:
```bash
ssh vylarrja@194.113.34.240
sudo bash /dev/stdin < /path/to/setup-server.sh
```

Или запустите локально с помощью ssh:
```bash
ssh vylarrja@194.113.34.240 "sudo bash -s" < setup-server.sh
```

Скрипт автоматически:
- Установит PostgreSQL, Nginx, Gunicorn, fail2ban, ufw
- Создаст базу данных
- Клонирует репозиторий
- Настроит виртуальное окружение
- Создал systemd сервис для Gunicorn
- Настроил Nginx как reverse proxy
- Настроил firewall

**Сохраните вывод скрипта** — там будут DB Password и SECRET_KEY.

### Вариант B: Ручной

См. файл `.gigacode/plans/1795279063569-calm-cactus.plan.md` — раздел "Этап 3".

## 3. Проверка

После настройки проверьте:
```bash
# Проверка Gunicorn
curl http://127.0.0.1:8000/api/v1/products/

# Проверка через Nginx
curl http://194.113.34.240/api/v1/products/

# Создание тестового продукта
curl -X POST http://194.113.34.240/api/v1/products/ \
  -H "Content-Type: application/json" \
  -d '{"title": "Test", "description": "Testing"}'
```

## 4. CI/CD

После настройки GitHub Secrets:
1. Сделайте любой коммит в `main`
2. Перейдите в `Actions` → `CI/CD Pipeline`
3. Убедитесь, что `test` прошёл успешно
4. Убедитесь, что `deploy` прошёл успешно

## 5. Настройка SSH-ключа для деплоя

Если ключ ещё не добавлен на сервер:
```bash
# Локально:
cat ~/.ssh/stocks_products_deploy.pub

# Скопируйте вывод и добавьте на сервер:
ssh vylarrja@194.113.34.240 "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
ssh vylarrja@194.113.34.240 "echo 'ssh-ed25519 AAAA...' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```
# CI/CD Test
