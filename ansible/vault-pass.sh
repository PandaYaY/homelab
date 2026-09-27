#!/bin/sh
# Отдаёт Ansible пароль от Vault из файла .ansible-vault-pass рядом со скриптом.
# Нужен потому, что на /mnt/d любой файл выглядит исполняемым, и Ansible
# пытается запустить сам файл с паролем как скрипт.
cat "$(dirname "$0")/.ansible-vault-pass"
