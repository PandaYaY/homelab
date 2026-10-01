# Спецификация: сбор логов (Loki + Alloy + Grafana)

Статус: черновик, 2026-10-01.

## Цель

Централизованно собирать и просматривать логи контейнеров Docker и службы
хоста (nginx, sshd, ядро) на одном сервере `orangepizero3`, не выходя за
~1 ГБ ОЗУ и не изнашивая SD-карту.

## Ограничения

- Хост: Orange Pi Zero 3, ARM64, Armbian, 4 ГБ ОЗУ. Образы только multi-arch (arm64).
- Система и данные на SD-карте, поэтому запись нужно минимизировать.
- Firewall (`nftables`) открывает только 80, 443 и SSH из LAN. Трафик контейнеров
  он не фильтрует, поэтому порты Loki и Grafana публикуются только на `127.0.0.1`.
- Docker уже ротирует логи: `json-file`, 10m × 3 (`roles/docker/defaults`).

## Выбор технологий

| Задача | Выбор | Альтернатива |
|---|---|---|
| Хранилище | Loki (filesystem, TSDB) | VictoriaLogs, если не уложимся в ОЗУ |
| Сбор | Grafana Alloy | Vector |
| Просмотр | Grafana | `logcli` для разового grep по SSH |

ELK, OpenSearch и Graylog отброшены по ОЗУ (2–4 ГБ+). Seq рассматривался,
но он закрытый и рассчитан на структурированные события, а не на текстовые
логи хоста.

## Архитектура

```
контейнеры Docker ─┐
journald хоста ────┴─> Alloy ──> Loki ──> Grafana ──> 127.0.0.1:3000
```

Один compose-проект `logging` в `/opt/logging`, три сервиса в общей сети.
Наружу публикуется только Grafana, и только на loopback.

| Сервис | Лимит ОЗУ | Данные |
|---|---|---|
| loki | 512m | `./data/loki` (uid 10001) |
| alloy | 256m | нет |
| grafana | 256m | `./data/grafana` (uid 472) |

## Состав изменений

### 1. `services/apps/logging/`

- `docker-compose.yaml`: сервисы `loki`, `alloy`, `grafana`.
  - Теги образов пиним (как у vaultwarden), `restart: unless-stopped`.
  - Alloy: `/var/run/docker.sock:ro`, `/var/log/journal:ro`, `/run/log/journal:ro`.
  - Grafana: `ports: 127.0.0.1:3000:3000`, `env_file: ./logging.env`.
  - Loki порт наружу не публикует.
- `config/loki.yaml`: `auth_enabled: false`, схема TSDB v13, filesystem,
  compactor с `retention_enabled: true`, `retention_period` (см. открытые вопросы),
  лимиты ingestion на поток, `chunk_encoding: snappy` или `zstd`.
- `config/alloy.alloy`: `discovery.docker` → `loki.source.docker`,
  `loki.source.journal`, отправка в Loki. Метки только `host`, `container`, `job`.
- `config/grafana-datasource.yaml`: provisioned datasource Loki.
- `templates/logging.env.j2`: `GF_SECURITY_ADMIN_PASSWORD`, `GF_SERVER_ROOT_URL`,
  отключение регистрации и анонимного доступа.
- `README.md` в стиле соседних сервисов.

### 2. Секреты

- `vault.yml`: `vault_grafana_admin_password`.
- `vars.yml`: `grafana_admin_password: "{{ vault_grafana_admin_password }}"`.
- Обновить `vault.example.yml`.

### 3. Роль `compose_app`

Сейчас роль падает, если нет `{{ app_dir }}/data`, и сама его никогда не создаёт
(данные приложений ценные, пустой каталог означает потерю). Для логов данные
одноразовые.

- Новый необязательный флаг приложения `disposable_data: true`.
  - Роль создаёт `data/loki` (10001) и `data/grafana` (472) с нужными владельцами.
  - Проверка наличия `data` для таких приложений пропускается.
- Копирование каталога `config/` в `{{ app_dir }}/config`.
- Поведение остальных приложений не меняется.

### 4. `vars.yml`: регистрация

```yaml
- name: logging
  env_template: logging.env.j2
  env_file: logging.env
  disposable_data: true
```

Ключа `backup` нет намеренно: `homelab-backup.sh.j2` берёт только приложения
с `app.backup`, логи в архив не попадут.

### 5. Доступ к Grafana

Вариант по умолчанию, пока не решено иное: **SSH-туннель**
(`ssh -L 3000:127.0.0.1:3000 nyaners@192.168.1.226`). nginx, TLS, DNS и firewall
не меняются.

Если нужен домен:

- `services/network/nginx/sites-available/grafana.<домен>.conf` по образцу
  vaultwarden (с `allow 192.168.1.0/24; deny all`, если только LAN);
- домен в `tls_domains` и `nginx_sites`;
- ручной выпуск сертификата: `sudo certbot certonly --nginx -d <домен>`.

### 6. Снижение износа SD

- Loki: большие `chunk_idle_period` и `max_chunk_age`, сжатие чанков,
  retention не больше 7 дней на старте.
- Alloy: отбрасывать шум (health-check запросы nginx, debug-логи).
- На будущее: вынести `data` на USB-диск или SSD, достаточно сменить путь тома.

### 7. Документация

- `README.md`: таблица сервисов, схема, пометка, что логи не бэкапятся.
- `ansible/README.md`: упомянуть `app_filter=logging` и `disposable_data`.

## Порядок выполнения

1. Доработать `compose_app` (`disposable_data`, `config/`).
2. Создать `services/apps/logging/` со всеми конфигами.
3. Добавить секрет в vault, ссылку в `vars.yml` и запись в `apps`.
4. Проверка: `ansible-playbook playbooks/apps.yml -e app_filter=logging --check --diff`.
5. Реальный запуск без `--check`.
6. Проверка работы (ниже).
7. Обновить документацию.

## Критерии приёмки

- `docker compose ps` в `/opt/logging`: все три контейнера `Up`.
- `docker stats --no-stream`: суммарно не более ~1 ГБ ОЗУ.
- Loki отвечает `ready` изнутри сети контейнеров.
- Grafana Explore: `{container="vaultwarden"}` возвращает свежие строки,
  `{job="journal"} |= "sshd"` показывает записи sshd.
- Порты Loki и Grafana не слушают на внешних интерфейсах (`ss -tlnp`).
- Повторный запуск плейбука: `changed=0`.
- Через сутки: рост `du -sh /opt/logging/data/loki` соответствует ожиданиям
  по retention.

## Риски

- **Права на `data`**: неверный владелец (10001 для Loki, 472 для Grafana)
  уронит контейнеры при старте.
- **Docker socket у Alloy**: широкий доступ к хосту даже в режиме `:ro`.
  Альтернатива: читать `/var/lib/docker/containers` напрямую, но без меток
  контейнеров.
- **Старые контейнеры**: новые `log-opts` Docker применяются только к новым
  контейнерам, для старых `-e app_recreate=true`. Сбор через Alloy от этого
  не зависит.
- **ОЗУ**: лимиты прикидочные, реальные цифры покажет `docker stats`.
  При нехватке переход на VictoriaLogs.
- **Износ SD**: следить за ростом `data/loki`, при необходимости переносить
  на внешний носитель.

## Открытые вопросы

1. Доступ к Grafana: SSH-туннель (по умолчанию) или домен (какой)?
2. Retention: 7 дней (по умолчанию) или 14?
3. Флаг `disposable_data` в `compose_app` (по умолчанию) или отдельная роль `logging`?
