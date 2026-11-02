#!/usr/bin/env bash
#
# install.sh - Orquestrador de Instalação e Bootstrap do Arch Linux (CLI-First Setup)
#
# Execução na Live ISO após particionamento e montagem manual em /mnt:
# TARGET_USER="kayran" USER_PASS="senha" ROOT_PASS="senha" ./install.sh
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INSTALLER]${NC} $1"; }
log_success() { echo -e "${GREEN}[INSTALLER:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[INSTALLER:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[INSTALLER:ERRO]${NC} $1" >&2; }

# -----------------------------------------------------------------------------
# 1. Validações Iniciais
# -----------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    log_err "Este script precisa ser executado como root (na Live ISO do Arch Linux)."
    exit 1
fi

TARGET_USER="${TARGET_USER:-kayran}"
USER_PASS="${USER_PASS:-}"
ROOT_PASS="${ROOT_PASS:-}"

if [[ -z "$USER_PASS" || -z "$ROOT_PASS" ]]; then
    log_err "Variáveis de ambiente USER_PASS e ROOT_PASS não foram definidas."
    echo "Uso: TARGET_USER=\"usuario\" USER_PASS=\"senha\" ROOT_PASS=\"senha\" ./install.sh"
    exit 1
fi

if ! mountpoint -q /mnt; then
    log_err "O ponto de montagem /mnt não está ativo!"
    log_err "Monte a partição raiz em /mnt e a partição EFI em /mnt/boot antes de prosseguir."
    exit 1
fi

if [[ ! -d /mnt/boot ]]; then
    log_err "Diretório /mnt/boot não existe. Certifique-se de montar a partição EFI em /mnt/boot."
    exit 1
fi

log_info "Verificando conectividade com a internet..."
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    log_err "Sem acesso à internet. Conecte via cabo ou iwctl antes de prosseguir."
    exit 1
fi
log_success "Conexão confirmada."

# -----------------------------------------------------------------------------
# 2. Instalação do Sistema Base (Pacstrap)
# -----------------------------------------------------------------------------
log_info "Executando pacstrap com pacotes essenciais do sistema..."

BASE_PKGS=(
    base
    base-devel
    linux
    linux-firmware
    networkmanager
    git
    sudo
    nano
)

pacstrap -K /mnt "${BASE_PKGS[@]}"
log_success "Sistema base instalado com sucesso via pacstrap."

# -----------------------------------------------------------------------------
# 3. Geração do Fstab
# -----------------------------------------------------------------------------
log_info "Gerando tabela de sistemas de arquivos (/mnt/etc/fstab)..."
genfstab -U /mnt >> /mnt/etc/fstab
log_success "Fstab gerado:"
cat /mnt/etc/fstab

# -----------------------------------------------------------------------------
# 4. Cópia dos Scripts para o Ambiente Alvo
# -----------------------------------------------------------------------------
BOOTSTRAP_DIR="/mnt/root/arch-bootstrap"
log_info "Copiando scripts de provisionamento para ${BOOTSTRAP_DIR}..."

rm -rf "${BOOTSTRAP_DIR}"
mkdir -p "${BOOTSTRAP_DIR}"
cp -r "$(dirname "$0")"/scripts "${BOOTSTRAP_DIR}/"
chmod +x "${BOOTSTRAP_DIR}"/scripts/*.sh

# -----------------------------------------------------------------------------
# 5. Execução Sequencial dos Módulos dentro do Chroot
# -----------------------------------------------------------------------------
log_info "Iniciando provisionamento modular dentro do chroot..."

SCRIPTS=(
    "01-base-chroot.sh"
    "02-hardware.sh"
    "03-virtualization.sh"
    "04-cli-tools.sh"
    "05-packages.sh"
    "06-android-dev.sh"
    "07-terminal-fish.sh"
    "08-dotfiles.sh"
    "09-dev-services.sh"
    "10-btrfs-snapper.sh"
)

for script in "${SCRIPTS[@]}"; do
    SCRIPT_PATH="/root/arch-bootstrap/scripts/${script}"
    log_info "========================================================"
    log_info "Executando módulo: ${script}"
    log_info "========================================================"
    
    arch-chroot /mnt /usr/bin/env \
        TARGET_USER="${TARGET_USER}" \
        USER_PASS="${USER_PASS}" \
        ROOT_PASS="${ROOT_PASS}" \
        bash "${SCRIPT_PATH}"
done

# -----------------------------------------------------------------------------
# 6. Finalização e Limpeza
# -----------------------------------------------------------------------------
log_info "Limpando diretórios temporários do chroot..."
rm -rf "${BOOTSTRAP_DIR}"

log_success "========================================================"
log_success "Instalação do Arch Linux (CLI-First) concluída com sucesso!"
log_success "Você pode agora desmontar as unidades e reiniciar o sistema:"
log_success "  umount -R /mnt"
log_success "  reboot"
log_success "========================================================"
