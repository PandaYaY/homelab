# homelab

Домашняя инфраструктура: один сервер на Orange Pi Zero3, на нём nginx как
обратный прокси и сервисы в Docker. Репозиторий хранит желаемое состояние
конфигураций и, позже, Ansible для их применения.

## Сервер

| Параметр | Значение |
|---|---|
| Хост | `orangepizero3` |
| Железо | Orange Pi Zero3, Allwinner H618, ARM64 |
| ОС | Armbian (на базе Debian: apt, systemd) |
| Пользователь SSH | `nyaners` |
| LAN | `192.168.1.0/24`, статический адрес `192.168.1.226` |

## Схема

```
Интернет
   |  80, 443
   v
Роутер (OpenWrt): проброс 80 и 443 на 192.168.1.226
   |
   v
orangepizero3 (192.168.1.226)
   |
   +-- nginx (systemd) :80 :443 -- TLS от certbot
   |     |
   |     +-- vaultwarden.nyaners.ru --> 127.0.0.1:8080
   |
   +-- docker
   |     +-- vaultwarden   127.0.0.1:8080 -> 80
   |     +-- findair       портов нет, ходит в Telegram API сам
   |
   +-- sshd :22  <-- ПК (Windows 11, Ansible из WSL) по LAN
```

## Сервисы

| Сервис | Где работает | Порт на сервере | Домен | Конфиг и описание |
|---|---|---|---|---|
| nginx | systemd | 80, 443 | vaultwarden.nyaners.ru | [services/network/nginx](services/network/nginx/README.md) |
| vaultwarden | Docker | 127.0.0.1:8080 | vaultwarden.nyaners.ru | [services/apps/vaultwarden](services/apps/vaultwarden/README.md) |
| find-air | Docker | нет | нет | [services/apps/find-air](services/apps/find-air/README.md) |

Кроме них на сервере слушают `sshd` (22), `systemd-resolved` (53, только
localhost), а также `rpcbind` (111) и `cupsd` (631), которые не нужны и
будут отключены на этапе hardening.

## Структура репозитория

```
services/
  network/nginx/      конфиги nginx, копия /etc/nginx
  apps/<сервис>/      docker-compose.yaml и templates/ с шаблонами env
ansible/              Ansible, см. ansible/README.md
```

Каждый сервис описан в своём README рядом с конфигами. Удаляешь сервис,
удаляешь папку целиком вместе с документацией.

## Соглашения

- Сервисы на сервере живут в `/opt/<сервис>`: там compose, отрендеренный
  env и каталог `data`. Сейчас они ещё в домашнем каталоге, перенос на
  этапе 4.
- Секреты в git не попадают. Файлы `*.env` игнорируются, вместо них лежат
  шаблоны `templates/*.env.j2` с переменными Jinja, значения хранятся в
  Ansible Vault.
- Репозиторий описывает желаемое состояние, а не снимок сервера. Расхождения
  устраняются применением конфигов из репозитория, а не правкой репозитория
  под сервер.
- Рабочую конфигурацию на сервере не трогаем руками, пока не согласовано.
  Первый прогон Ansible только с `--check --diff`.

## Этапы

1. Инвентаризация. Сделано.
2. Перенос конфигов в репозиторий. Сделано.
3. Документация. Сделано.
4. Ansible: inventory, роли, раскладка конфигов из `services/`. В работе.
5. Бэкапы (в первую очередь данные vaultwarden), TLS, hardening, установка
   Docker через Ansible.
