#!/usr/bin/env bash
#
# scripts/10-btrfs-snapper.sh - Configuração de Snapshots Btrfs, Snapper e Snap-Pac
# Responsabilidades:
# 1. Verificar se o sistema de arquivos da raiz é Btrfs
# 2. Instalar Snapper, snap-pac e utilitários de snapshot
# 3. Gerar perfil do Snapper para a raiz (/) e para o /home
# 4. Ajustar limites de retenção de snapshots (timeline e contagem)
# 5. Ativar timers do systemd para criação periódica e higienização automática
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[10-BTRFS]${NC} $1"; }
log_success() { echo -e "${GREEN}[10-BTRFS:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[10-BTRFS:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[10-BTRFS:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"

# -----------------------------------------------------------------------------
# 1. Detecção do Sistema de Arquivos Raiz
# -----------------------------------------------------------------------------
log_info "Detectando tipo de sistema de arquivos da raiz (/)..."

ROOT_FSTYPE=$(findmnt -no FSTYPE / || true)

if [[ "${ROOT_FSTYPE}" != "btrfs" ]]; then
    log_warn "O sistema de arquivos raiz é '${ROOT_FSTYPE}' (não é Btrfs)."
    log_warn "Pulando provisionamento do Snapper. Módulo concluído."
    exit 0
fi

log_success "Sistema de arquivos Btrfs detectado na raiz."

# -----------------------------------------------------------------------------
# 2. Instalação do Snapper e Ferramentas Auxiliares
# -----------------------------------------------------------------------------
log_info "Instalando Snapper, snap-pac e ferramentas de manutenção Btrfs..."

SNAPPER_PACKAGES=(
    snapper             # Gerenciador de snapshots
    snap-pac            # Hook do pacman para tirar snapshots automáticos pré/pós upgrade
    btrfs-progs         # Utilitários de baixo nível do Btrfs
)

pacman -S --noconfirm --needed "${SNAPPER_PACKAGES[@]}"
log_success "Pacotes do Snapper instalados com sucesso."

# -----------------------------------------------------------------------------
# 3. Configuração do Snapper para o Subvolume Raiz (/)
# -----------------------------------------------------------------------------
log_info "Configurando perfil do Snapper para o subvolume raiz..."

# Se já houver um diretório /.snapshots criado como pasta comum, desfaz para o snapper recriar
if [[ ! -d "/etc/snapper/configs/root" ]]; then
    if [[ -d "/.snapshots" ]] && ! mountpoint -q "/.snapshots"; then
        rmdir "/.snapshots" 2>/dev/null || true
    fi

    # Cria a configuração do snapper para a raiz
    snapper -c root create-config / || true
fi

# Ajusta permissões para que o grupo wheel ou usuário possa consultar
if [[ -f "/etc/snapper/configs/root" ]]; then
    sed -i 's/^ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' /etc/snapper/configs/root
    sed -i "s/^ALLOW_USERS=\"\"/ALLOW_USERS=\"${TARGET_USER}\"/" /etc/snapper/configs/root

    # Limites de retenção para evitar esgotamento de disco
    sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root
    sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="15"/' /etc/snapper/configs/root
    sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/root
    log_success "Políticas de retenção do perfil root configuradas."
fi

# -----------------------------------------------------------------------------
# 4. Configuração do Snapper para /home (se for subvolume Btrfs)
# -----------------------------------------------------------------------------
HOME_FSTYPE=$(findmnt -no FSTYPE /home || true)
if [[ "${HOME_FSTYPE}" == "btrfs" && ! -f "/etc/snapper/configs/home" ]]; then
    log_info "Subvolume Btrfs dedicado detectado em /home. Criando perfil..."
    snapper -c home create-config /home || true
    if [[ -f "/etc/snapper/configs/home" ]]; then
        sed -i 's/^ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' /etc/snapper/configs/home
        sed -i "s/^ALLOW_USERS=\"\"/ALLOW_USERS=\"${TARGET_USER}\"/" /etc/snapper/configs/home
        sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="3"/' /etc/snapper/configs/home
        sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="5"/' /etc/snapper/configs/home
        sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/' /etc/snapper/configs/home
        sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/home
        log_success "Perfil do Snapper para /home configurado."
    fi
fi

# Garante permissões restritas em /.snapshots
chmod 750 /.snapshots 2>/dev/null || true

# -----------------------------------------------------------------------------
# 5. Habilitação de Timers de Automação e Limpeza
# -----------------------------------------------------------------------------
log_info "Habilitando timers do Snapper para snapshots periódicos e higienização..."

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# Se o grub-btrfs estiver instalado e o GRUB for o bootloader, habilita o daemon
if command -v grub-btrfsd &>/dev/null; then
    systemctl enable grub-btrfsd.service || true
    log_success "Daemon grub-btrfsd habilitado para sincronizar snapshots no boot."
fi

log_success "Módulo 10-btrfs-snapper.sh finalizado com sucesso."
