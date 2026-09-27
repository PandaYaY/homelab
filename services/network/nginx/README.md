# nginx

Обратный прокси на сервере. Установлен из пакетов Ubuntu, работает как
systemd-сервис, не в Docker. На сервер конфиги раскладывает роль Ansible
`nginx`.

## Файлы

| В репозитории                                 | На сервере                                               |
| --------------------------------------------- | -------------------------------------------------------- |
| `nginx.conf`                                  | `/etc/nginx/nginx.conf`                                  |
| `sites-available/00-default.conf`             | `/etc/nginx/sites-available/00-default.conf`             |
| `sites-available/vaultwarden.nyaners.ru.conf` | `/etc/nginx/sites-available/vaultwarden.nyaners.ru.conf` |

В `/etc/nginx/sites-enabled/` лежат симлинки на оба сайта. `conf.d/` и
`snippets/` не менялись, там дефолт из пакета.

Штатный `sites-available/default` принадлежит пакету nginx. Его не правим и
не удаляем, иначе при обновлении пакета будет конфликт конфигов. Роль только
убирает его симлинк из `sites-enabled`: он объявляет `default_server` на
порту 80 и конфликтует с `00-default.conf`.

Не в репозитории и не должны там быть:

- `/etc/letsencrypt/` — сертификаты и ключи, ими управляет certbot.

## Сайты

- **00-default.conf** — сайт по умолчанию для всего, что не подошло ни к
  одному домену: запросы по IP, чужие домены, сканеры. На 80 nginx
  закрывает соединение без ответа, на 443 отклоняет TLS-рукопожатие через
  `ssl_reject_handshake` и не показывает сертификат.
- **vaultwarden.nyaners.ru.conf** — прокси на `127.0.0.1:8080` с поддержкой
  websocket. 80 редиректит на 443. `/admin` доступен только из
  `127.0.0.1` и `192.168.1.0/24`, снаружи nginx отвечает 403.

## TLS

Сертификаты Let's Encrypt через certbot, строки с пометкой
`managed by Certbot` в конфиге сайта добавлены им. Продление автоматическое
таймером certbot.

## Применить изменения

Из каталога `ansible/`, сначала проверка, потом применение:

```sh
ansible-playbook playbooks/nginx.yml --check --diff
ansible-playbook playbooks/nginx.yml --diff
```

Роль сама проверяет конфиг через `nginx -t` и перечитывает nginx, только
если проверка прошла.

**Новый сайт:** положить файл в `sites-available/` и добавить его имя в
`nginx_sites` в `ansible/roles/nginx/defaults/main.yml`. Роль разложит его
и создаст симлинк в `sites-enabled`.

**Удалить сайт:** убрать имя из `nginx_sites` и добавить в
`nginx_sites_absent`. Роль удалит файл и симлинк на сервере.

**Выключить, не удаляя:** добавить имя в `nginx_sites_disabled`. Роль уберёт
только симлинк, файл на сервере останется.

Сайты называются по домену с суффиксом `.conf`, например
`vaultwarden.nyaners.ru.conf`. Суффикс нужен, чтобы редакторы не принимали
окончание `.ru` за расширение Ruby.
