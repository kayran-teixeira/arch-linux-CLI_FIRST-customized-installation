#!/usr/bin/env bash
#
# scripts/02-hardware.sh - Provisionamento de Hardware, GPU, Áudio e Firmware
# Responsabilidades:
# 1. Habilitar repositório [multilib] para compatibilidade de 32-bits (Steam/Wine)
# 2. Detectar e instalar microcode da CPU (Intel/AMD) com injeção no systemd-boot
# 3. Instalar drivers NVIDIA DKMS, configurar Early KMS e hook automático no pacman
# 4. Configurar pipeline de áudio de baixa latência PipeWire + WirePlumber
# 5. Compilar e habilitar o daemon awccd para controle térmico do Dell G15
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[02-HARDWARE]${NC} $1"; }
log_success() { echo -e "${GREEN}[02-HARDWARE:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[02-HARDWARE:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[02-HARDWARE:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"

# -----------------------------------------------------------------------------
# 1. Habilitação do Repositório [multilib]
# -----------------------------------------------------------------------------
log_info "Habilitando repositório [multilib] no /etc/pacman.conf..."

# Descomenta a seção [multilib] e seu respectivo Include
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

pacman -Sy --noconfirm
log_success "Repositório [multilib] sincronizado com sucesso."

# -----------------------------------------------------------------------------
# 2. Detecção e Configuração de CPU Microcode
# -----------------------------------------------------------------------------
log_info "Detectando arquitetura da CPU para injeção de microcode..."

CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
UCODE_PKG=""
UCODE_IMG=""

if [[ "${CPU_VENDOR}" == "GenuineIntel" ]]; then
    log_info "Processador Intel detectado."
    UCODE_PKG="intel-ucode"
    UCODE_IMG="/intel-ucode.img"
elif [[ "${CPU_VENDOR}" == "AuthenticAMD" ]]; then
    log_info "Processador AMD detectado."
    UCODE_PKG="amd-ucode"
    UCODE_IMG="/amd-ucode.img"
else
    log_warn "Fabricante de CPU desconhecido (${CPU_VENDOR}). Pulando microcode."
fi

if [[ -n "${UCODE_PKG}" ]]; then
    pacman -S --noconfirm --needed "${UCODE_PKG}"
    
    # Injeta a linha do microcode antes da initramfs no arquivo de boot do systemd-boot
    BOOT_ENTRY="/boot/loader/entries/arch.conf"
    if [[ -f "${BOOT_ENTRY}" ]] && ! grep -q "${UCODE_IMG}" "${BOOT_ENTRY}"; then
        sed -i "/linux \/vmlinuz-linux/a initrd  ${UCODE_IMG}" "${BOOT_ENTRY}"
        log_success "Microcode ${UCODE_PKG} configurado no systemd-boot."
    fi
fi

# -----------------------------------------------------------------------------
# 3. Stack NVIDIA DKMS (Open Source ou Proprietário) e Early KMS
# -----------------------------------------------------------------------------
# NVIDIA_MODULE_TYPE:
# "open" (Padrão recomendado para Turing e superiores: RTX 20xx, 30xx, 40xx, GTX 16xx)
# "proprietary" (Para arquiteturas legadas Maxwell GTX 9xx e Pascal GTX 10xx)
NVIDIA_MODULE_TYPE="${NVIDIA_MODULE_TYPE:-open}"

if [[ "${NVIDIA_MODULE_TYPE}" == "open" ]]; then
    log_info "Selecionado módulo Open-Source da NVIDIA (nvidia-open-dkms)..."
    NVIDIA_DKMS_PKG="nvidia-open-dkms"
else
    log_info "Selecionado módulo proprietário clássico da NVIDIA (nvidia-dkms)..."
    NVIDIA_DKMS_PKG="nvidia-dkms"
fi

log_info "Instalando stack gráfica NVIDIA e suporte a PRIME Render Offload..."

NVIDIA_PACKAGES=(
    "${NVIDIA_DKMS_PKG}"
    nvidia-utils
    lib32-nvidia-utils
    nvidia-settings
    opencl-nvidia
    lib32-opencl-nvidia
    nvidia-prime            # Suporte a prime-run para offloading gráfico sob demanda
    libva-nvidia-driver     # Aceleração VA-API em navegadores e players de vídeo
    nvtop                   # Monitor TUI de GPU
)

pacman -S --noconfirm --needed "${NVIDIA_PACKAGES[@]}"

log_info "Configurando Early KMS no /etc/mkinitcpio.conf..."
# Adiciona os módulos da NVIDIA para carregamento imediato no initramfs
sed -i 's/^MODULES=([^)]*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

# Remove o hook kms genérico (evita conflitos com os módulos binários da NVIDIA)
sed -i 's/\bkms\b//g' /etc/mkinitcpio.conf
# Remove múltiplos espaços caso o kms tenha deixado resíduos
sed -i 's/  */ /g' /etc/mkinitcpio.conf

log_info "Criando hook do pacman para recompilar initramfs em upgrades da NVIDIA..."
mkdir -p /etc/pacman.d/hooks
cat <<'EOF' > /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-dkms
Target=nvidia-open-dkms
Target=linux

[Action]
Description=Atualizando initramfs apos mudanca nos modulos NVIDIA...
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
EOF

log_info "Regenerando initramfs para aplicar módulos de GPU..."
mkinitcpio -P

log_info "Injetando parâmetros de modo de vídeo do Wayland no bootloader..."
BOOT_ENTRY="/boot/loader/entries/arch.conf"
if [[ -f "${BOOT_ENTRY}" ]]; then
    # Garante que os parâmetros de DRM e framebuffer passem para o kernel no boot
    if ! grep -q "nvidia_drm.modeset=1" "${BOOT_ENTRY}"; then
        sed -i '/^options / s/$/ nvidia_drm.modeset=1 nvidia_drm.fbdev=1/' "${BOOT_ENTRY}"
        log_success "Flags nvidia_drm.modeset=1 e fbdev=1 adicionadas ao loader."
    fi
fi

# -----------------------------------------------------------------------------
# 4. Pipeline de Áudio com PipeWire e WirePlumber
# -----------------------------------------------------------------------------
log_info "Instalando stack de áudio PipeWire..."

AUDIO_PACKAGES=(
    pipewire
    pipewire-audio
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    wireplumber
    lib32-pipewire
    lib32-pipewire-jack
)

# Remove pulseaudio se presente para evitar conflitos de portas
pacman -Rdd --noconfirm pulseaudio pulseaudio-bluetooth 2>/dev/null || true
pacman -S --noconfirm --needed "${AUDIO_PACKAGES[@]}"

log_success "PipeWire e WirePlumber instalados (iniciam como daemons do usuário)."

# -----------------------------------------------------------------------------
# 5. Controle de Hardware Dell G15: Alienware Command Center (`awccd`)
# -----------------------------------------------------------------------------
log_info "Preparando ambiente para compilação do awccd para Dell G15..."

pacman -S --noconfirm --needed cmake libusb git

# Concede elevação temporária para o makepkg instalar dependências via pacman
TEMP_SUDO_FILE="/etc/sudoers.d/99-temp-awccd-bootstrap"
cat <<EOF > "${TEMP_SUDO_FILE}"
${TARGET_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "${TEMP_SUDO_FILE}"

cleanup_awccd_sudo() {
    if [[ -f "${TEMP_SUDO_FILE}" ]]; then
        rm -f "${TEMP_SUDO_FILE}"
    fi
}
trap cleanup_awccd_sudo EXIT

AWCCD_BUILD_DIR="/tmp/awccd-build"
rm -rf "${AWCCD_BUILD_DIR}"
mkdir -p "${AWCCD_BUILD_DIR}"
chown -R "${TARGET_USER}:users" "${AWCCD_BUILD_DIR}"

log_info "Compilando awccd-git a partir do AUR como usuário ${TARGET_USER}..."
su - "${TARGET_USER}" -c "
    git clone https://aur.archlinux.org/awccd-git.git ${AWCCD_BUILD_DIR}/awccd
    cd ${AWCCD_BUILD_DIR}/awccd
    makepkg -si --noconfirm
"

rm -rf "${AWCCD_BUILD_DIR}"
cleanup_awccd_sudo
trap - EXIT

# Garante que o módulo de interface de controle da placa-mãe seja carregado
echo "dell-wmi" > /etc/modules-load.d/dell-wmi.conf

log_info "Habilitando serviço do awccd no systemd..."
systemctl enable awccd.service

log_success "awccd configurado e habilitado para gerenciar ventoinhas e modos de energia do Dell G15."
log_success "Módulo 02-hardware.sh finalizado com sucesso."