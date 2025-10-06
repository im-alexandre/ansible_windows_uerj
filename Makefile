SHELL := /usr/bin/env bash
.PHONY: help setup venv galaxy ping graph deploy clean

help:
	@echo "Targets:"
	@echo "  setup     - prepara o ambiente no WSL (apt + venv + galaxy)"
	@echo "  venv      - cria/atualiza .venv e instala requirements.txt"
	@echo "  galaxy    - instala coleções/roles do requirements.yml"
	@echo "  ping      - win_ping no grupo laboratorio9003"
	@echo "  graph     - imprime o grafo do inventário"
	@echo "  mysql     - executa install_mysql.yml (Instala o mysql)"
	@echo "  wsl       - executa install_wsl.yml (Instala o wsl)"
	@echo "  deploy    - executa site.yml (base + mysql)"
	@echo "  packages  - instala apenas os pacotes em packages.txt"
	@echo "  clean     - remove .venv e artefatos"
	@echo ""
	@echo ""
	@echo "  variável 'env': para alterar o inventory, utilize a variável env=casa, isto utilizará o arquivo 'inventory_casa.ini'"
	@echo ""
	@echo ""

env ?=

setup:
	./scripts/setup_wsl.sh

venv:
	[ -d .venv ] || python3 -m venv .venv
	. .venv/bin/activate && python -m pip install --upgrade pip setuptools wheel && pip install -r requirements/requirements.txt

galaxy:
	. .venv/bin/activate && ansible-galaxy install -r requirements/requirements.yml

ping:
ifeq ($(env),)
	. .venv/bin/activate && ansible -i ./inventory.ini -m win_ping laboratorio9003
else
	. .venv/bin/activate && ansible -i ./inventory_$(env).ini -m win_ping laboratorio9003
endif

graph:
ifeq ($(env),)
	. .venv/bin/activate && ansible-inventory -i inventory.ini --graph
else
	. .venv/bin/activate && ansible-inventory -i inventory_$(env).ini --graph
endif

deploy:
ifeq ($(env),)
	. .venv/bin/activate && ansible-playbook -i "./inventory.ini" site.yml --skip-tags wsl
else
	. .venv/bin/activate && ansible-playbook -i "./inventory_$(env).ini" site.yml --skip-tags wsl
endif

packages:
ifeq ($(env),)
	. .venv/bin/activate && ansible-playbook -i "./inventory.ini" site.yml --tags packages,choco
else
	. .venv/bin/activate && ansible-playbook -i "./inventory_$(env).ini" site.yml --tags packages,choco
endif

wsl:
ifeq ($(env),)
	. .venv/bin/activate && ansible-playbook -i "./inventory.ini" site.yml --tags wsl
else
	. .venv/bin/activate && ansible-playbook -i "./inventory_$(env).ini" site.yml --tags wsl
endif

mysql:
ifeq ($(env),)
	. .venv/bin/activate && ansible-playbook -i "./inventory.ini" site.yml --tags mysql
else
	. .venv/bin/activate && ansible-playbook -i "./inventory_$(env).ini" site.yml --tags mysql
endif

clean:
	rm -rf .venv __pycache__
