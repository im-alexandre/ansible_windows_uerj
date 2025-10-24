SHELL := /usr/bin/env bash
.PHONY: help setup venv galaxy ping graph deploy clean

help:
	@echo "Targets:"
	@echo "  setup     - prepara o ambiente no WSL (apt + venv + galaxy)"
	@echo "  venv      - cria/atualiza .venv e instala requirements.txt"
	@echo "  galaxy    - instala coleções/roles do requirements.yml"
	@echo "  ping      - win_ping no grupo nodes"
	@echo "  graph     - imprime o grafo do inventário"
	@echo "  deploy    - executa  (base + mysql)"
	@echo "  packages  - instala apenas os pacotes em packages.txt"
	@echo "  clean     - remove .venv e artefatos"

setup:
	chmod a+x ./scripts/setup_wsl.sh && ./scripts/setup_wsl.sh

venv:
	[ -d .venv ] || python3 -m venv .venv
	. .venv/bin/activate && python -m pip install --upgrade pip setuptools wheel && pip install -r requirements/requirements.txt

galaxy:
	. .venv/bin/activate && ansible-galaxy install -r requirements/requirements.yml

ping:
	. .env && . .venv/bin/activate && ansible -m win_ping all --limit '!localhost'

graph:
	. .env && . .venv/bin/activate && ansible-inventory --graph

deploy:
	. .env && . .venv/bin/activate && ansible-playbook site.yml

packages:
	. .env && . .venv/bin/activate && ansible-playbook site.yml --tags packages,choco -vv


clean:
	rm -rf .venv __pycache__
