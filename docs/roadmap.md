# Roadmap до middle DevOps

Персональный план на 9 месяцев, с 02.10.2026 по 30.06.2027, при 1–2 часах в
день, то есть около 40 часов в месяц и 360 часов всего. Каждый этап — реальное
изменение в этом репозитории. Прогресс отмечается чекбоксами, этапы и решения
по ходу дела записываются в [plan.md](plan.md).

Исходные данные: backend-разработчик на C# 1,5 года, до этого TypeScript;
Kubernetes знаком со стороны разработчика (Deployment, Service, Ingress,
ConfigMap), Octopus Deploy со стороны пользователя. Сервер: Orange Pi Zero3,
4 ГБ ОЗУ, 4 ядра ARM64, SD-карта 57 ГБ, занято 5 ГБ. Облако: только
бесплатные тарифы. Цель: рынок РФ, стек Linux, сети, Ansible, Kubernetes,
Argo CD.

## 1. Где я сейчас

Оценка по коду и истории коммитов на 02.10.2026. Весь репозиторий сделан за
пять дней, с 27.09 по 01.10.

### Уже на уровне middle

- **Ansible как инструмент, а не скрипт.** Роли с `defaults`, `handlers`,
  шаблонами; идемпотентность проверена, повторный прогон `site.yml` даёт
  ноль изменений. Учтены подводные камни `--check`: `check_mode: false` для
  команд-проверок, `force` для симлинков, `ignore_errors` для юнитов, которых
  ещё нет
  ([roles/nginx/tasks/main.yml](../ansible/roles/nginx/tasks/main.yml),
  [roles/backup/tasks/main.yml](../ansible/roles/backup/tasks/main.yml)).
- **Безопасные изменения.** `nginx -t` и `sshd -t` в handlers до reload,
  `validate: nft -c -f %s` у правил файрвола, `block/rescue` и таймер отката
  при применении nftables с проверкой нового SSH-соединения
  ([roles/firewall/tasks/main.yml](../ansible/roles/firewall/tasks/main.yml)).
  Это уровень, который многие middle не показывают.
- **Linux глубже, чем «поставить пакет».** Понимание порядка `Include` в
  sshd, сокет-активации, маскировки юнитов, таймеров systemd, сосуществования
  своей таблицы nftables с правилами Docker без `flush ruleset`.
- **Секреты.** Ни одного секрета в истории git, Vault, `diff: false` у
  задач с env, `.gitignore` на `*.env` и файл пароля, разбор стойкости пароля
  Vault в публичном репозитории ([review, п. 2–4](review-2026-09-27.md)).
- **Бэкапы с разбором отказов.** Онлайн-копия SQLite, проверка целостности,
  найденный и исправленный сценарий «пустая база с отметкой об успехе»
  (review, п. 1). Ретенция, инструкция восстановления в README.
- **Docker-гигиена.** Теги образов закреплены, порт только на `127.0.0.1`,
  ротация логов, `live-restore`, сборка образа вынесена в CI другого
  репозитория (find-air, GHCR, multi-arch).
- **Инженерная культура.** README на каждый сервис, ревью с важностью и
  статусами, журнал отложенных решений с аргументами
  ([plan.md, nginx остаётся в systemd](plan.md#nginx-остаётся-в-systemd-в-docker-не-переносится)).

### Пробелы

Прямо, без смягчений:

1. **Нет CI для самого репозитория.** Ни `ansible-lint`, ни `yamllint`, ни
   `--syntax-check` не запускаются автоматически. Всё применяется с ноутбука
   руками, коммиты идут прямо в `master` без PR.
2. **Нет наблюдаемости.** Если vaultwarden упадёт, диск заполнится или
   ночной бэкап завершится ошибкой, никто не узнает. Ошибка бэкапа видна
   только в `journalctl`, который никто не читает. Нет метрик, нет алертов,
   нет сбора логов (этап 6 плана открыт). У контейнеров нет `healthcheck`.
3. **Нет сценария «сервер умер».** Бэкапы на той же SD-карте, не
   зашифрованы (review, п. 14), восстановление целого сервера с нуля не
   описано и не репетировалось. Выпуск сертификата ручной
   ([roles/tls/tasks/main.yml](../ansible/roles/tls/tasks/main.yml)).
4. **Kubernetes только со стороны разработчика.** Нет опыта установки
   кластера, сети, хранилища, RBAC, обновлений, отладки «почему под не
   поднимается» на уровне узла. Helm, GitOps, operators не трогал.
5. **Нет доставки.** Обновление приложения: руками поменять тег в compose,
   руками запустить playbook. Нет автоматических обновлений зависимостей, нет
   отката как процедуры.
6. **Часть инфраструктуры вне кода.** Роутер OpenWrt (проброс портов,
   закрепление DHCP, будущий DNS), записи DNS на reg.ru, строки
   `managed by Certbot` в конфиге сайта. `192.168.1.0/24` продублирован в
   [vaultwarden.nyaners.ru.conf](../services/network/nginx/sites-available/vaultwarden.nyaners.ru.conf)
   и в `lan_cidr`, разъедутся незаметно.
7. **Сети: один хост в одной сети.** Нет VPN, нет внутреннего DNS, доступ из
   LAN зависит от NAT loopback. IPv6 учтён только в файрволе.
8. **Облако и Terraform: ноль.** На рынке РФ спрашивают Terraform с Yandex
   Cloud или VK Cloud почти в каждой вакансии middle.
9. **Нет тестов инфраструктуры.** Ошибка в бэкапе найдена ревью, а не
   тестом. Ни Molecule, ни хотя бы проверочного прогона в CI.
10. **Нет SRE-практик.** Нет SLO, нет инцидентов с постмортемами, нет
    runbook'ов на типовые отказы. Мелкие долги ревью (п. 7, 12, 13) висят.

## 2. Что такое middle DevOps

Критерий один: делает без подсказок и объясняет, почему именно так. Junior
делает по инструкции, middle пишет инструкцию.

**Linux и сети.** Читает `journalctl`, `ss`, `ip route`, `tcpdump`, `strace`
и находит причину, а не симптом. Пишет юниты и таймеры systemd. Настраивает
nftables или iptables и понимает, как Docker в них вмешивается. Объясняет
путь пакета: DNS, TCP handshake, TLS, HTTP, обратный прокси, NAT. Поднимает
WireGuard и split DNS.

**IaC и конфигурация.** Пишет роли Ansible с нуля, идемпотентные,
проверяемые в `--check`, с handlers и валидацией. Пишет модули Terraform,
понимает state, `plan` и `apply`, импорт существующих ресурсов, remote
backend. Отделяет данные от кода: inventory, group_vars, tfvars.

**Контейнеры и оркестрация.** Собирает минимальные образы, multi-stage,
non-root, multi-arch. Ставит и обновляет кластер Kubernetes, настраивает
ingress, storage class, RBAC, limits и requests, probes, NetworkPolicy.
Отлаживает `CrashLoopBackOff`, `Pending`, `ImagePullBackOff` по событиям и
логам. Пишет Helm-чарты и values, понимает Kustomize.

**CI/CD.** Строит пайплайн: lint, тесты, сборка, публикация образа, деплой с
окружениями и ручным подтверждением. GitOps через Argo CD: кластер
подтягивает желаемое состояние из git. Автообновление зависимостей через
Renovate. Умеет откатить.

**Наблюдаемость.** Ставит Prometheus, пишет PromQL и alerting rules,
настраивает Alertmanager с маршрутизацией, строит дашборды Grafana. Собирает
логи в Loki и ищет в них через LogQL. Знает, что такое трейсы и зачем
OpenTelemetry. Делает алерты, по которым нужно действовать, а не шум.

**Безопасность и секреты.** Секреты вне git: Ansible Vault, SOPS, Sealed
Secrets, Kubernetes Secrets с ограничением RBAC. Минимальные права, ключи
вместо паролей, файрвол по умолчанию закрыт, автообновления безопасности,
TLS везде, ротация секретов как процедура.

**Бэкапы и восстановление.** Правило 3-2-1, шифрование копий вне сервера,
регулярная репетиция восстановления с замером RTO и RPO, бэкап состояния
кластера, а не только данных приложений.

**Облака.** Поднимает VPC, подсети, security groups, ВМ, managed-сервисы
через Terraform. Понимает, за что платит. На рынке РФ: Yandex Cloud, VK
Cloud, Selectel.

**SRE-практики.** Формулирует SLI и SLO, считает error budget, ведёт
инциденты по шагам: обнаружение, диагностика, устранение, постмортем без
поиска виноватых. Пишет runbook на каждый алерт.

**Работа с кодом.** PR и ревью даже в одиночку, CI на каждый PR, ADR на
решения, документация рядом с кодом и актуальная, тесты инфраструктуры там,
где цена ошибки высока.

## 3. Этапы

Правила для всех этапов:

- ветка, PR, зелёный CI, merge. Прямых коммитов в `master` больше нет;
- любое изменение на сервере сначала `--check --diff`;
- новый сервис — новая папка в `services/` со своим README;
- решение, которое не очевидно, записывается в `plan.md`, раздел «Отложенные
  решения», с датой и аргументами;
- в конце этапа обновить README, схему и этот файл.

Память сервера на весь план: сейчас занято 650 МБ из 3900. k3s возьмёт
около 600, стек мониторинга 500, Loki 150, Argo CD 400. Остаётся запас, но
узкое место не память, а SD-карта: Prometheus и Loki пишут постоянно. Короткая
ретенция, редкий scrape, а при первой возможности USB-SSD под `/var/lib`.

### Этап 1. CI и рабочий процесс

- [ ] сделано

**Закрывает:** пробелы 1 и 9, область CI/CD и работа с кодом.

**Сделать:**

- `.github/workflows/ci.yml`: `yamllint`, `ansible-lint` с профилем
  `production`, `ansible-playbook playbooks/site.yml --syntax-check`,
  `ansible-galaxy collection install -r requirements.yml`. Vault в CI не
  расшифровывается: подложить `vault.yml` заглушкой из `vault.example.yml`
  через переменную `ANSIBLE_VAULT_PASSWORD_FILE` на фиктивный файл или
  `--vault-id` с пустым паролем и `vault.example.yml` вместо настоящего.
- `.yamllint.yml`, `.ansible-lint` в корне, `.pre-commit-config.yaml` с теми
  же проверками, чтобы ловить до пуша.
- Исправить всё, что найдёт `ansible-lint`: имена задач, `fqcn`,
  `no-changed-when`, `risky-file-permissions`. Это первое столкновение с
  тем, как выглядит «правильный» Ansible снаружи.
- Защита ветки `master` в настройках GitHub: PR обязателен, CI обязателен.
- Бейдж CI в README.

**Почему так.** GitHub Actions уже используется для find-air, репозиторий на
GitHub. На рынке РФ чаще GitLab CI: после этапа посмотреть на
`.gitlab-ci.yml` и понять, что stages, jobs, artifacts и rules — те же
понятия с другими именами. Делать параллельный пайплайн не нужно.

**Теория:** документация ansible-lint, раздел Rules; GitHub Docs,
Workflow syntax.

**Готово, когда:** PR с ошибкой в YAML или задачей без `name` блокируется
CI; `master` не принимает прямой push; `pre-commit run -a` проходит.

**Время:** 10 часов.

**Вопросы на собеседовании:** чем `--syntax-check` отличается от `--check`;
как хранить секреты в CI и чем плох `echo $SECRET`; что такое идемпотентность
и как её проверить автоматически; зачем линтер инфраструктурному коду; как
устроены `rules` и `needs` в пайплайне.

### Этап 2. Долги ревью и сайты nginx как шаблоны

- [ ] сделано

**Закрывает:** пробел 6 и открытые пункты ревью 7, 12, 13, задачу плана про
строки certbot. Область IaC.

**Сделать:**

- Review п. 12: `systemctl reset-failed homelab-firewall-revert.service`
  перед `systemd-run` в [roles/firewall](../ansible/roles/firewall/tasks/main.yml),
  `failed_when: false`.
- Review п. 7: переменная `apps_absent` в `vars.yml` и задачи в
  `compose_app` или отдельный блок в `apps.yml`: `docker compose down`,
  последний бэкап через `homelab-backup`, удаление `/opt/<app>`.
- Review п. 13: `Unattended-Upgrade::Origins-Pattern` с
  `origin=Docker` в `/etc/apt/apt.conf.d/52-homelab.conf`, роль `docker`.
- Сайты nginx в шаблоны: `services/network/nginx/sites-available/*.conf.j2`,
  роль раскладывает через `template`. В шаблон vaultwarden входят
  `{{ lan_cidr }}` вместо захардкоженной сети и блок TLS, который сейчас
  принадлежит certbot. Дубль сети исчезает, строки certbot становятся
  строками репозитория.
- Выпуск сертификата в роль `tls`: `certbot certonly --webroot -w
  /var/www/certbot -d {{ item }}` с `creates:` на `fullchain.pem`, чтобы
  задача была идемпотентной; deploy-hook `systemctl reload nginx`. Плагин
  `python3-certbot-nginx` больше не нужен: он правит конфиг, который теперь
  рендерит Ansible. Для webroot нужен `location /.well-known/acme-challenge/`
  в сайте на 80, до редиректа.
- Отметить пункты 7, 12, 13 в review как исправленные.

**Почему так.** Конфиг с пометками `managed by Certbot` принадлежит двум
хозяевам, и это ломает принцип «репозиторий описывает желаемое состояние».
Альтернатива для собеседования: ACME через `acme.sh` или Caddy с
автоматическим TLS, DNS-01 валидация для wildcard.

**Теория:** Certbot docs, раздел Webroot; Ansible docs, `template` и
`creates`.

**Готово, когда:** `site.yml --check` на чистом inventory даёт ноль
изменений; удалённое из `apps` приложение останавливается на сервере;
`certbot renew --dry-run` проходит через webroot; в конфигах на сервере нет
ни одной строки, которой нет в репозитории.

**Время:** 12 часов.

**Вопросы:** как работает ACME и чем http-01 отличается от dns-01; что такое
`creates` и когда его мало; как Ansible решает, что задача changed; что
сделает unattended-upgrades с пакетом из стороннего репозитория.

### Этап 3. Split DNS и роутер в репозитории

- [ ] сделано

**Закрывает:** пробел 7, этап 7 плана. Область сетей.

**Сделать:**

- Хост `router` в `inventory/hosts.yml`, группа `network`,
  `ansible_connection: ssh`, без python: на OpenWrt работают только `raw`
  и `script`, либо ставится `python3-light` через `opkg`.
- Роль `openwrt_dns`: список доменов из `tls_domains`, по
  `uci add_list dhcp.@dnsmasq[0].address='/<домен>/192.168.1.226'` на
  каждый, `uci commit dhcp`, `service dnsmasq restart`. Проверка через
  `uci show dhcp` до изменения, чтобы роль была идемпотентной.
- Проброс портов и закрепление DHCP тоже в роль, через `uci`: сейчас они
  живут только в памяти роутера.
- Схема в README: добавить роутер как управляемый хост.
- Проверить из LAN: `dig vaultwarden.nyaners.ru` отдаёт `192.168.1.226`,
  `/admin` в логах nginx с реальным IP клиента, а не адресом роутера.

**Почему так.** Единственный способ держать роутер в желаемом состоянии без
второго инструмента. Альтернатива для собеседования: отдельный DNS в сети,
Pi-hole или AdGuard Home с условной переадресацией, и обычный `dnsmasq` на
Linux.

**Теория:** OpenWrt wiki, DNS and DHCP configuration (dnsmasq);
`man dnsmasq`, опции `address` и `server`.

**Готово, когда:** роль применяется повторно без изменений; с ноутбука в
LAN домен резолвится в локальный адрес; с телефона через мобильную сеть во
внешний; роутер после перезагрузки сохраняет правила.

**Время:** 10 часов.

**Вопросы:** как идёт разрешение имени от браузера до авторитативного
сервера; что такое NAT loopback и почему он плох; чем split DNS отличается от
split horizon на авторитативном сервере; что сломает DoH в браузере; как
Ansible работает с хостом без python.

### Этап 4. Бэкапы вне сервера и репетиция восстановления

- [ ] сделано

**Закрывает:** пробел 3, review п. 14, открытую задачу плана. Область бэкапов,
начало SRE.

**Сделать:**

- rclone с `crypt` поверх Google Drive или Яндекс Диска (WebDAV, работает
  из РФ без VPN). Ключи crypt и токен remote в Vault, конфиг rclone
  рендерится шаблоном в `/root/.config/rclone/rclone.conf` с правами `600`.
- В `homelab-backup.sh.j2` после локального архива: `rclone sync
  {{ backup_dir }} remote-crypt:homelab --max-age 8d`, или отдельный юнит
  `homelab-backup-offsite.service` с `After=homelab-backup.service`.
- `OnFailure=homelab-notify@%n.service` у обоих юнитов: шаблонный юнит,
  который шлёт сообщение в Telegram через `curl` к Bot API. Токен в Vault.
  Это первый алерт в системе.
- Бэкап того, что не в `data`: `/etc/letsencrypt` целиком, иначе после
  восстановления ждать лимит Let's Encrypt.
- `docs/runbooks/restore-server.md`: пошагово, от прошивки SD-карты до
  зелёной проверки. Выполнить его по-настоящему на второй SD-карте,
  записать время. Это и есть RTO.
- Решить и записать RPO: сутки. Если мало, обсудить `rclone` чаще.

**Почему так.** Бэкап, из которого ни разу не восстанавливались, не бэкап.
Альтернативы для собеседования: restic и borg с дедупликацией, Velero для
Kubernetes, снапшоты томов в облаке, pgBackRest для PostgreSQL.

**Теория:** rclone docs, Crypt; `man systemd.unit`, `OnFailure`; Vaultwarden
wiki, Backing up your vault.

**Готово, когда:** в облаке лежат архивы за 7 дней, прочитать их без
ключа нельзя; при отключённой сети ночной прогон присылает сообщение в
Telegram; сервер восстановлен с чистой карты по runbook'у меньше чем за час,
vaultwarden открывается, пароли на месте.

**Время:** 20 часов.

**Вопросы:** 3-2-1, RPO и RTO своими словами; почему бэкап рядом с данными
не защищает; что будет, если потерять ключ шифрования; как бэкапить базу под
нагрузкой; как убедиться, что бэкап рабочий, не восстанавливая всё.

### Этап 5. Мониторинг и алерты

- [ ] сделано

**Закрывает:** пробел 2. Область наблюдаемости.

**Сделать:**

- Новое приложение `services/apps/monitoring/`: compose с Prometheus,
  Alertmanager, Grafana, `node_exporter`, `cAdvisor`, `blackbox_exporter`.
  Всё публикуется только на `127.0.0.1` или в сеть compose, Grafana на
  `127.0.0.1:3000`. Добавить в `apps` в `vars.yml` с `backup` для данных
  Grafana.
- Grafana доступна из LAN через nginx как `grafana.home.nyaners.ru` только
  с `allow {{ lan_cidr }}`, домен резолвится через split DNS из этапа 3,
  сертификат самоподписанный или без TLS в LAN. Наружу не публикуется: это
  обходит условие из plan.md про второй публичный сервис, решение про
  Caddy/Traefik откладывается до k3s.
- Правила алертов в `services/apps/monitoring/rules/*.yml`: хост
  недоступен (решает blackbox, но с того же хоста, см. ниже), диск больше 80
  %, `node_filesystem_readonly`, контейнер перезапустился за 10 минут,
  сертификат истекает меньше чем через 14 дней, бэкап не завершался успешно
  больше 26 часов. Последнее через textfile collector: скрипт бэкапа пишет
  `homelab_backup_last_success_timestamp` в
  `/var/lib/node_exporter/textfile/backup.prom`.
- Alertmanager с receiver в Telegram, группировка, `repeat_interval`,
  правила тишины на время работ.
- Внешняя проверка, потому что сервер не может сообщить о собственной
  смерти: бесплатный Healthchecks.io или UptimeRobot на
  `https://vaultwarden.nyaners.ru`, оповещение в тот же Telegram. Записать в
  plan.md как осознанную зависимость от внешнего сервиса.
- Дашборд: один свой, не импортированный, с тем, на что реально смотреть:
  нагрузка, диск, память, состояние контейнеров, возраст бэкапа.
- Ретенция Prometheus 15 дней, `scrape_interval` 30 с, чтобы беречь SD.

**Почему так.** Prometheus и Grafana — стандарт де-факто, и то, что спросят
на любом собеседовании. На рынке РФ ещё жив Zabbix: знать, чем pull-модель
Prometheus отличается от агентской модели Zabbix, но не ставить. Для
собеседования также: VictoriaMetrics как замена Prometheus с меньшим
расходом ресурсов, часто встречается в РФ.

**Теория:** Prometheus docs, Getting started и Alerting rules; Google SRE
book, глава 6, Monitoring Distributed Systems, четыре золотых сигнала;
Grafana docs, Alertmanager Telegram receiver.

**Готово, когда:** `docker stop vaultwarden` присылает сообщение в Telegram
за 2 минуты; `fallocate` на 45 ГБ присылает алерт про диск; остановленный
таймер бэкапа через 26 часов присылает алерт; выключенный сервер
присылает сообщение от внешнего сервиса за 5 минут; месяц без ложных
срабатываний, иначе правило правится.

**Время:** 30 часов.

**Вопросы:** pull против push, что делать с короткоживущими задачами;
counter, gauge, histogram, что такое `rate` и почему `rate` по gauge
бессмысленно; как избежать алертов, по которым нечего делать; что такое
cardinality и чем она опасна; как мониторить то, что мониторит.

### Этап 6. Логи

- [ ] сделано

**Закрывает:** пробел 2, этап 6 плана. Область наблюдаемости.

**Сделать:**

- Loki и Promtail в тот же compose `monitoring`. Promtail читает journald
  и логи контейнеров из `/var/lib/docker/containers` с метками по имени
  контейнера через Docker service discovery.
- Loki с хранением в файловой системе, ретенция 14 дней, компакшн.
- Datasource в Grafana, панель логов nginx и vaultwarden рядом с метриками.
- Один алерт по логам через ruler Loki: больше 20 неудачных входов в
  vaultwarden за 5 минут с одного IP.
- Логи nginx в JSON через `log_format`, чтобы парсить без регулярок.

**Почему так.** Loki дешевле ELK по памяти в разы, на 4 ГБ это
единственный вариант. Для собеседования: ELK и OpenSearch, зачем
индексировать всё против индексировать только метки, Fluent Bit и Vector как
агенты.

**Теория:** Grafana Loki docs, Get started и LogQL; Promtail scrape
configs, `docker_sd_configs` и `journal`.

**Готово, когда:** в Grafana по `{container="vaultwarden"} |= "error"`
видны строки за последние 14 дней; 25 неверных паролей в vaultwarden
присылают алерт; Loki занимает меньше 2 ГБ на диске.

**Время:** 15 часов.

**Вопросы:** чем Loki отличается от Elasticsearch по модели хранения; что
такое structured logging и зачем; как не положить диск логами; как
соотнести лог с метрикой по времени; куда девать PII в логах.

### Этап 7. WireGuard

- [ ] сделано

**Закрывает:** пробел 7. Область сетей и безопасности.

**Сделать:**

- Роль `wireguard`: интерфейс `wg0`, `10.8.0.0/24`, ключи сервера в Vault,
  пиры в `vars.yml` списком с публичными ключами. UDP 51820 в
  `firewall_udp_public`, роль firewall дорабатывается под UDP.
- Проброс UDP 51820 на роутере через роль из этапа 3.
- Клиент на телефоне и ноутбуке. `AllowedIPs` только LAN и `10.8.0.0/24`,
  не весь трафик.
- Теперь Grafana, `/admin` vaultwarden и SSH доступны извне через VPN:
  `firewall_ssh_cidr` и `allow` в nginx расширяются на `10.8.0.0/24`.
- `wg show` экспортируется в Prometheus через `prometheus-wireguard-exporter`
  или textfile, алерт не нужен.

**Почему так.** Единственный безопасный способ дать себе доступ к LAN-only
сервисам. Для собеседования: OpenVPN и IPsec, зачем Tailscale и
Headscale, что такое zero trust.

**Теория:** wireguard.com, Quick Start и Conceptual Overview;
Ubuntu Server docs, WireGuard.

**Готово, когда:** с телефона через мобильную сеть открывается Grafana по
LAN-адресу; SSH снаружи без VPN отбивается файрволом, через VPN проходит;
роль идемпотентна.

**Время:** 10 часов.

**Вопросы:** как WireGuard находит пира и зачем `PersistentKeepalive`; что
такое `AllowedIPs` с точки зрения маршрутизации; чем WireGuard отличается от
OpenVPN; как ограничить VPN-клиента одной сетью.

### Этап 8. Доставка: Renovate и деплой по merge

- [ ] сделано

**Закрывает:** пробел 5. Область CI/CD.

**Сделать:**

- Renovate через GitHub App на репозиторий: следит за тегами образов в
  `services/apps/*/docker-compose.yaml`, версиями коллекций в
  `requirements.yml`, actions в workflows. `renovate.json` с группировкой
  и расписанием, мажорные обновления vaultwarden только вручную.
- Self-hosted runner GitHub Actions на сервере, ARM64, как systemd-сервис
  через роль `gh_runner`. Токен регистрации в Vault.
- `deploy.yml`: на push в `master` runner запускает
  `ansible-playbook playbooks/site.yml --diff` с `ansible_connection: local`.
  Пароль Vault в GitHub Secrets. На PR тот же playbook с `--check --diff`,
  результат комментарием в PR.
- Опасность: публичный репозиторий плюс self-hosted runner. В настройках
  Actions запретить запуск workflow из форков без одобрения, runner только
  для этого репозитория. Записать в plan.md.
- `healthcheck` в compose у vaultwarden и find-air, чтобы
  `docker compose up` ждал готовности, а смена тега с битым образом не
  считалась успехом. В `deploy.yml` после playbook шаг проверки:
  `curl -f https://vaultwarden.nyaners.ru/alive`.
- Откат: инструкция в README, `git revert` плюс merge, деплой сделает
  остальное. Проверить один раз на find-air.

**Почему так.** Это замыкает цикл: Renovate открывает PR на новый
vaultwarden, CI проверяет, merge применяет, healthcheck подтверждает, алерт
из этапа 5 ловит остальное. Для собеседования: `ansible-pull` как GitOps
для серверов, GitLab Runner с executor shell и docker, Octopus как
deployment-инструмент с окружениями, которые ты уже видел, blue-green и
canary.

**Теория:** Renovate docs, Docker datasource; GitHub Docs, Security
hardening for self-hosted runners; Docker Compose, `healthcheck` и
`depends_on` с `condition`.

**Готово, когда:** новый релиз vaultwarden появляется как PR в течение
суток; merge PR обновляет сервер без ручных действий; PR с ошибкой в роли
получает комментарий с diff от `--check`; откат через revert занимает
меньше 10 минут.

**Время:** 20 часов.

**Вопросы:** чем GitOps отличается от CI-деплоя по SSH; как сделать деплой
безопасным, если runner стоит на проде; что такое rolling, blue-green,
canary; как откатить, если миграция базы необратима; как не дать Renovate
сломать прод.

### Этап 9. k3s на сервере

- [ ] сделано

**Закрывает:** пробел 4. Область контейнеров и оркестрации, уровень
оператора.

**Сделать:**

- Роль `k3s`: установка через официальный скрипт с закреплённой версией
  `INSTALL_K3S_VERSION`, `config.yaml` в `/etc/rancher/k3s/`:
  `disable: [traefik, servicelb]`, чтобы не воевать с nginx за 80 и 443,
  `write-kubeconfig-mode: 0640`. Kubeconfig забирается на ПК через `fetch`,
  адрес сервера подставляется.
- Порт 6443 только из LAN и VPN в файрволе. Flannel и его правила
  nftables: убедиться, что таблица `inet homelab` не ломает трафик подов.
  Это первый реальный конфликт, разобраться, а не отключить файрвол.
- Папка `k8s/` в репозитории. Первое приложение: find-air как Deployment
  с одной репликой, `strategy: Recreate` (SQLite не терпит двух писателей),
  PVC на `local-path`, Secret из Vault через Ansible-задачу
  `kubernetes.core.k8s`, пока нет GitOps. Перед переносом: остановить compose
  версию, восстановить `data` из бэкапа в PV. Это маленькая миграция с
  планом и откатом.
- `resources.requests` и `limits`, `livenessProbe` и `readinessProbe` у
  find-air. У бота нет HTTP, значит `exec`-проба или добавить `/healthz` в
  код бота. Второе честнее.
- Бэкап k3s: `/var/lib/rancher/k3s/server/db` (SQLite вместо etcd на одном
  узле) и PV `local-path` в `/var/lib/rancher/k3s/storage` добавить в
  `homelab-backup`.
- Обновление k3s: поменять версию в роли, прогнать, посмотреть, что
  произошло с подами. Сделать один раз на минорной версии.
- Дать себе три поломки и починить по событиям: образ с опечаткой, limit
  памяти меньше потребления, PVC с несуществующим storage class.

**Почему так.** k3s — полноценный Kubernetes, проходит conformance, но
ставится одной командой и живёт в 600 МБ. Для собеседования: kubeadm и чем
отличается control plane на etcd, managed Kubernetes в Yandex Cloud,
kind и minikube для локальных тестов, Talos как ОС для кластера.

**Теория:** k3s docs, Configuration Options, Networking, Volumes and
Storage; Kubernetes docs, Configure Liveness, Readiness and Startup Probes;
Kubernetes Up & Running, главы про Pods, Deployments, Storage.

**Готово, когда:** `kubectl get nodes` с ПК; find-air работает в k3s с
данными, compose-версия удалена через `apps_absent`; `kubectl delete pod`
поднимает нового за 30 секунд с теми же данными; обновление k3s на один
минор прошло без потери PV; все три поломки диагностированы по `kubectl
describe` и `kubectl logs` без гугла.

**Время:** 40 часов.

**Вопросы:** что происходит от `kubectl apply` до запущенного контейнера;
зачем requests, если есть limits; чем readiness отличается от liveness и
что будет, если перепутать; как под получает IP и как трафик идёт между
узлами; что такое PV, PVC, StorageClass и почему `local-path` не для прода;
что в etcd и как его бэкапить.

### Этап 10. Helm, Argo CD и секреты в кластере

- [ ] сделано

**Закрывает:** пробелы 4 и 5, GitOps. Области CI/CD и секретов.

**Сделать:**

- Argo CD в k3s через Helm, минимальный профиль: без Dex, без
  notifications, `resources` подрезаны под 400 МБ. UI только из LAN и VPN
  через nginx или `kubectl port-forward`.
- find-air переписать в Helm-чарт `k8s/charts/find-air` с `values.yaml`:
  тег образа, лимиты, расписание. Шаблоны писать руками, не через `helm
  create`, чтобы понять каждую строку.
- `k8s/argocd/`: Application на find-air, затем app-of-apps с корневым
  Application, который следит за папкой. `syncPolicy.automated` с `prune`
  и `selfHeal`.
- Секреты: Sealed Secrets. Контроллер в кластере, `kubeseal` на ПК,
  зашифрованный `SealedSecret` в git. Ключ контроллера в бэкап. Задачу
  `kubernetes.core.k8s` из этапа 9 удалить.
- Renovate на `values.yaml`: новый тег find-air из GHCR приходит как PR,
  merge, Argo синхронизирует. Полный путь: релиз в репозитории бота, образ,
  PR, под в кластере, ни одной ручной команды.
- Дрейф: поменять реплики руками через `kubectl scale`, увидеть
  `OutOfSync`, увидеть, как `selfHeal` возвращает.

**Почему так.** Argo CD в целевом стеке, и это самая частая GitOps-связка в
вакансиях. Для собеседования: Flux как альтернатива с теми же идеями, SOPS
с age вместо Sealed Secrets и external-secrets с HashiCorp Vault как
«взрослый» вариант, Kustomize против Helm, Argo Image Updater.

**Теория:** Argo CD docs, Getting Started и Cluster Bootstrapping
(app-of-apps); Helm docs, Chart Template Guide; Sealed Secrets README.

**Готово, когда:** push тега в `values.yaml` приводит к новому поду без
команд с ПК; ручное изменение в кластере откатывается Argo за 3 минуты;
`kubeseal` даёт секрет, который можно закоммитить; `helm lint` и
`helm template` в CI на каждый PR.

**Время:** 30 часов.

**Вопросы:** что такое GitOps и чем pull-модель Argo лучше push из CI; как
Argo понимает, что есть дрейф; как хранить секреты в git безопасно и что
делать при утечке ключа; жизненный цикл релиза Helm, что такое hooks; как
Argo обрабатывает CRD и порядок применения (sync waves).

### Этап 11. Наблюдаемость в кластере

- [ ] сделано

**Закрывает:** пробел 4 в части operators и CRD, пробел 2 для k3s.

**Сделать:**

- `kube-prometheus-stack` через Argo CD с values под 4 ГБ: без
  `prometheus-operator` admission webhook, без `kube-etcd` (его нет),
  Grafana из compose переезжает сюда с теми же дашбордами через
  ConfigMap-provisioning. Loki через чарт `loki` в режиме single binary,
  Promtail заменяется на Alloy или остаётся Promtail как DaemonSet.
- Правила из этапа 5 переписываются в `PrometheusRule`, Alertmanager
  конфиг в Secret через Sealed Secrets. Node, cAdvisor, blackbox как
  `ServiceMonitor` и `Probe`.
- Compose-версия `monitoring` живёт параллельно неделю, потом удаляется
  через `apps_absent`. Данные Grafana переносятся.
- Трейсы: маленький сервис на ASP.NET Core minimal API, `/healthz`,
  `/metrics` через `prometheus-net`, OpenTelemetry в Tempo single binary.
  Образ multi-arch в GitHub Actions, деплой через чарт и Argo. Это
  единственный путь увидеть трейсы в этом стеке, и он играет на твоей
  сильной стороне.

**Почему так.** Это переделка работающего, но закрывает operators, CRD,
Helm values большого чарта и миграцию между платформами. Если к 7-му
месяцу времени нет, можно оставить мониторинг в compose и ограничиться
`kube-state-metrics` плюс scrape k3s снаружи. Для собеседования:
VictoriaMetrics operator, OpenTelemetry Collector как единая точка сбора.

**Теория:** kube-prometheus-stack values и README; Grafana Tempo docs,
Getting started; OpenTelemetry .NET, Getting started.

**Готово, когда:** все алерты этапа 5 работают из кластера, compose
удалён; в Grafana трейс запроса в .NET-сервис от nginx до ответа; алерт
`KubePodCrashLooping` приходит в Telegram на сломанном find-air.

**Время:** 25 часов.

**Вопросы:** что такое operator и CRD, зачем они; как Prometheus находит
цели в Kubernetes; разница между метриками, логами и трейсами и когда что
смотреть; что такое OpenTelemetry и чем collector лучше прямой отправки;
как ограничить ресурсы стека мониторинга, чтобы он не съел кластер.

### Этап 12. Terraform и облако

- [ ] сделано

**Закрывает:** пробел 8. Области IaC и облаков.

**Сделать:**

- Минимум, который остаётся навсегда: DNS `nyaners.ru` переехать с reg.ru
  на Cloudflare, бесплатно, домен остаётся на reg.ru, меняются только NS.
  `terraform/dns/`: provider cloudflare, записи для всех сервисов, токен в
  переменной окружения. Существующие записи через `terraform import`.
  State локально, в `.gitignore`, пока нет remote backend.
- Расширенный опыт на грант Yandex Cloud для новых аккаунтов:
  `terraform/yc/`: сеть, подсеть, security group, одна ВМ ARM или x86,
  state в Object Storage как S3-backend. На ВМ прогнать `hardening.yml` и
  `docker.yml` через динамический inventory или `terraform output` в
  hosts. Поднять там WireGuard-пир и k3s agent, подключить к кластеру дома
  как второй узел через VPN. Посмотреть, как планировщик раскидывает поды,
  сделать `kubectl drain`. По окончании гранта `terraform destroy`.
- CI: `terraform fmt -check`, `validate`, `tflint`, `plan` на PR.
- Записать в plan.md: что стоило денег, что бесплатно, что сломалось.

**Почему так.** Terraform с Yandex Cloud спрашивают почти в каждой вакансии
РФ. Terraform против OpenTofu: синтаксис тот же, лицензия разная, знать
историю. Для собеседования: Pulumi, CloudFormation, модули и workspaces,
drift detection.

**Теория:** Terraform docs, Get Started и State; Yandex Cloud, Terraform
provider docs и quickstart; Cloudflare provider docs.

**Готово, когда:** записи DNS меняются только через PR и `terraform
apply`; `terraform plan` без изменений даёт ноль; ВМ в Yandex Cloud
поднята, подключена к k3s как узел, уничтожена, и в консоли нет
забытых ресурсов.

**Время:** 25 часов.

**Вопросы:** что в state и почему его нельзя терять; что такое lock и зачем
remote backend; как импортировать существующее; чем `taint` отличается от
`replace`; как структурировать проект на несколько окружений; что такое
provider и как он версионируется.

### Этап 13. SLO, учебные инциденты, постмортемы

- [ ] сделано

**Закрывает:** пробел 10. Область SRE. Идёт параллельно с 4 по 9 месяц,
по одному инциденту в две-три недели.

**Сделать:**

- `docs/slo.md`: SLI для vaultwarden — доля успешных проверок blackbox за
  30 дней, SLO 99,5 %, то есть 3,6 часа простоя в месяц. Панель error
  budget в Grafana. Алерт на скорость сгорания бюджета (burn rate), а не на
  факт недоступности.
- `docs/runbooks/`: по одному на каждый алерт из этапа 5: что значит,
  что проверить, что сделать, когда эскалировать.
- `docs/incidents/YYYY-MM-DD-<slug>.md` на каждый учебный инцидент:
  хронология, причина, что помогло, что мешало, действия. Шаблон из
  SRE book.
- Список учебных инцидентов, устроить себе без предупреждения, в
  календаре на неделю вперёд:
  - `kill -9` nginx и смотреть, кто первым заметит;
  - заполнить диск до 100 % во время бэкапа;
  - испортить `db.sqlite3` и восстановить из бэкапа с замером времени;
  - вытащить SD-карту, восстановить сервер на запасной по runbook'у;
  - сломать DNS на роутере;
  - дать find-air limit памяти 32 МБ;
  - истёкший сертификат: `certbot` с `--force-renewal` на staging-CA;
  - удалить namespace argocd и восстановить из git.
- Неделя «дежурства»: алерты на телефон, обязательство реагировать в
  15 минут в любое время, потом честный разбор, сколько раз это
  получилось.

**Почему так.** На собеседовании middle не спрашивают, знает ли он слово
SLO, а просят рассказать про инцидент, который он вёл. Без них рассказывать
нечего. Для собеседования: PagerDuty и Opsgenie, chaos engineering, blameless
culture.

**Теория:** Google SRE book, главы 4 (SLO) и 15 (Postmortem Culture); SRE
Workbook, глава 5 (Alerting on SLOs).

**Готово, когда:** восемь инцидентов задокументированы, у каждого есть
хотя бы одно действие, которое попало в репозиторий; error budget виден в
Grafana; каждый алерт ссылается на runbook в аннотации.

**Время:** 20 часов.

**Вопросы:** разница SLA, SLO, SLI; как считать error budget и что делать,
когда он кончился; что такое burn rate alert и чем лучше порога; как
выглядит хороший постмортем; расскажите про инцидент, который вы вели, по
шагам.

### Этап 14. Капстоун: vaultwarden в k3s, cert-manager, прощание с certbot

- [ ] сделано

**Закрывает:** всё вместе. Необязательный, если 7–9 месяцы ушли на 11–13.

**Сделать:**

- Это момент из plan.md: второй публичный сервис за прокси. Записать
  решение: ingress-nginx или Traefik в k3s на 80 и 443, cert-manager с
  http-01 или dns-01 через Cloudflare из этапа 12, nginx и certbot в systemd
  выводятся.
- Чарт vaultwarden, PVC, Sealed Secret с admin token, Ingress с
  ограничением `/admin` по IP через аннотации. Миграция данных из
  `/opt/vaultwarden/data` с окном простоя, объявленным себе заранее, план
  отката: compose остаётся на диске до конца недели.
- Grafana, Argo CD UI через тот же ingress, только из LAN и VPN.
- Роли `nginx` и `tls` помечаются устаревшими, `nginx_sites_absent`,
  удаление пакетов, обновление схемы в README.

**Готово, когда:** внешний пользователь не заметил миграцию, кроме
объявленного окна; сертификаты продлеваются cert-manager; на сервере нет
nginx в systemd; runbook восстановления сервера переписан под k3s и
выполнен один раз.

**Время:** 30 часов.

**Вопросы:** как спланировать миграцию с состоянием и откатом; как
ingress-контроллер получает трафик на одном узле без LoadBalancer; как
cert-manager хранит и продлевает сертификаты; что такое downtime window и
как объявлять его пользователям.

## 4. Чего один домашний сервер не даст

- **Масштаб: десятки хостов, динамический inventory.** Замена: этап 12,
  три ВМ в Yandex Cloud на грант, одни и те же роли на группу хостов,
  `yandex cloud` dynamic inventory plugin. Один вечер на `ansible -m ping`
  по 10 хостам стоит больше, чем месяц на одном.
- **Многозональность и managed Kubernetes.** Замена: на том же гранте
  поднять Managed Kubernetes на 2 узла в разных зонах, прогнать через него
  чарт find-air из этапа 10, снести. Читать архитектурные схемы в
  документации Yandex Cloud и AWS Well-Architected: это пересказывают на
  собеседованиях.
- **Kubernetes в проде: HA control plane, etcd, upgrade без простоя.**
  Замена: три ВМ в WSL2 или Hyper-V на ПК, k3s с embedded etcd на три
  сервера, обновить по одному с `drain`, убить один узел и смотреть.
  Одна неделя.
- **Дежурства.** Замена: этап 13, неделя с алертами на телефоне и
  обязательством реагировать. Полной замены нет: настоящее дежурство
  отличается тем, что инцидент не твой.
- **Команда и ревью.** Замена: PR в open source, где инфраструктура:
  `k3s-io/k3s-ansible`, коллекции Ansible, документация vaultwarden, Helm
  charts. Один принятый PR за 9 месяцев. Читать чужие постмортемы: сайт
  incident.io, GitHub status post-incident reviews. Разбор своих PR с
  Claude в роли ревьюера, но настоящий ревьюер в open source строже.
- **Базы данных под нагрузкой.** В стеке только SQLite. Замена: PostgreSQL
  в k3s для .NET-сервиса из этапа 11, `pg_dump` в бэкап, одна репликация
  в ВМ на ПК, чтобы понять WAL. На собеседованиях middle в РФ спрашивают
  про бэкап и реплику PostgreSQL почти всегда.
- **Enterprise-инструменты: GitLab, Jenkins, HashiCorp Vault.** На 4 ГБ
  GitLab не живёт. Замена: бесплатный gitlab.com с зеркалом репозитория и
  тем же CI в `.gitlab-ci.yml`, два вечера. Vault: dev-режим в Docker на
  ПК, прочитать про auth methods и dynamic secrets, не внедрять.
- **Стоимость и FinOps.** На бесплатных тарифах не чувствуется. Замена:
  посчитать на калькуляторе Yandex Cloud, во сколько обойдётся этот homelab
  в облаке, записать в plan.md.

## 5. Горизонты

**Месяц 1, октябрь 2026.** Этапы 1, 2, 3. Около 32 часов. Результат:
репозиторий с CI, без долгов ревью, роутер под управлением, split DNS.

**Месяцы 2–3, ноябрь–декабрь.** Этапы 4, 5, 6, 7. Около 75 часов.
Результат: бэкапы вне сервера, репетиция восстановления, мониторинг, логи,
алерты в Telegram, VPN. Сервер впервые сообщает о проблемах сам.

**Месяцы 4–6, январь–март 2027.** Этапы 8, 9, 10, первые инциденты из
13. Около 95 часов. Результат: автодоставка через Renovate и runner, k3s с
find-air, Helm, Argo CD, Sealed Secrets. Полный путь от релиза до пода без
ручных команд.

**Собеседования с 7-го месяца, апрель 2027.** После этапа 10 с
мониторингом из этапа 5 портфолио достаточно для middle. Что показывать:

- README со схемой и таблицей сервисов, за три минуты понятно, что сделано;
- `docs/review-2026-09-27.md` и `docs/incidents/`: умение находить и
  разбирать проблемы;
- `docs/plan.md`, отложенные решения: умение не делать лишнего и объяснять
  почему;
- роль firewall с откатом по таймеру: любимый вопрос «как вы меняете
  файрвол удалённо»;
- пайплайн от релиза find-air до пода в k3s через Renovate и Argo CD;
- дашборд Grafana и правила алертов, с рассказом, какие сработали
  по-настоящему;
- runbook восстановления сервера с замеренным временем.

Рассказ на собеседовании строится не «я поставил Prometheus», а «у меня
молча падал бэкап, я сделал алерт на возраст последнего успешного, он
сработал через месяц вот из-за чего».

**Месяцы 7–9, апрель–июнь 2027.** Этапы 11, 12, 13 до конца, 14 если
остаётся время. Около 100 часов. Параллельно собеседования: каждый вопрос,
на который не получилось ответить, записывается в этот файл в раздел ниже,
и на него ищется ответ в репозитории, а не в википедии.

## Вопросы с собеседований без ответа

Сюда записывать вопросы, на которых споткнулся, с датой. Закрывать
изменением в репозитории или заметкой в plan.md.

- 
