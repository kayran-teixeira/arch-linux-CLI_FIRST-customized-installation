#!/usr/bin/env bash
#
# scripts/01-base-chroot.sh - Configuração Base do Sistema dentro do chroot
# Responsabilidades:
# 1. Configurar Timezone, Locales, Teclado de TTY e Hostname
# 2. Aplicar tuning de I/O no Kernel (eliminar falso 100% em USBs/discos)
# 3. Criar usuário padrão, definir senhas e configurar sudoers
# 4. Habilitar serviços nucleares de rede e tempo
# 5. Instalar e configurar bootloader systemd-boot de forma determinística
#

set -euo pipefail

# Cores para feedback visual
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[01-BASE]${NC} $1"; }
log_success() { echo -e "${GREEN}[01-BASE:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[01-BASE:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[01-BASE:ERRO]${NC} $1" >&2; }

# -----------------------------------------------------------------------------
# 1. Validação de Variáveis de Ambiente
# -----------------------------------------------------------------------------
TARGET_USER="${TARGET_USER:-kayran}"
USER_PASS="${USER_PASS:-}"
ROOT_PASS="${ROOT_PASS:-}"

if [[ -z "$USER_PASS" || -z "$ROOT_PASS" ]]; then
    log_err "Variáveis de credenciais (USER_PASS e ROOT_PASS) estão vazias."
    exit 1
fi

log_info "Iniciando configuração base para o usuário: ${TARGET_USER}..."

# -----------------------------------------------------------------------------
# 2. Localização, Fuso Horário e Console TTY
# -----------------------------------------------------------------------------
log_info "Configurando timezone (America/Sao_Paulo) e relógio do hardware..."
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

log_info "Gerando locales (en_US.UTF-8 e pt_BR.UTF-8)..."
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(pt_BR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen >/dev/null

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LC_TIME=pt_BR.UTF-8" >> /etc/locale.conf

# Garante que o layout ABNT2 funcione direto no terminal puro (TTY)
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf

log_info "Configurando Hostname e resolução local..."
echo "arch-box" > /etc/hostname

cat <<EOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch-box.localdomain arch-box
EOF
log_success "Localização e rede local configuradas."

# -----------------------------------------------------------------------------
# 3. Kernel I/O Tuning (Correção Definitiva do Congelamento de Buffer)
# -----------------------------------------------------------------------------
log_info "Aplicando tuning no sysctl para buffer de I/O e sincronismo de disco..."

cat <<'EOF' > /etc/sysctl.d/99-io-performance.conf
# ==============================================================================
# Otimização de I/O de Armazenamento e Gerenciamento de Memória
# ==============================================================================

# Inicia a gravação em disco em segundo plano assim que houver 16 MB pendentes
vm.dirty_background_bytes = 16777216

# Suspende a aplicação de escrita se mais de 48 MB acumularem na memória RAM.
# Força o progresso da cópia a respeitar a velocidade real da controladora USB/SATA
vm.dirty_bytes = 50331648

# Reduz o tempo máximo de permanência de páginas sujas no cache antes do flush forçado
vm.dirty_expire_centisecs = 1500
vm.dirty_writeback_centisecs = 500

# Evita o uso agressivo de swap se houver memória RAM livre suficiente
vm.swappiness = 10

# Proteção contra ataques em links simbólicos e hardlinks
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

log_success "Arquivo /etc/sysctl.d/99-io-performance.conf gerado com sucesso."

# -----------------------------------------------------------------------------
# 4. Criação de Usuário, Shell Fish e Privilégios Sudo
# -----------------------------------------------------------------------------
log_info "Garantindo dependência do shell Fish para o usuário..."
pacman -S --noconfirm --needed fish >/dev/null

if id -u "${TARGET_USER}" &>/dev/null; then
    log_warn "Usuário ${TARGET_USER} já existe. Atualizando grupos e shell..."
    usermod -aG wheel,video,audio,storage,input -s /usr/bin/fish "${TARGET_USER}"
else
    log_info "Criando usuário ${TARGET_USER} com shell /usr/bin/fish..."
    useradd -m -g users -G wheel,video,audio,storage,input -s /usr/bin/fish "${TARGET_USER}"
fi

# Define as senhas criptografadas
echo "root:${ROOT_PASS}" | chpasswd
echo "${TARGET_USER}:${USER_PASS}" | chpasswd
log_success "Senhas de root e ${TARGET_USER} aplicadas."

# Configura sudoers com arquivo isolado e permissões restritas (0440)
log_info "Configurando permissões do sudo para o grupo wheel..."
cat <<EOF > /etc/sudoers.d/10-installer
%wheel ALL=(ALL:ALL) ALL
Defaults timestamp_timeout=30
EOF
chmod 0440 /etc/sudoers.d/10-installer
log_success "Permissões de sudo aplicadas com segurança."

# -----------------------------------------------------------------------------
# 5. Configuração de ZRAM e Daemons de Sistema (Rede, Tempo e Firewall)
# -----------------------------------------------------------------------------
log_info "Configurando ZRAM com algoritmo zstd (swap comprimido em RAM)..."
pacman -S --noconfirm --needed zram-generator firewalld btrfs-progs >/dev/null

cat <<'EOF' > /etc/systemd/zram-generator.conf
[zram0]
compression-algorithm = zstd
EOF
log_success "Arquivo /etc/systemd/zram-generator.conf gerado."

log_info "Habilitando serviços essenciais de rede, firewall e sincronização de horário..."
systemctl enable NetworkManager.service
systemctl enable firewalld.service
systemctl enable systemd-timesyncd.service
log_success "Serviços NetworkManager, firewalld e systemd-timesyncd habilitados."

# -----------------------------------------------------------------------------
# 6. Instalação e Configuração do Bootloader (systemd-boot)
# -----------------------------------------------------------------------------
log_info "Instalando systemd-boot na partição EFI (/boot)..."
bootctl install --path=/boot

# Extrai o UUID real da partição montada na raiz (/)
ROOT_UUID=$(findmnt -no UUID /)
if [[ -z "${ROOT_UUID}" ]]; then
    # Fallback caso findmnt não retorne diretamente o UUID
    ROOT_SOURCE=$(findmnt -no SOURCE /)
    ROOT_UUID=$(blkid -s UUID -o value "${ROOT_SOURCE}")
fi

if [[ -z "${ROOT_UUID}" ]]; then
    log_err "Não foi possível obter o UUID da partição raiz para o bootloader."
    exit 1
fi

log_info "UUID da partição raiz identificado: ${ROOT_UUID}"

# Configuração global do menu do loader
cat <<'EOF' > /boot/loader/loader.conf
default  arch.conf
timeout  3
console-mode max
editor   no
EOF

# Entrada padrão do kernel Linux
cat <<EOF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw quiet
EOF

log_success "Entrada do bootloader /boot/loader/entries/arch.conf criada."
log_success "Módulo 01-base-chroot.sh finalizado sem erros."