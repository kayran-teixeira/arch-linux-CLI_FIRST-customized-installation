#!/usr/bin/env bash
#
# scripts/07-terminal-fish.sh - Configuração do Ambiente de Terminal, Shell e Cheatsheets
# Responsabilidades:
# 1. Instalar Kitty, Fish, Fastfetch, Tealdeer (tldr) e fontes JetBrains Mono
# 2. Configurar Kitty com aceleração por GPU, baixa latência e sem decorações
# 3. Configurar Fish shell (desativar greeting, configurar aliases, PATH e autocompletions)
# 4. Configurar Fastfetch para execução automática limpa em novas sessões
# 5. Configurar Tealdeer com realce colorido e páginas personalizadas de administração CLI
# 6. Atualizar a base de autocompletamento do Fish a partir das manpages do sistema
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[07-TERM]${NC} $1"; }
log_success() { echo -e "${GREEN}[07-TERM:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[07-TERM:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[07-TERM:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"
USER_HOME="/home/${TARGET_USER}"

# -----------------------------------------------------------------------------
# 1. Instalação de Pacotes do Terminal, Shell e Fontes
# -----------------------------------------------------------------------------
log_info "Instalando Kitty, Fish, Fastfetch, Tealdeer e fontes tipográficas..."

TERM_PACKAGES=(
    kitty                      # Emulador de terminal acelerado via OpenGL
    fish                       # Shell interativo com syntax highlighting e autosugestões
    fastfetch                  # Telemetria rápida do sistema em C
    tealdeer                   # Implementação em Rust de alta performance do tldr
    ttf-jetbrains-mono-nerd    # Fonte com glifos e símbolos para IDEs e terminal
    noto-fonts-emoji           # Suporte a emojis no terminal
)

pacman -S --noconfirm --needed "${TERM_PACKAGES[@]}"
log_success "Pacotes de terminal e fontes instalados com êxito."

# -----------------------------------------------------------------------------
# 2. Configuração do Emulador de Terminal Kitty
# -----------------------------------------------------------------------------
log_info "Configurando ${USER_HOME}/.config/kitty/kitty.conf..."

KITTY_CONF_DIR="${USER_HOME}/.config/kitty"
mkdir -p "${KITTY_CONF_DIR}"

cat <<'EOF' > "${KITTY_CONF_DIR}/kitty.conf"
# ==============================================================================
# Configuração Mínima e de Baixa Latência para o Kitty
# ==============================================================================

# Tipografia
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        11.0

# Otimização de Pipeline de Renderização e Latência de I/O
sync_to_monitor         yes
repaint_delay           8
input_delay             2
enable_audio_bell       no

# Aparência e Layout Monocle (Sem Decorações Gráficas)
window_padding_width    6
hide_window_decorations yes
confirm_os_window_close 0
cursor_shape            block
cursor_blink_interval   0

# Shell Padrão
shell /usr/bin/fish

# Esquema de Cores Escuro e Neutro
background #0f1117
foreground #cdd6f4
selection_background #313244
selection_foreground #cdd6f4

# Cores Normais / Brilhantes (ANSI)
color0  #45475a
color8  #585b70
color1  #f38ba8
color9  #f38ba8
color2  #a6e3a1
color10 #a6e3a1
color3  #f9e2af
color11 #f9e2af
color4  #89b4fa
color12 #89b4fa
color5  #f5c2e7
color13 #f5c2e7
color6  #94e2d5
color14 #94e2d5
color7  #bac2de
color15 #a6adc8
EOF

log_success "Arquivo kitty.conf configurado."

# -----------------------------------------------------------------------------
# 3. Configuração do Shell Fish
# -----------------------------------------------------------------------------
log_info "Configurando ${USER_HOME}/.config/fish/config.fish..."

FISH_CONF_DIR="${USER_HOME}/.config/fish"
mkdir -p "${FISH_CONF_DIR}"

cat <<'EOF' > "${FISH_CONF_DIR}/config.fish"
# Desativa a mensagem padrão de boas-vindas do Fish
set -g fish_greeting

# Garante variáveis de ambiente no PATH do Fish
fish_add_path -g $HOME/.local/bin
fish_add_path -g $HOME/Android/Sdk/platform-tools
fish_add_path -g $HOME/Android/Sdk/cmdline-tools/latest/bin
fish_add_path -g $HOME/Android/Sdk/emulator

# Executa o Fastfetch estritamente em sessões interativas de terminal
if status is-interactive
    fastfetch
end

# -----------------------------------------------------------------------------
# Aliases e Abreviações Operacionais
# -----------------------------------------------------------------------------
# Listagem moderna com cores
alias ls="ls --color=auto"
alias ll="ls -lh --color=auto"
alias la="ls -lah --color=auto"

# Utilitários de arquivo e cheatsheets
alias cat="ouch decompress"
alias t="tldr"

# Ejeção segura de discos garantindo esvaziamento do buffer de I/O
alias safedrive="sync && udisksctl unmount -b"

# SSH transparente mantendo suporte a terminfo do Kitty em servidores remotos
if test "$TERM" = "xterm-kitty"
    alias ssh="kitten ssh"
end

# -----------------------------------------------------------------------------
# Configurações de Cores do Syntax Highlighting do Fish
# -----------------------------------------------------------------------------
set -g fish_color_normal cdd6f4
set -g fish_color_command 89b4fa --bold
set -g fish_color_quote f9e2af
set -g fish_color_redirection f5c2e7
set -g fish_color_end f38ba8
set -g fish_color_error f38ba8 --bold
set -g fish_color_param cdd6f4
set -g fish_color_comment 585b70
set -g fish_color_selection --background=313244
set -g fish_color_search_match --background=313244
set -g fish_color_operator 94e2d5
set -g fish_color_escape f5c2e7
set -g fish_color_autosuggestion 585b70
EOF

log_success "Arquivo config.fish configurado."

# -----------------------------------------------------------------------------
# 4. Configuração do Fastfetch (Perfil Limpo e Compacto)
# -----------------------------------------------------------------------------
log_info "Configurando preset compacto do Fastfetch..."

FASTFETCH_CONF_DIR="${USER_HOME}/.config/fastfetch"
mkdir -p "${FASTFETCH_CONF_DIR}"

cat <<'EOF' > "${FASTFETCH_CONF_DIR}/config.jsonc"
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "small",
    "padding": {
      "top": 1,
      "left": 2,
      "right": 3
    }
  },
  "display": {
    "separator": " 󰄾 "
  },
  "modules": [
    "title",
    "separator",
    "os",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "display",
    "cpu",
    "gpu",
    "memory",
    "disk",
    "break",
    "colors"
  ]
}
EOF

log_success "Configuração do Fastfetch gerada."

# -----------------------------------------------------------------------------
# 5. Tealdeer: Cheatsheets Coloridas e Páginas Customizadas de Administração
# -----------------------------------------------------------------------------
log_info "Configurando Tealdeer e gerando páginas de manual rápido do sistema..."

TEALDEER_CONF_DIR="${USER_HOME}/.config/tealdeer"
TEALDEER_PAGES_DIR="${USER_HOME}/.local/share/tealdeer/pages/custom"

mkdir -p "${TEALDEER_CONF_DIR}"
mkdir -p "${TEALDEER_PAGES_DIR}"

# Configuração do Tealdeer com paginação desativada e suporte a páginas locais
cat <<EOF > "${TEALDEER_CONF_DIR}/config.toml"
[display]
compact = false
use_pager = false

[updates]
auto_update = true

[directories]
custom_pages_dir = "${TEALDEER_PAGES_DIR}"
EOF

# Página 1: Gestão de Áudio (PipeWire / WirePlumber)
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-audio.page"
# arch-audio

> Guia rápido de controle do PipeWire e WirePlumber via CLI.

- Listar todos os dispositivos de reprodução, captura e seus IDs numéricos:
  `wpctl status`

- Definir uma saída de áudio específica como padrão:
  `wpctl set-default <ID>`

- Aumentar o volume da saída padrão em 5%:
  `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+`

- Diminuir o volume da saída padrão em 5%:
  `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-`

- Alternar o mudo (mute/unmute) da saída de áudio padrão:
  `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle`

- Alternar o mudo do microfone padrão:
  `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`
EOF

# Página 2: Hardware Dell G15 e GPU NVIDIA
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-gpu.page"
# arch-gpu

> Controle térmico do Dell G15 (awccd) e telemetria da GPU dedicada NVIDIA.

- Listar perfis térmicos suportados pela controladora WMI do Dell G15:
  `awcc-cli --list-profiles`

- Ativar o perfil de máximo resfriamento e desempenho (G-Mode):
  `awcc-cli --set-profile Performance`

- Retornar o sistema para o perfil térmico balanceado padrão:
  `awcc-cli --set-profile Balanced`

- Monitorar uso de VRAM, frequência e processos na GPU com interface TUI:
  `nvtop`

- Exibir snapshot detalhado de drivers e processos da NVIDIA:
  `nvidia-smi`
EOF

# Página 3: Virtualização KVM / QEMU
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-vm.page"
# arch-vm

> Gerenciamento de hipervisor KVM/QEMU via linha de comando sem GUI.

- Listar todas as máquinas virtuais registradas e seus status:
  `virsh list --all`

- Iniciar a execução de uma máquina virtual:
  `virsh start <nome_da_vm>`

- Desligar uma máquina virtual de forma limpa (ACPI shutdown):
  `virsh shutdown <nome_da_vm>`

- Forçar parada imediata de uma máquina virtual travada:
  `virsh destroy <nome_da_vm>`

- Listar redes virtuais do libvirt e verificar se a rede 'default' (virbr0) está ativa:
  `virsh net-list --all`

- Criar um disco virtual dinâmico no formato qcow2:
  `qemu-img create -f qcow2 /caminho/disco.qcow2 30G`
EOF

# Página 4: Armazenamento e Ejeção Segura
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-disks.page"
# arch-disks

> Gerenciamento de blocos de disco, montagem sem root e ejeção segura sem congelamento de cache.

- Inspecionar UUIDs, rótulos e pontos de montagem de todas as partições:
  `lsblk -f`

- Montar uma partição externa em espaço de usuário sem privilégios de root:
  `udisksctl mount -b /dev/sdX1`

- Desmontar e sincronizar o buffer de I/O antes da remoção física:
  `sync && udisksctl unmount -b /dev/sdX1`

- Desligar a energia da controladora USB do pendrive para remoção 100% segura:
  `udisksctl power-off -b /dev/sdX`
EOF

# Página 5: Desenvolvimento Mobile e Android
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-android.page"
# arch-android

> Utilitários de comunicação USB, depuração e espelhamento de celulares Android.

- Listar aparelhos conectados com depuração USB autorizada:
  `adb devices`

- Abrir shell de terminal interativo diretamente dentro do Android:
  `adb shell`

- Enviar arquivos do computador para a memória interna do smartphone:
  `adb push ./arquivo.zip /sdcard/Download/`

- Baixar fotos ou arquivos do celular para a pasta local:
  `adb pull /sdcard/DCIM/Camera/ ./fotos/`

- Espelhar a tela do aparelho com aceleração gráfica e taxa de quadros máxima:
  `scrcpy --max-fps 60 --video-bit-rate 16M`
EOF

log_success "Páginas do Tealdeer criadas em ${TEALDEER_PAGES_DIR}."

# -----------------------------------------------------------------------------
# 6. Atualização de Autocompletions e Permissões
# -----------------------------------------------------------------------------
log_info "Ajustando propriedade dos diretórios para ${TARGET_USER}..."
chown -R "${TARGET_USER}:users" "${USER_HOME}/.config" "${USER_HOME}/.local"

log_info "Atualizando base de dados de autocompletamento do Fish..."
su - "${TARGET_USER}" -c "
    # Gera arquivos de autocompletamento baseados nas manpages instaladas
    fish -c 'fish_update_completions' &>/dev/null || true
"

log_info "Tentando inicializar cache global de páginas do Tealdeer (requer internet)..."
su - "${TARGET_USER}" -c "
    tldr --update &>/dev/null || true
"

log_success "Módulo 07-terminal-fish.sh finalizado com sucesso."