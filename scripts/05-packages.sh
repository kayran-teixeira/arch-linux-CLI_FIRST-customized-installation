#!/usr/bin/env bash
#
# scripts/05-packages.sh - Instalação de Aplicações Desktop, Ferramentas e AUR
# Responsabilidades:
# 1. Instalar Dolphin e dependências completas para operação estável em Wayland
# 2. Instalar suite de discos e particionamento (GParted + drivers de filesystem)
# 3. Instalar ferramentas de compressão e manipulação de arquivos (ouch, p7zip, etc.)
# 4. Instalar Steam (com dependências 32-bit e fontes) e OBS Studio
# 5. Instalar SDKs Java e configurar versão padrão via archlinux-java
# 6. Gerenciar elevação temporária do yay e instalar VS Code, JetBrains e ATLauncher
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[05-PKGS]${NC} $1"; }
log_success() { echo -e "${GREEN}[05-PKGS:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[05-PKGS:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[05-PKGS:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"

# -----------------------------------------------------------------------------
# 1. Pacotes Oficiais via Pacman (Executados Diretamente como Root)
# -----------------------------------------------------------------------------
log_info "Instalando ecossistema Dolphin para Wayland..."
DOLPHIN_PACKAGES=(
    dolphin                 # Gerenciador de arquivos
    ark                     # Backend para menus de compressão/extração no Dolphin
    breeze                  # Tema Breeze para coerência visual Qt
    breeze-icons            # Mandatório para evitar ícones em branco fora do KDE
    kio-extras              # Protocolos de rede, MTP (celular) e miniaturas
    kio-admin               # Ações administrativas seguras via Polkit
    ffmpegthumbs            # Miniaturas de vídeo
    kdegraphics-thumbnailers# Miniaturas de imagens vetoriais, PDF e RAW
    qt6-wayland             # Suporte nativo Wayland para aplicações Qt6
    qt5-wayland             # Suporte nativo Wayland para legados Qt5
)
pacman -S --noconfirm --needed "${DOLPHIN_PACKAGES[@]}"

log_info "Instalando utilitários de particionamento e sistemas de arquivos..."
DISK_PACKAGES=(
    gparted                 # Interface visual de particionamento
    e2fsprogs               # Suporte a ext2/ext3/ext4
    dosfstools              # Suporte a FAT16/FAT32
    ntfs-3g                 # Suporte a leitura/escrita em partições Windows NTFS
    exfatprogs              # Suporte a cartões SD e pendrives exFAT modernos
    mtools                  # Manipulação de arquivos MS-DOS
    parted                  # Manipulador de tabelas de partição de baixo nível
)
pacman -S --noconfirm --needed "${DISK_PACKAGES[@]}"

log_info "Instalando ferramentas de compressão e extração..."
COMPRESSION_PACKAGES=(
    tar
    p7zip
    unrar
    unzip
    zip
    zstd
    gzip
    bzip2
    xz
    ouch                    # Utilitário CLI moderno com sintaxe universal
)
pacman -S --noconfirm --needed "${COMPRESSION_PACKAGES[@]}"

log_info "Instalando Steam, OBS Studio e dependências de renderização..."
GAMING_MEDIA_PACKAGES=(
    steam                   # Cliente Steam (utiliza multilib e 32-bit drivers)
    obs-studio              # Gravação e streaming com suporte a PipeWire Wayland
    vlc                     # Player multimídia com codecs embutidos
    ttf-liberation          # Fonte mandatória para a interface da Steam não bugar
    wqy-zenhei              # Fontes CJK para evitar caixas em nomes de jogos/perfis
    lib32-fontconfig        # Suporte a fontes para o runtime 32-bit do Proton
)
pacman -S --noconfirm --needed "${GAMING_MEDIA_PACKAGES[@]}"

log_info "Instalando matriz de JDKs Java (8, 11, 17, 21)..."
JAVA_PACKAGES=(
    jdk8-openjdk
    jdk11-openjdk
    jdk17-openjdk           # Versão padrão da indústria e compatível com Android Gradle
    jdk21-openjdk           # Versão LTS moderna
    jdk-openjdk             # Versão mais recente
)
pacman -S --noconfirm --needed "${JAVA_PACKAGES[@]}"

# Define o Java 17 como versão primária do sistema
log_info "Configurando JDK 17 como versão padrão do sistema..."
archlinux-java set java-17-openjdk
log_success "Java padrão configurado: $(archlinux-java get)"

log_info "Instalando ferramentas de ambiente Python isolado (uv, pipx)..."
PYTHON_PACKAGES=(
    python
    python-pip
    python-pipx
    uv                      # Gerenciador ultrarrápido de pacotes e venvs em Rust
)
pacman -S --noconfirm --needed "${PYTHON_PACKAGES[@]}"

# -----------------------------------------------------------------------------
# 2. Concessão Temporária de Sudo NOPASSWD para Instalações AUR
# -----------------------------------------------------------------------------
TEMP_SUDO_FILE="/etc/sudoers.d/99-temp-packages-bootstrap"

log_info "Habilitando privilégio temporário para yay operar sem interrupção..."
cat <<EOF > "${TEMP_SUDO_FILE}"
${TARGET_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "${TEMP_SUDO_FILE}"

cleanup_pkg_sudo() {
    if [[ -f "${TEMP_SUDO_FILE}" ]]; then
        log_warn "Revogando privilégios NOPASSWD do usuário ${TARGET_USER}..."
        rm -f "${TEMP_SUDO_FILE}"
    fi
}
trap cleanup_pkg_sudo EXIT

# -----------------------------------------------------------------------------
# 3. Instalação de Aplicações via AUR (yay)
# -----------------------------------------------------------------------------
log_info "Instalando ferramentas de desenvolvimento e launchers via AUR..."

AUR_PACKAGES=(
    visual-studio-code-bin
    jetbrains-toolbox
    atlauncher-bin
    envycontrol
)

su - "${TARGET_USER}" -c "
    set -euo pipefail
    yay -S --noconfirm --needed ${AUR_PACKAGES[*]}
"

log_success "Pacotes AUR instalados com sucesso."

cleanup_pkg_sudo
trap - EXIT

log_success "Módulo 05-packages.sh finalizado com sucesso."
