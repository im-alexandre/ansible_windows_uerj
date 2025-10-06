# Projeto de Automação (Windows + Ansible + Chocolatey)

Este projeto instala e configura softwares em computadores Windows (laboratório) de forma padronizada, usando **Ansible** (no Ubuntu/WSL) e **Chocolatey** (no Windows). O **PostgreSQL** é instalado automaticamente via Chocolatey.

## Para quem é?
Para o encarregado do laboratório que **não precisa conhecer Ansible**. Basta seguir o passo a passo abaixo.

---
## Estrutura
```text
.
├── ansible.cfg
├── inventory.ini
├── packages.txt
├── requirements.txt
├── requirements.yml
├── site.yml
├── tasks/
│   ├── win_prep.yml
│   ├── choco_bootstrap.yml
│   ├── choco_packages.yml
│   ├── postgres_choco.yml
│   └── postgres_checks.yml
└── scripts/
    ├── setup_wsl.sh
    └── usb/
        ├── configura_ssh.ps1
        └── cria_inventory.ps1
```

### O que é cada arquivo?
- `inventory.ini`: lista os computadores do laboratório e como conectar neles.
- `packages.txt`: softwares a instalar via Chocolatey (ex.: git, dbeaver, python, postgresql).
- `requirements.txt`: bibliotecas Python necessárias para o Ansible.
- `requirements.yml`: dependências do Ansible Galaxy (se houver).
- `site.yml`: **playbook principal** com dois passos (instalar pacotes + instalar/checar PostgreSQL).
- `tasks/*.yml`: tarefas menores, reusadas dentro do `site.yml`.
- `scripts/setup_wsl.sh`: prepara o ambiente no Ubuntu/WSL automaticamente.
- `scripts/usb/*.ps1`: scripts para executar **no Windows**, com pendrive.

---
## Passo a passo (resumo)

### 1) Preparar cada computador Windows (com pendrive)
- Inserir pendrive
- Executar **como Administrador**:
  - `configura_ssh.ps1` (habilita e configura SSH)
  - `cria_inventory.ps1` (opcional: gera inventário local)

### 2) Preparar o computador controlador (Ubuntu/WSL)
```bash
./scripts/setup_wsl.sh
source .venv/bin/activate
```

### 3) Conferir conectividade com as máquinas
```bash
make graph    # Mostra inventário de hosts
make ping     # Testa comunicação (win_ping)
```

### 4) Executar a instalação (pacotes + PostgreSQL via Chocolatey)
```bash
make deploy
```

---
## Manutenção simples
- Para **adicionar/remover softwares**, edite o `packages.txt` (um por linha).
- Para alterar versão/nome do serviço do PostgreSQL, ajuste no `site.yml` as variáveis `postgres_package_name` e `postgres_service_name`.

---
## Perguntas comuns
- **Precisa saber Ansible?** Não. O `Makefile` e o `setup_wsl.sh` já deixam pronto para uso.
- **Onde rodam os comandos?** No **Ubuntu/WSL** (o controlador).
- **O que precisa no Windows?** Apenas rodar os scripts do pendrive como Admin para habilitar SSH e padronizar.

---
## Sugestões de evolução (opcional)
- Adicionar `ansible-lint` e criar `make lint` para validar playbooks.
- Centralizar variáveis em `group_vars/all.yml` para facilitar manutenção.
- Criar um alvo `make usb` para empacotar automaticamente apenas os scripts de pendrive.


---
## Configuração do PostgreSQL
- Usuário (superusuário): `postgres`
- Senha: `postgres`
- Banco padrão: `postgres`

Esses valores podem ser mudados no `site.yml` via variáveis:
```yaml
postgres_superuser: postgres
postgres_superuser_password: postgres
postgres_default_db: postgres
postgres_port: 5432
```
O playbook instala o PostgreSQL via Chocolatey já definindo a senha e, em seguida, garante (idempotente) que a senha está aplicada e que o banco existe.
