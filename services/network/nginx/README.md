# nginx

Обратный прокси на сервере. Установлен из пакетов Armbian, работает как
systemd-сервис, не в Docker.

## Файлы

| В репозитории | На сервере |
|---|---|
| `nginx.conf` | `/etc/nginx/nginx.conf` |
| `sites-available/default` | `/etc/nginx/sites-available/default` |
| `sites-available/vaultwarden.nyaners.ru.conf` | `/etc/nginx/sites-available/vaultwarden.nyaners.ru.conf` |

В `/etc/nginx/sites-enabled/` лежат симлинки на оба сайта. `conf.d/` и
`snippets/` не менялись, там дефолт из пакета.

Не в репозитории и не должны там быть:

- `/etc/nginx/.htpasswd` — basic auth для `/admin` vaultwarden;
- `/etc/letsencrypt/` — сертификаты и ключи, ими управляет certbot.

## Сайты

- **default** — заглушка на 80 порту для запросов без известного `Host`,
  отдаёт `/var/www/html`.
- **vaultwarden.nyaners.ru.conf** — прокси на `127.0.0.1:8080` с поддержкой
  websocket. 80 редиректит на 443. `/admin` доступен либо из
  `127.0.0.1` и `192.168.1.0/24`, либо по basic auth.

## TLS

Сертификаты Let's Encrypt через certbot, строки с пометкой
`managed by Certbot` в конфиге сайта добавлены им. Продление автоматическое
таймером certbot.

## Применить изменения руками

```sh
sudo cp services/network/nginx/nginx.conf /etc/nginx/nginx.conf
sudo cp services/network/nginx/sites-available/* /etc/nginx/sites-available/
sudo nginx -t && sudo systemctl reload nginx
```

Новый сайт после копирования нужно включить:

```sh
sudo ln -s /etc/nginx/sites-available/<домен>.conf /etc/nginx/sites-enabled/<домен>.conf
```

Сайты называются по домену с суффиксом `.conf`, например
`vaultwarden.nyaners.ru.conf`. Суффикс нужен, чтобы редакторы не принимали
окончание `.ru` за расширение Ruby.
