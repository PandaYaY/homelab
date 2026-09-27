# find-air

Telegram-бот, который следит за ценами на авиабилеты и присылает дайджест.
Код живёт в отдельном репозитории
[PandaYaY/FindAir](https://github.com/PandaYaY/FindAir), здесь только
развёртывание.

## Как устроен

- Образ собирается на сервере прямо из ветки `master` репозитория на GitHub,
  контекст сборки задан в `docker-compose.yaml`.
- Портов не публикует: бот сам ходит в Telegram API и Travelpayouts.
  nginx ему не нужен.
- База SQLite в `./data` рядом с compose.

## Файлы

| Файл | Назначение |
|---|---|
| `docker-compose.yaml` | описание контейнера и источник сборки |
| `templates/find-air.env.j2` | шаблон `find-air.env`, рендерится Ansible |

Переменные шаблона:

| Переменная | Что это |
|---|---|
| `find_air_bot_token` | токен бота от @BotFather |
| `find_air_allowed_user_ids` | Telegram ID пользователей через запятую |
| `find_air_tp_token` | токен API Travelpayouts |

Остальные настройки (интервал проверки, время дайджеста, пороги падения
цены) заданы в шаблоне явно.

## Обновление

```sh
cd /opt/find-air
docker compose up -d --build
```

Compose заново клонирует `master` и пересобирает образ. Отдельный
`git pull` не нужен.

## Сейчас на сервере

Пока Ansible не внедрён, бот запущен из клона репозитория в
`~/projects/FindAir` пользователя `nyaners` и собран оттуда, поэтому образ
называется `findair-findair`. Перенос в `/opt/find-air` и сборка из GitHub
запланированы на этап 4, после этого образ будет называться `findair`.
