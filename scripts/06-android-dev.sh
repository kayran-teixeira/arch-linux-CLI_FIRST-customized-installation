#!/usr/bin/env bash
#
# scripts/06-android-dev.sh - Ferramentas de Desenvolvimento Android e Conectividade Mobile
# Responsabilidades:
# 1. Instalar ferramentas de comunicação USB/Rede (android-tools, scrcpy, gvfs-mtp)
# 2. Instalar regras de hardware (android-udev) e associar usuário ao grupo adbusers
# 3. Ajustar limites de monitoramento do kernel (fs.inotify) para o Gradle e Android Studio
# 4. Configurar variáveis globais de ambiente (ANDROID_HOME, caminhos de SDK no PATH)
# 5. Instalar o Android Studio via AUR com privilégios gerenciados de compilação
# 6. Validar aceleração de virtualização para o Android Emulator (KVM)
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[06-ANDROID]${NC} $1"; }
log_success() { echo -e "${GREEN}[06-ANDROID:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[06-ANDROID:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[06-ANDROID:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"

# -----------------------------------------------------------------------------
# 1. Instalação de Pacotes Oficiais (ADB, Fastboot, Udev, Scrcpy, MTP)
# -----------------------------------------------------------------------------
log_info "Instalando utilitários oficiais para Android e montagem de dispositivos..."

ANDROID_OFFICIAL_PKGS=(
    android-tools           # ADB (Android Debug Bridge) e Fastboot
    android-udev            # Regras do udev para centenas de IDs de fabricantes USB
    scrcpy                  # Espelhamento e controle de tela via USB/TCP com baixa latência
    gvfs-mtp                # Integração com Dolphin para navegar na memória interna do celular
    libmtp                  # Biblioteca de baixo nível para protocolo MTP
    usbutils                # lsusb para diagnóstico de hardware conectado
)

pacman -S --noconfirm --needed "${ANDROID_OFFICIAL_PKGS[@]}"
log_success "Pacotes oficiais de comunicação Android instalados."

# -----------------------------------------------------------------------------
# 2. Permissões de Usuário e Grupos de Hardware
# -----------------------------------------------------------------------------
log_info "Configurando permissões do usuário ${TARGET_USER} para ADB e emulação..."

# Garante a existência do grupo adbusers gerado pelo pacote android-udev
groupadd -f adbusers

# adbusers: comunicação USB sem sudo
# kvm: aceleração por hardware do Android Emulator
usermod -aG adbusers,kvm "${TARGET_USER}"
log_success "Usuário associado aos grupos 'adbusers' e 'kvm'."

# -----------------------------------------------------------------------------
# 3. Kernel Inotify Tuning (Prevenção de Falhas no Gradle/Android Studio)
# -----------------------------------------------------------------------------
log_info "Aumentando limites do inotify para indexação de projetos e Gradle..."

# O Android Studio e o daemon do Gradle mantêm dezenas de milhares de descritores
# de arquivos abertos para monitorar alterações de código. O padrão de 8192 do Linux
# causa falhas de compilação como 'No space left on device' mesmo com o disco vazio.
cat <<'EOF' > /etc/sysctl.d/99-android-inotify.conf
# Limites estendidos de observadores de arquivos para IDEs e build tools
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024
EOF

log_success "Arquivo /etc/sysctl.d/99-android-inotify.conf criado."

# -----------------------------------------------------------------------------
# 4. Variáveis Globais de Ambiente para o Android SDK
# -----------------------------------------------------------------------------
log_info "Configurando variáveis de ambiente em /etc/profile.d/android.sh..."

cat <<'EOF' > /etc/profile.d/android.sh
# Android SDK Paths
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_USER_HOME="$HOME/.android"

# Injeta ferramentas do SDK no PATH caso existam
if [ -d "$ANDROID_HOME/platform-tools" ]; then
    export PATH="$PATH:$ANDROID_HOME/platform-tools"
fi
if [ -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]; then
    export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
fi
if [ -d "$ANDROID_HOME/emulator" ]; then
    export PATH="$PATH:$ANDROID_HOME/emulator"
fi
EOF
chmod +x /etc/profile.d/android.sh
log_success "Definições de ANDROID_HOME gravadas no profile do sistema."

# -----------------------------------------------------------------------------
# 5. Instalação do Android Studio via AUR (yay)
# -----------------------------------------------------------------------------
TEMP_SUDO_FILE="/etc/sudoers.d/99-temp-android-bootstrap"

log_info "Concedendo privilégio temporário para compilação do Android Studio..."
cat <<EOF > "${TEMP_SUDO_FILE}"
${TARGET_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "${TEMP_SUDO_FILE}"

cleanup_android_sudo() {
    if [[ -f "${TEMP_SUDO_FILE}" ]]; then
        log_warn "Revogando privilégios NOPASSWD do usuário ${TARGET_USER}..."
        rm -f "${TEMP_SUDO_FILE}"
    fi
}
trap cleanup_android_sudo EXIT

log_info "Instalando android-studio a partir do AUR como ${TARGET_USER}..."
su - "${TARGET_USER}" -c "
    set -euo pipefail
    yay -S --noconfirm --needed android-studio
"

log_success "Android Studio instalado com sucesso."

# Revoga a regra temporária de sudo imediatamente
cleanup_android_sudo
trap - EXIT

# -----------------------------------------------------------------------------
# 6. Criação da Estrutura de Diretórios Inicial no Home do Usuário
# -----------------------------------------------------------------------------
USER_HOME="/home/${TARGET_USER}"
log_info "Criando diretório base do Android SDK em ${USER_HOME}/Android/Sdk..."

mkdir -p "${USER_HOME}/Android/Sdk"
mkdir -p "${USER_HOME}/.android"
chown -R "${TARGET_USER}:users" "${USER_HOME}/Android" "${USER_HOME}/.android"

log_success "Módulo 06-android-dev.sh finalizado com êxito."