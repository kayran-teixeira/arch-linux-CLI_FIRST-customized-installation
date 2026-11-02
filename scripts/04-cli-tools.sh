#!/usr/bin/env bash
#
# scripts/04-aur-yay.sh - Provisionamento Seguro do AUR Helper (yay)
# Responsabilidades:
# 1. Garantir ferramentas de compilação essenciais (base-devel, git)
# 2. Configurar elevação temporária sem senha para o usuário alvo
# 3. Compilar e empacotar o yay via makepkg em espaço de usuário
# 4. Instalar o pacote binário gerado e verificar integridade
# 5. Revogar imediatamente a regra de sudo sem senha
# 6. Inicializar a base de dados do yay e limpar diretórios temporários
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[04-YAY]${NC} $1"; }
log_success() { echo -e "${GREEN}[04-YAY:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[04-YAY:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[04-YAY:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"

# -----------------------------------------------------------------------------
# 1. Pré-requisitos de Compilação
# -----------------------------------------------------------------------------
log_info "Verificando dependências base de compilação..."

# base-devel e git são mandatórios para o makepkg resolver dependências e compilar
pacman -S --noconfirm --needed base-devel git
log_success "Ferramentas base-devel e git confirmadas."

# -----------------------------------------------------------------------------
# 2. Elevação Temporária de Privilégios (Sudo sem senha efêmero)
# -----------------------------------------------------------------------------
# O makepkg -si invoca 'sudo pacman' para instalar as dependências de compilação (Go)
# e o pacote final. Se o sudo exigir senha em um script não-interativo, o processo quebra.
TEMP_SUDO_FILE="/etc/sudoers.d/99-temp-yay-bootstrap"

log_info "Concedendo privilégio temporário NOPASSWD para ${TARGET_USER}..."
cat <<EOF > "${TEMP_SUDO_FILE}"
${TARGET_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "${TEMP_SUDO_FILE}"

# Garantir remoção da permissão temporária mesmo em caso de erro prematuro
cleanup_sudo() {
    if [[ -f "${TEMP_SUDO_FILE}" ]]; then
        log_warn "Removendo arquivo de sudo temporário de segurança..."
        rm -f "${TEMP_SUDO_FILE}"
    fi
}
trap cleanup_sudo EXIT

# -----------------------------------------------------------------------------
# 3. Preparação do Diretório de Build
# -----------------------------------------------------------------------------
BUILD_DIR="/home/${TARGET_USER}/.cache/yay-bootstrap"

log_info "Preparando ambiente de build em ${BUILD_DIR}..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
chown -R "${TARGET_USER}:users" "${BUILD_DIR}"

# -----------------------------------------------------------------------------
# 4. Clone e Compilação do yay sob o Usuário Alvo
# -----------------------------------------------------------------------------
log_info "Clonando repositório PKGBUILD do yay e compilando..."

su - "${TARGET_USER}" -c "
    set -euo pipefail
    cd '${BUILD_DIR}'
    git clone https://aur.archlinux.org/yay.git yay-src
    cd yay-src

    # -s: resolve dependências via pacman automaticamente
    # -i: instala o pacote binário após compilar
    # --noconfirm: impede bloqueios esperando confirmação de terminal
    # --needed: não reinstala se já existente
    makepkg -si --noconfirm --needed
"

log_success "yay compilado e instalado com sucesso."

# -----------------------------------------------------------------------------
# 5. Revogação de Segurança e Limpeza
# -----------------------------------------------------------------------------
log_info "Revogando acesso NOPASSWD e higienizando ambiente..."
cleanup_sudo
# Desarma o trap para não disparar redundantemente
trap - EXIT

# Remove a árvore de build e o código fonte intermediário
rm -rf "${BUILD_DIR}"
log_success "Diretório de build temporário removido."

# -----------------------------------------------------------------------------
# 6. Validação e Ajustes Operacionais do yay
# -----------------------------------------------------------------------------
log_info "Validando integridade do binário yay..."

if ! su - "${TARGET_USER}" -c "command -v yay &>/dev/null"; then
    log_err "Binário yay não encontrado no PATH de ${TARGET_USER}."
    exit 1
fi

YAY_VER=$(su - "${TARGET_USER}" -c "yay --version | head -n1")
log_success "Instalação validada: ${YAY_VER}"

log_info "Configurando comportamento padrão do yay para ${TARGET_USER}..."
su - "${TARGET_USER}" -c "
    # Sincroniza a base local do yay com os pacotes instalados
    yay -Y --gendb

    # Define limpeza automática de pacotes de compilação órfãos
    yay --save --cleanafter --removemake
"

log_success "Base de dados do yay sincronizada e flags de limpeza salvas."
log_success "Módulo 04-aur-yay.sh finalizado com sucesso."