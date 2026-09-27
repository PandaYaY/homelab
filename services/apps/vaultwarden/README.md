# vaultwarden

Менеджер паролей, совместимый с Bitwarden. Работает в Docker, снаружи
доступен как https://vaultwarden.nyaners.ru через nginx.

## Как устроен

- Образ `vaultwarden/server`, версия зафиксирована в `docker-compose.yaml`.
- Порт 80 контейнера опубликован только на `127.0.0.1:8080`, наружу его
  выпускает nginx.
- Данные (SQLite-база, вложения, ключи RSA) в `./data` рядом с compose.
- Регистрация закрыта, новые пользователи только по приглашению.
- Админка `/admin` защищена `ADMIN_TOKEN` и дополнительно ограничена в nginx.

## Файлы

| Файл | Назначение |
|---|---|
| `docker-compose.yaml` | описание контейнера |
| `templates/vaultwarden.env.j2` | шаблон `vaultwarden.env`, рендерится Ansible |

Переменные шаблона:

| Переменная | Что это |
|---|---|
| `vaultwarden_admin_token` | argon2-хеш токена админки, генерируется командой `vaultwarden hash` внутри контейнера |

## Обновление

```sh
cd /opt/vaultwarden
docker compose pull
docker compose up -d
```

Перед обновлением мажорной версии смотреть changelog: миграции базы
необратимы.

## Бэкап

Достаточно каталога `./data`. База SQLite, копировать на живом контейнере
лучше через `sqlite3 data/db.sqlite3 ".backup ..."`, а не `cp`.
Автоматизация бэкапов запланирована на этапе 5.

## Сейчас на сервере

Пока Ansible не внедрён, compose и данные лежат в `~/vaultwarden`
пользователя `nyaners`. Перенос в `/opt/vaultwarden` вместе с каталогом
`data` запланирован на этап 4.
