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
    starship                   # Prompt de linha de comando rápido e personalizável
    zoxide                     # Navegação inteligente de diretórios (z / cd moderno)
    eza                        # Substituto moderno do ls com ícones e status git
    fzf                        # Buscador fuzzy para histórico e navegação interativa
    htop                       # Monitor de processos interativo em terminal
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
# Listagem moderna com eza (ícones, permissões e status git)
if command -v eza &>/dev/null
    alias ls="eza --icons=auto"
    alias ll="eza -lh --icons=auto --git"
    alias la="eza -lah --icons=auto --git"
    alias tree="eza --tree --icons=auto"
else
    alias ls="ls --color=auto"
    alias ll="ls -lh --color=auto"
    alias la="ls -lah --color=auto"
end

# Integrações Modernas de Shell (Starship Prompt e Zoxide)
if command -v starship &>/dev/null
    starship init fish | source
end

if command -v zoxide &>/dev/null
    zoxide init fish | source
end

if command -v fnm &>/dev/null
    fnm env --use-on-cd --shell fish | source
end

# Utilitários de arquivo e cheatsheets
alias cat="ouch decompress"
alias t="tldr"

# Função interativa para seleção de cheatsheets com fzf
function colinha
    set -l pages_dir "$HOME/.local/share/tealdeer/pages/custom"
    if test -d "$pages_dir"
        set -l selected (ls $pages_dir/*.page 2>/dev/null | xargs -n 1 basename -s .page | fzf --prompt="Colinha CLI > " --height=40% --layout=reverse --border)
        if test -n "$selected"
            tldr "$selected"
        end
    else
        echo "Nenhuma página customizada encontrada em $pages_dir"
    end
end

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

# Página 6: Gestão de Versões Java (archlinux-java)
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-java.page"
# arch-java

> Gerenciamento e alternância de versões de JDK instaladas no Arch Linux.

- Listar todos os ambientes Java instalados e ver qual é o padrão:
  `archlinux-java status`

- Definir uma versão específica como padrão do sistema:
  `sudo archlinux-java set java-17-openjdk`

- Definir versão mais recente (OpenJDK mais novo) como padrão:
  `sudo archlinux-java set java-21-openjdk`

- Desmarcar a versão ativa do Java:
  `sudo archlinux-java unset`

- Verificar a versão em execução e variáveis de ambiente:
  `java -version && echo $JAVA_HOME`
EOF

# Página 7: Gerenciamento de Serviços e Logs (systemctl e journalctl)
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-systemd.page"
# arch-systemd

> Controle de daemons e análise de logs no Systemd.

- Iniciar ou parar um serviço imediatamente:
  `sudo systemctl start <servico>` / `sudo systemctl stop <servico>`

- Habilitar serviço para o boot e iniciar imediatamente:
  `sudo systemctl enable --now <servico>`

- Verificar status detalhado, PID e logs recentes de um serviço:
  `systemctl status <servico>`

- Listar unidades com falha de inicialização:
  `systemctl --failed`

- Acompanhar logs de um serviço em tempo real (follow mode):
  `journalctl -u <servico> -f`

- Inspecionar apenas erros e alertas críticos do boot atual:
  `journalctl -b -p err`

- Consultar logs de um intervalo de tempo específico:
  `journalctl --since "1 hour ago"`
EOF

# Página 8: Extração e Compressão Universal de Arquivos
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-compression.page"
# arch-compression

> Manipulação de arquivos compactados via CLI (ouch, tar, zip, 7z, zstd).

- Descompactar qualquer formato automaticamente com sintaxe universal (ouch):
  `ouch decompress arquivo.tar.gz` (ou via alias: `cat arquivo.tar.gz`)

- Compactar arquivos em qualquer formato suportado:
  `ouch compress pasta/ arquivo.tar.zst`

- Criar arquivo tar.gz clássico:
  `tar -czvf arquivo.tar.gz pasta/`

- Extrair arquivo tar.gz clássico:
  `tar -xzvf arquivo.tar.gz`

- Extrair arquivo tar.xz ou tar.bz2:
  `tar -xvf arquivo.tar.xz`

- Compactar e descompactar arquivos ZIP:
  `zip -r pacote.zip pasta/` e `unzip pacote.zip`

- Extrair arquivo 7z ou RAR:
  `7z x pacote.7z` ou `unrar x pacote.rar`
EOF

# Página 9: Gestão de Usuários, Grupos e Sessões Sudo
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-users-sudo.page"
# arch-users-sudo

> Administração de contas locais, grupos e elevação de privilégios com sudo.

- Criar novo usuário com diretório home e shell fish:
  `sudo useradd -m -s /usr/bin/fish <usuario>`

- Adicionar usuário existente a grupos secundários (ex: docker, libvirt, wheel):
  `sudo usermod -aG docker,libvirt,wheel <usuario>`

- Renovar o timestamp da sessão sudo (estender sem reabrir prompt):
  `sudo -v`

- Encerrar imediatamente a sessão sudo em cache (revogar autenticação ativa):
  `sudo -k`

- Editar sudoers com validação de sintaxe mandatória:
  `sudo visudo` (ou `sudo visudo -f /etc/sudoers.d/custom`)

- Listar grupos do usuário atual:
  `groups` ou `id`
EOF

# Página 10: Gerenciamento e Monitoramento de Processos
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-processes.page"
# arch-processes

> Monitoramento de consumo de hardware, sinais e encerramento de processos.

- Abrir monitor moderno de processos, CPU, GPU, memória e rede:
  `btop`

- Buscar o PID de um processo pelo nome:
  `pgrep -l <nome_do_processo>`

- Enviar sinal de encerramento amigável (SIGTERM):
  `pkill <nome_do_processo>` ou `kill <PID>`

- Forçar encerramento imediato de processo travado (SIGKILL):
  `kill -9 <PID>` ou `pkill -9 <nome_do_processo>`

- Listar processos ordenados por maior consumo de memória:
  `ps aux --sort=-%mem | head -n 15`

- Alterar prioridade de CPU de um processo em execução (-20 mais rápido a 19 mais lento):
  `sudo renice -n -5 -p <PID>`
EOF

# Página 11: Manutenção, Limpeza e Gerenciamento de Partições
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-maintenance.page"
# arch-maintenance

> Higienização de pacotes órfãos, cache, logs e análise de armazenamento.

- Inspecionar UUIDs, partições e espaço livre em disco:
  `lsblk -f` e `df -h`

- Limpar cache do pacman mantendo apenas as 2 versões mais recentes:
  `sudo paccache -r`

- Remover completamente pacotes órfãos (dependências não mais utilizadas):
  `sudo pacman -Rns (pacman -Qtdq)`

- Limpar histórico de logs do journalctl com mais de 7 dias ou maior que 200MB:
  `sudo journalctl --vacuum-time=7d` e `sudo journalctl --vacuum-size=200M`

- Limpar containers parados, imagens não usadas e volumes do Docker:
  `docker system prune -a --volumes`

- Analisar saúde de discos NVMe/SSD via SMART:
  `sudo smartctl -a /dev/nvme0n1`
EOF

# Página 12: Gerenciamento e Limpeza de Snapshots Btrfs (Snapper)
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-snapper.page"
# arch-snapper

> Criação, listagem, rollback e limpeza de snapshots Btrfs com Snapper.

- Listar todos os snapshots existentes da partição raiz:
  `snapper -c root list`

- Listar snapshots do subvolume /home:
  `snapper -c home list`

- Criar um snapshot manual antes de testes arriscados:
  `sudo snapper -c root create --description "Antes-da-modificacao"`

- Deletar um snapshot específico pelo ID para liberar espaço:
  `sudo snapper -c root delete <ID>`

- Deletar um intervalo de snapshots antigos:
  `sudo snapper -c root delete 10-25`

- Comparar diferenças entre dois snapshots ou entre um snapshot e o sistema atual:
  `snapper -c root status 5..0`

- Executar balanceamento e limpeza de blocos não alocados no Btrfs:
  `sudo btrfs balance start -dusage=50 -musage=50 /`

- Verificar integridade de dados e checksums em segundo plano (Scrub):
  `sudo btrfs scrub start /` e `sudo btrfs scrub status /`
EOF

# Página 13: Administração do Firewall (Firewalld / firewall-cmd)
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-firewall.page"
# arch-firewall

> Gerenciamento de zonas de rede, portas e regras do Firewalld via CLI.

- Inspecionar o estado ativo do firewall e zona de rede em vigor:
  `sudo firewall-cmd --state` e `sudo firewall-cmd --get-active-zones`

- Exibir todas as regras, portas e serviços liberados na zona padrão:
  `sudo firewall-cmd --list-all`

- Liberar um serviço de rede pré-definido de forma permanente:
  `sudo firewall-cmd --add-service=ssh --permanent && sudo firewall-cmd --reload`

- Liberar uma porta TCP específica (ex: 8080 para desenvolvimento web):
  `sudo firewall-cmd --add-port=8080/tcp --permanent && sudo firewall-cmd --reload`

- Liberar uma porta UDP específica (ex: 19132 para servidores de jogos):
  `sudo firewall-cmd --add-port=19132/udp --permanent && sudo firewall-cmd --reload`

- Fechar e revogar uma porta aberta anteriormente:
  `sudo firewall-cmd --remove-port=8080/tcp --permanent && sudo firewall-cmd --reload`

- Bloquear um endereço IP malicioso com regra rica (Rich Rule):
  `sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.1.150" reject' --permanent && sudo firewall-cmd --reload`
EOF

# Página 14: GPU NVIDIA (Módulos DKMS, Prime Offload e EnvyControl)
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-nvidia.page"
# arch-nvidia

> Gestão de módulos NVIDIA (open vs proprietário), PRIME render offload e EnvyControl.

- Executar aplicação na GPU dedicada NVIDIA sob demanda (PRIME Offload):
  `prime-run <comando>` (ex: `prime-run steam` ou `prime-run obs`)

- Consultar modo gráfico ativo no notebook híbrido (EnvyControl):
  `envycontrol --query`

- Alternar para o modo Híbrido (iGPU para desktop + dGPU sob demanda):
  `sudo envycontrol -s hybrid`

- Alternar para o modo Integrado (desliga totalmente a GPU NVIDIA para poupar bateria):
  `sudo envycontrol -s integrated`

- Alternar para o modo Dedicado NVIDIA (GPU dGPU processa tudo diretamente):
  `sudo envycontrol -s nvidia`

- Alternar entre módulos NVIDIA Open e Proprietário:
  `sudo pacman -S nvidia-open-dkms` (para Turing ou superior: RTX 20/30/40/50, GTX 16xx)
  `sudo pacman -S nvidia-dkms` (para Pascal/Maxwell legado: GTX 10xx, 9xx)
  `sudo mkinitcpio -P`
EOF

# Página 15: Repositório e Kernels CachyOS
cat <<'EOF' > "${TEALDEER_PAGES_DIR}/arch-cachyos.page"
# arch-cachyos

> Repositórios com binários compilados em x86-64-v3/v4 e kernels de baixa latência BORE.

- Testar compatibilidade de instruções da sua CPU com x86-64-v3:
  `/lib64/ld-linux-x86-64.so.2 --help | grep -i supported`

- Instalar kernel CachyOS de alta responsividade para jogos e desktop:
  `sudo pacman -S linux-cachyos linux-cachyos-headers`

- Regenerar imagens initramfs de todos os kernels instalados:
  `sudo mkinitcpio -P`

- Atualizar mirrorlists do CachyOS com servidores de menor latência:
  `sudo cachyos-rate-mirrors`
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