#!/usr/bin/env bash
#
# scripts/09-dev-services.sh - Instalação de Ferramentas de IA, Containers e Runtime Web
# Responsabilidades:
# 1. Instalar NodeJS e gerenciador de pacotes NPM
# 2. Instalar Docker engine, Docker Compose e Buildx
# 3. Habilitar serviço do Docker no systemd e associar usuário ao grupo docker
# 4. Instalar Claude Code CLI (@anthropic-ai/claude-code)
# 5. Instalar Antigravity CLI (agy) via script oficial
# 6. Validar binários e disponibilização no PATH do usuário
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[09-DEV]${NC} $1"; }
log_success() { echo -e "${GREEN}[09-DEV:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[09-DEV:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[09-DEV:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"
USER_HOME="/home/${TARGET_USER}"

# -----------------------------------------------------------------------------
# 1. Instalação do NodeJS, NPM e FNM (Fast Node Manager)
# -----------------------------------------------------------------------------
log_info "Instalando NodeJS, NPM e FNM dos repositórios oficiais..."

NODE_PACKAGES=(
    nodejs
    npm
    fnm
)

pacman -S --noconfirm --needed "${NODE_PACKAGES[@]}"
log_success "NodeJS, NPM e FNM instalados com sucesso."

# -----------------------------------------------------------------------------
# 2. Instalação e Configuração do Docker
# -----------------------------------------------------------------------------
log_info "Instalando stack Docker (Engine, Compose, Buildx)..."

DOCKER_PACKAGES=(
    docker
    docker-compose
    docker-buildx
)

pacman -S --noconfirm --needed "${DOCKER_PACKAGES[@]}"

# Configuração do daemon com limites de log e driver overlay2
log_info "Configurando /etc/docker/daemon.json com limites de rotação de log..."
mkdir -p /etc/docker
cat <<'EOF' > /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF

# Cria o grupo docker se ainda não existir
groupadd -f docker

# Adiciona o usuário alvo ao grupo docker (permite rodar sem sudo)
usermod -aG docker "${TARGET_USER}"
log_success "Usuário ${TARGET_USER} adicionado ao grupo docker."

# Habilita o daemon do Docker para inicialização automática no boot
log_info "Habilitando serviço docker.service no systemd..."
systemctl enable docker.service
log_success "Serviço do Docker habilitado."

# -----------------------------------------------------------------------------
# 3. Instalação do Claude Code CLI
# -----------------------------------------------------------------------------
log_info "Instalando Claude Code CLI (@anthropic-ai/claude-code) globalmente via npm..."

# Instalação global do Claude Code
npm install -g @anthropic-ai/claude-code

if command -v claude &>/dev/null; then
    log_success "Claude Code CLI instalado com sucesso: $(claude --version 2>/dev/null || echo 'instalado')"
else
    log_warn "Claude Code instalado via npm. Caso não esteja no PATH global, verifique /usr/local/bin ou prefixo npm."
fi

# -----------------------------------------------------------------------------
# 4. Instalação do Antigravity CLI (agy)
# -----------------------------------------------------------------------------
log_info "Instalando Antigravity CLI (agy) para o usuário ${TARGET_USER}..."

# Executa o instalador oficial como o usuário comum
su - "${TARGET_USER}" -c "
    curl -fsSL https://antigravity.google/cli/install.sh | bash
"

# Valida se o binário está acessível no home do usuário
AGY_BIN="${USER_HOME}/.local/bin/agy"
if [[ -f "${AGY_BIN}" ]]; then
    chmod +x "${AGY_BIN}"
    log_success "Antigravity CLI (agy) instalado com sucesso em ${AGY_BIN}."
else
    log_warn "Binário agy não encontrado em ${AGY_BIN}. Verifique a conexão com o servidor de download."
fi

# Garante que as permissões do diretório .local/bin fiquem com o usuário
chown -R "${TARGET_USER}:users" "${USER_HOME}/.local" 2>/dev/null || true

log_success "Módulo 09-dev-services.sh finalizado com êxito."
