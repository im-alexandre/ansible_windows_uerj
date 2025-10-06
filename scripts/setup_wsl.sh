#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v apt >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip python3-dev build-essential libffi-dev libssl-dev openssh-client sshpass git make
fi

[ -d .venv ] || python3 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip setuptools wheel
[ -f requirements/requirements.txt ] && pip install -r requirements/requirements.txt
[ -f requirements/requirements.yml ] && ansible-galaxy install -r requirements/requirements.yml

echo "Ambiente pronto."
echo "Exemplos:"
echo "  source .venv/bin/activate"
echo "  make graph"
echo "  make ping"
echo "  make deploy"
