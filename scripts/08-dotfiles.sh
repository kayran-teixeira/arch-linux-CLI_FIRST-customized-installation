#!/usr/bin/env bash
#
# scripts/08-dotfiles.sh - Configuração do Compositor Wayland (Hyprland Monocle) e Autostart TTY1
# Responsabilidades:
# 1. Instalar utilitários de suporte ao compositor (xdg-desktop-portal-hyprland, mako, brightnessctl)
# 2. Configurar o Hyprland em modo "monocle" puro (sem bordas, gaps, blur ou animações)
# 3. Mapear regras de isolamento de janelas (Terminais, Navegadores, IDEs, Dolphin, Steam)
# 4. Configurar binds universais de hardware (wpctl para áudio, brightnessctl para tela, perfis Dell G15)
# 5. Configurar o daemon de notificações Mako
# 6. Injetar gatilho de inicialização automática no Fish para login exclusivo no TTY1 com flags NVIDIA
# 7. Ajustar permissões definitivas na pasta home do usuário alvo
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[08-DOTFILES]${NC} $1"; }
log_success() { echo -e "${GREEN}[08-DOTFILES:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[08-DOTFILES:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[08-DOTFILES:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"
USER_HOME="/home/${TARGET_USER}"

# -----------------------------------------------------------------------------
# 1. Pacotes de Infraestrutura do Compositor Wayland
# -----------------------------------------------------------------------------
log_info "Instalando Hyprland, portais Wayland e daemons de suporte..."

HYPR_PACKAGES=(
    hyprland                        # Compositor Wayland dinâmico baseado no wlroots
    xdg-desktop-portal-hyprland     # Suporte a screen-sharing (WebRTC/Discord) e diálogos
    polkit-gnome                    # Agente de autenticação para elevação de privilégios
    mako                            # Daemon leve de notificações desktop
    wl-clipboard                    # Utilitários de controle de clipboard Wayland
    brightnessctl                   # Controle de brilho da tela via CLI
    libnotify                       # Comando notify-send para scripts
)

pacman -S --noconfirm --needed "${HYPR_PACKAGES[@]}"
log_success "Pacotes do ambiente gráfico mínimo instalados."

# -----------------------------------------------------------------------------
# 2. Configuração do Hyprland Monocle (Sem Decorações e Focado em Teclado)
# -----------------------------------------------------------------------------
log_info "Configurando ${USER_HOME}/.config/hypr/hyprland.conf..."

HYPR_CONF_DIR="${USER_HOME}/.config/hypr"
mkdir -p "${HYPR_CONF_DIR}"

cat <<'EOF' > "${HYPR_CONF_DIR}/hyprland.conf"
# ==============================================================================
# HYPRLAND - Configuração Monocle / CLI-First Minimalista
# ==============================================================================

# 1. Monitor (Detecção Automática de Resolução e Taxa de Atualização Máxima)
monitor=,preferred,auto,1

# 2. Inicialização de Daemons e Aplicações Críticas
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = mako
exec-once = [workspace 1 silent] kitty

# 3. Estética Monocle (Zero Distrações, Foco 100% em Terminal)
general {
    gaps_in = 0
    gaps_out = 0
    border_size = 0
    layout = master
    no_focus_fallback = true
}

decoration {
    rounding = 0
    blur {
        enabled = false
    }
    shadow {
        enabled = false
    }
}

animations {
    enabled = false
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
    background_color = 0x0f1117
    vrr = 1
}

master {
    new_status = master
    mfact = 0.50
}

# 4. Regras de Isolamento de Janelas por Workspace
# Workspace 1: Terminal Principal
windowrulev2 = workspace 1, class:^(kitty)$

# Workspace 2: IDEs e Editores de Código
windowrulev2 = workspace 2, class:^(code-url-handler|Code|visual-studio-code-bin)$
windowrulev2 = workspace 2, class:^(jetbrains-.*)$
windowrulev2 = workspace 2, class:^(android-studio)$

# Workspace 8: Gestão de Arquivos e Discos
windowrulev2 = workspace 8, class:^(org.kde.dolphin)$
windowrulev2 = workspace 8, class:^(GParted)$

# Workspace 9: Navegadores Web (Modo Tela Cheia)
windowrulev2 = workspace 9, class:^(firefox)$
windowrulev2 = fullscreen, class:^(firefox)$
windowrulev2 = workspace 9, class:^(google-chrome|chromium)$

# Workspace 10: Jogos e Mídia
windowrulev2 = workspace 10, class:^(steam)$
windowrulev2 = workspace 10, class:^(gamescope)$
windowrulev2 = workspace 10, class:^(com.atlauncher.App)$
windowrulev2 = workspace 10, class:^(com.obsproject.Studio)$

# 5. Mapeamento de Teclado e Atalhos (Keybinds)
$mainMod = SUPER

# Lançadores Principais
bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, F, fullscreen, 1

# Aplicações Isoladas
bind = $mainMod, B, exec, firefox
bind = $mainMod, E, exec, dolphin
bind = $mainMod, C, exec, code
bind = $mainMod, S, exec, steam

# Alternância de Perfis Térmicos do Dell G15 via awccd
bind = $mainMod, G, exec, awcc-cli --set-profile Performance && notify-send "Dell G15" "Perfil Performance (G-Mode) Ativado"
bind = $mainMod SHIFT, G, exec, awcc-cli --set-profile Balanced && notify-send "Dell G15" "Perfil Balanceado Ativado"

# Controle de Áudio via PipeWire (WirePlumber)
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl  = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

# Controle de Brilho da Tela
bindel = , XF86MonBrightnessUp, exec, brightnessctl set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Navegação Direta de Workspaces (1 a 10)
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Mover Janela Ativa para Workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10
EOF

log_success "Arquivo hyprland.conf configurado."

# -----------------------------------------------------------------------------
# 3. Configuração do Daemon de Notificações Mako
# -----------------------------------------------------------------------------
log_info "Configurando estilo visual compacto em ${USER_HOME}/.config/mako/config..."

MAKO_CONF_DIR="${USER_HOME}/.config/mako"
mkdir -p "${MAKO_CONF_DIR}"

cat <<'EOF' > "${MAKO_CONF_DIR}/config"
font=JetBrainsMono Nerd Font 10
background-color=#0f1117ee
text-color=#cdd6f4
border-color=#89b4fa
border-size=1
border-radius=0
default-timeout=4000
margin=16
padding=10
anchor=top-right
EOF

log_success "Arquivo mako/config criado."

# -----------------------------------------------------------------------------
# 4. Autostart via TTY1 com Flags NVIDIA e Wayland no Shell Fish
# -----------------------------------------------------------------------------
log_info "Configurando autostart no Fish (~/.config/fish/conf.d/tty-autostart.fish)..."

FISH_CONFD="${USER_HOME}/.config/fish/conf.d"
mkdir -p "${FISH_CONFD}"

cat <<'EOF' > "${FISH_CONFD}/tty-autostart.fish"
# Dispara o Hyprland automaticamente apenas no login interativo do terminal físico TTY1
if status is-login
    if test (tty) = "/dev/tty1"
        if test -z "$WAYLAND_DISPLAY" -a -z "$DISPLAY"
            # -----------------------------------------------------------------
            # Variáveis de Renderização de Baixo Nível para Wayland + GPU NVIDIA
            # -----------------------------------------------------------------
            set -gx XDG_SESSION_TYPE wayland
            set -gx XDG_CURRENT_DESKTOP Hyprland
            set -gx XDG_SESSION_DESKTOP Hyprland

            # Força engines web e navegadores a rodarem via Wayland nativo
            set -gx MOZ_ENABLE_WAYLAND 1
            set -gx ELECTRON_OZONE_PLATFORM_HINT auto

            # Aceleração de Hardware via Driver Proprietário NVIDIA
            set -gx LIBVA_DRIVER_NAME nvidia
            set -gx GBM_BACKEND nvidia-drm
            set -gx __GLX_VENDOR_LIBRARY_NAME nvidia
            set -gx NVD_BACKEND direct

            # Renderização de cursor por hardware para evitar atraso visual
            set -gx WLR_NO_HARDWARE_CURSORS 0

            # Inicialização com substituição limpa de processo
            exec Hyprland
        end
    end
end
EOF

log_success "Gatilho de autostart do TTY1 registrado."

# -----------------------------------------------------------------------------
# 5. Ajuste Rigoroso de Propriedade e Permissões
# -----------------------------------------------------------------------------
log_info "Garantindo propriedade dos arquivos de configuração para ${TARGET_USER}..."
chown -R "${TARGET_USER}:users" "${USER_HOME}/.config"

log_success "Módulo 08-dotfiles.sh finalizado com sucesso."