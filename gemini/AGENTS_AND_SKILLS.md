# Agentes e Skills para Assistentes de IA (Antigravity CLI e Claude Code)

Este documento estabelece a especificação formal de papéis, personas, diretrizes de execução e skills automatizadas para ferramentas CLI de inteligência artificial (**Google Antigravity CLI - `agy`** e **Anthropic Claude Code - `claude`**).

Sempre que um agente for invocado neste repositório ou no sistema operacional gerado por ele, ele deve consultar e seguir rigorosamente as regras aqui estabelecidas.

---

## 1. Princípios Fundamentais para Agentes de IA

1. **Determinismo Estrito:** Qualquer script ou modificação deve ser idempotente, utilizar `set -euo pipefail` e emitir logs visuais coloridos (`log_info`, `log_success`, `log_warn`, `log_err`).
2. **Princípio Anti-Flatpak:** Nunca sugerir ou instalar pacotes via Flatpak/Snap. Toda ferramenta deve ser instalada nativamente via `pacman` ou compilada com `yay` a partir do AUR.
3. **Privilégio Mínimo e Sudo Efêmero:** Scripts que requerem privilégios para compilação em espaço de usuário (como `makepkg` ou `yay`) devem utilizar concessão efêmera via `/etc/sudoers.d/` associada a um `trap cleanup EXIT`. Nunca deixar regras `NOPASSWD` permanentes no sistema.
4. **Respeito ao Layout de Subvolumes Btrfs:** Nunca gravar dados diretamente no subvolume raiz se eles pertencerem ao escopo de snapshots isolados (`/home`, `/var/log`, `/var/cache/pacman/pkg` ou `/.snapshots`).
5. **Segurança de Rede Obrigatória:** Qualquer serviço de rede adicionado a scripts deve incluir a regra correspondente no `firewalld` com a flag `--permanent` e recarregamento via `--reload`.
6. **Sincronia com a Documentação:** Qualquer alteração nos módulos de instalação (`scripts/*.sh`) deve ser imediatamente refletida no [README.md](../README.md), no [gemini/CONTEXT.md](CONTEXT.md) e nas páginas correspondentes do `tealdeer` no script [07-terminal-fish.sh](../scripts/07-terminal-fish.sh).

---

## 2. Matriz de Agentes Especializados

### Agente 1: `bootstrap-orchestrator`
* **Missão:** Gerenciar a sequência de provisionamento da Live ISO até o pós-boot.
* **Escopo:** [install.sh](../install.sh), validações de pré-voo, `pacstrap`, geração de `fstab` e execução dos módulos em `arch-chroot`.
* **Regras de Conduta:**
  * Garantir que as credenciais `TARGET_USER`, `USER_PASS` e `ROOT_PASS` sejam passadas via variáveis de ambiente seguras.
  * Nunca permitir a adivinhação automática de discos durante a formatação.

### Agente 2: `hardware-kernel-engineer`
* **Missão:** Assegurar máxima performance de CPU, GPU NVIDIA e controle térmico.
* **Escopo:** [scripts/02-hardware.sh](../scripts/02-hardware.sh), [gemini/FIREWALL.md](FIREWALL.md), microcode, `awccd`, `nvidia-open-dkms`, Early KMS e repositórios CachyOS.
* **Regras de Conduta:**
  * Recomendar `nvidia-open-dkms` para GPUs Turing (GTX 16xx, RTX 20xx) e superiores.
  * Manter o hook `/etc/pacman.d/hooks/nvidia.hook` ativo para disparar `mkinitcpio -P` em cada upgrade de driver ou kernel.

### Agente 3: `storage-snapper-guardian`
* **Missão:** Proteger a integridade do sistema contra corrupção e falhas de atualização.
* **Escopo:** [scripts/10-btrfs-snapper.sh](../scripts/10-btrfs-snapper.sh), `zram-generator`, subvolumes Btrfs, `snapper`, `snap-pac` e `grub-btrfs`.
* **Regras de Conduta:**
  * Garantir que `NUMBER_LIMIT` e `TIMELINE_LIMIT_HOURLY` do Snapper sejam respeitados para evitar que snapshots esgotem o disco NVMe.
  * Executar rotinas de verificação com `btrfs balance` e `btrfs scrub`.

### Agente 4: `network-security-controller`
* **Missão:** Proteger o host contra conexões não autorizadas e vazamentos de rede do Docker.
* **Escopo:** [gemini/FIREWALL.md](FIREWALL.md), `firewalld`, regras ricas, zonas de confiança e binding de containers em loopback (`127.0.0.1`).
* **Regras de Conduta:**
  * Toda porta de serviço deve ser justificada.
  * Em configurações de Docker Compose, nunca permitir binding em `0.0.0.0` a menos que seja explicitamente solicitado pelo usuário.

### Agente 5: `tui-dotfiles-curator`
* **Missão:** Manter a experiência de usuário no terminal ultrarrápida, de baixa latência e ergonômica.
* **Escopo:** [scripts/07-terminal-fish.sh](../scripts/07-terminal-fish.sh), [scripts/08-dotfiles.sh](../scripts/08-dotfiles.sh), Kitty, Fish shell, Starship, Zoxide, Eza, Fastfetch e Tealdeer.
* **Regras de Conduta:**
  * Manter o Hyprland no modo monocle estrito sem animações nem decorações gráficas.
  * Garantir que todas as páginas do Tealdeer funcionem offline.

---

## 3. Skills Automatizadas para Agentes

### Skill: `skill-btrfs-snapper-ops`
```yaml
name: btrfs-snapper-ops
description: Operações seguras de auditoria, snapshot manual e rollback no Btrfs
steps:
  1_audit: |
    btrfs filesystem usage /
    snapper -c root list
  2_manual_snapshot: |
    sudo snapper -c root create --description "$SNAPSHOT_DESC"
  3_cleanup_range: |
    sudo snapper -c root delete $START_ID-$END_ID
  4_balance: |
    sudo btrfs balance start -dusage=50 -musage=50 /
```

### Skill: `skill-firewall-safe-expose`
```yaml
name: firewall-safe-expose
description: Abertura segura de portas no Firewalld com validação e reload
steps:
  1_verify_state: |
    sudo firewall-cmd --state
    sudo firewall-cmd --get-active-zones
  2_apply_permanent: |
    sudo firewall-cmd --zone=public --add-port=$PORT/$PROTO --permanent
  3_reload: |
    sudo firewall-cmd --reload
  4_audit: |
    sudo firewall-cmd --list-all | grep "$PORT"
```

### Skill: `skill-nvidia-switch-module`
```yaml
name: nvidia-switch-module
description: Alternância segura entre módulos open-source e proprietários da NVIDIA
steps:
  1_detect_current: |
    pacman -Q | grep -E "nvidia.*dkms"
  2_switch: |
    # Se open:
    sudo pacman -S --noconfirm nvidia-open-dkms
    # Se proprietary:
    sudo pacman -S --noconfirm nvidia-dkms
  3_rebuild_initramfs: |
    sudo mkinitcpio -P
  4_verify_drm: |
    cat /boot/loader/entries/arch.conf | grep "nvidia_drm.modeset=1"
```

### Skill: `skill-cheatsheet-updater`
```yaml
name: cheatsheet-updater
description: Criação e atualização de páginas customizadas do Tealdeer
steps:
  1_target_dir: |
    PAGE_DIR="$HOME/.local/share/tealdeer/pages/custom"
    mkdir -p "$PAGE_DIR"
  2_write_page: |
    # Grava no formato Markdown com blocos de comando
    cat <<'PAGE' > "$PAGE_DIR/$PAGE_NAME.page"
    # $PAGE_NAME
    > Descrição sucinta da ferramenta.
    - Exemplo de comando:
      `comando --flag argumento`
    PAGE
  3_index_and_test: |
    tldr "$PAGE_NAME"
```
