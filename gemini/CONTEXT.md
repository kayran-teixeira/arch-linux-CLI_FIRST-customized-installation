# CONTEXT: Arch Linux Bootstrap (CLI-First Setup)

Este documento centraliza todas as especificações arquiteturais, decisões de engenharia, listas de pacotes, configurações de baixo nível e regras operacionais para o desenvolvimento, execução e manutenção do repositório `arch-bootstrap`. Ele serve como contexto integral para automação, geração de código e refatoração via **Antigravity CLI** e **Claude Code**.

---

## 1. Visão Geral e Filosofia do Sistema

* **Objetivo:** Transformar uma instalação padrão do Arch Linux em uma estação de trabalho estritamente **CLI-First** (focada em terminal e teclado), eliminando Display Managers e decorações gráficas pesadas, sem abrir mão de:
  1. Aceleração de hardware e estabilidade com GPU dedicada NVIDIA em Wayland.
  2. Execução nativa de jogos modernos (Steam/Proton com drivers multilib de 32 bits).
  3. Navegação web moderna sem fallbacks ilegíveis em modo texto.
  4. Desenvolvimento de software profissional (Java/Android, Node.js via FNM, Python via UV/Pipx, KVM/QEMU e Docker).
  5. Ergonomia e controle de hardware de ponta a ponta via terminal e cheatsheets integradas (`tealdeer` / `colinha`).
  6. Proteção de dados e integridade contra atualizações quebradas via snapshots instantâneos Btrfs gerenciados pelo Snapper.
  7. Segurança ativa de rede através de filtragem dinâmica com Firewalld.
* **Princípio Anti-Flatpak:** Todos os componentes desktop e utilitários são instalados nativamente via repositórios oficiais (`pacman`) ou compilados a partir do AUR (`yay`), garantindo integração limpa com sockets de sistema, drivers do host e pipelines de I/O.
* **Modelo "Fake CLI" (Monocle Wayland):**
  * Boot direto no TTY físico (`/dev/tty1`).
  * Autostart condicional do **Hyprland** disparado pelo shell Fish exclusivamente no TTY1.
  * O compositor atua como um multiplexador de tela cheia sem bordas (`border_size = 0`), sem espaçamentos (`gaps = 0`) e sem animações (`animations = false`).
  * As aplicações são isoladas rigidamente em workspaces numéricos dedicados via `windowrulev2`.

---

## 2. Especificações de Hardware e Sistema Operacional

* **Sistema Base:** Arch Linux (Rolling Release, kernel `linux` padrão + `linux-headers`, ou kernel otimizado `linux-cachyos`).
* **Arquitetura de Boot:** UEFI Nativo (GPT) particionado manualmente, inicializado via `systemd-boot` (ou `GRUB` com `grub-btrfs`).
* **Dispositivo Alvo:** Notebook Dell G15 (série 5530 / Dell Gaming).
  * **CPU:** Intel Core (requer injeção de `intel-ucode.img` no bootloader).
  * **GPU:** NVIDIA GeForce RTX dedicada (suporte a `nvidia-open-dkms` como padrão moderno ou `nvidia-dkms` legado, Early KMS, flags Wayland DRM e alternância com `envycontrol` / `nvidia-prime`).
  * **Chassi e Refrigeração:** Controladora proprietária Dell WMI gerenciada via daemon `awccd-git` (suporte ao G-Mode/Performance profile).
* **Armazenamento e Particionamento:**
  * **Layout Primário Recomendado (Btrfs):**
    * Partição EFI (`/dev/nvme0n1p1`): 1 GB FAT32 montado em `/boot`.
    * Partição Raiz (`/dev/nvme0n1p2`): Btrfs com subvolumes `@` (`/`), `@home` (`/home`), `@pkg` (`/var/cache/pacman/pkg`), `@log` (`/var/log`) e `@snapshots` (`/.snapshots`), montados com `compress=zstd:3,ssd,discard=async`.
  * **Layout Alternativo (Ext4):** Partição raiz única Ext4 com identificador UUID.
* **Gerenciamento de Memória e Swap:** `zram-generator` configurando swap comprimido em RAM (`zram0`) via Zstandard.
* **Pipeline de Áudio:** PipeWire nativo (`pipewire-pulse`, `pipewire-alsa`, `pipewire-jack` e `wireplumber`).
* **Segurança de Rede:** `firewalld` ativo com backend nftables e zona padrão `public`.

---

## 3. Árvore de Diretórios do Repositório

```text
arch-bootstrap/
├── README.md                      # Manual pré-instalação, cheatsheets completas e guias de administração
├── install.sh                     # Orquestrador de execução externa na Live ISO (Pre-flight, pacstrap e chroot)
├── gemini/                        # Base de conhecimento e governança para agentes de IA
│   ├── INDEX.md                   # Roteador rápido de contexto (< 60 tokens)
│   ├── PROGRESS.md                # Controle vivo de progresso, marcos e backlog
│   ├── DECISIONS.md               # Architecture Decision Records (ADRs)
│   ├── RUNBOOK.md                 # Playbooks operacionais e resolução de incidentes
│   ├── FIREWALL.md                # Manual exaustivo do Firewalld e integração Docker
│   ├── CONTEXT.md                 # Especificação técnica master de engenharia
│   ├── AGENTS_AND_SKILLS.md       # Papéis de agentes, ferramentas e skills executáveis
│   ├── TOKEN_OPTIMIZATION_AND_AI_OPS.md # Padrões de economia de tokens e baixo overhead
│   └── AI_WORKFLOW_RULES.md       # Regras de engajamento e ciclo de trabalho da IA
└── scripts/
    ├── 01-base-chroot.sh          # Locales, fstab, sysctl I/O, ZRAM (zstd), firewalld, usuário e bootloader
    ├── 02-hardware.sh             # NVIDIA Open/DKMS, early KMS, PRIME, PipeWire e awccd (Dell G15)
    ├── 03-virtualization.sh       # KVM, QEMU, libvirt, virt-manager, vhost-net e rede virbr0
    ├── 04-aur-yay.sh              # Provisionamento do AUR helper yay com sudo NOPASSWD efêmero
    ├── 04-cli-tools.sh            # (Symlink / Arquivo canônico do yay)
    ├── 05-packages.sh             # Dolphin, GParted, Steam, OBS, JDKs (8, 11, 17, 21), Python (uv/pipx), EnvyControl
    ├── 06-android-dev.sh          # Android tools, android-udev, scrcpy, fs.inotify e Android Studio
    ├── 07-terminal-fish.sh        # Kitty, Fish, Starship, Zoxide, Eza, FZF, Fastfetch, Tealdeer e função colinha
    ├── 08-dotfiles.sh             # Hyprland monocle, keybinds de hardware, Mako e autostart TTY1
    ├── 09-dev-services.sh         # NodeJS, FNM, Docker daemon com limits, Claude Code CLI e Antigravity CLI
    └── 10-btrfs-snapper.sh        # Configuração do Snapper, snap-pac, timers de retenção e integração grub-btrfs
```

---

## 4. Matriz de Problemas Críticos e Soluções Implementadas

| Problema / Gargalo Detectado | Causa Técnica no Linux | Solução Implementada nos Scripts |
| :--- | :--- | :--- |
| **Congelamento em 100% ao ejetar USB / MTP** | Parâmetro `vm.dirty_ratio` relativo retém gigabytes na RAM antes de flush. | Substituição por limites absolutos em bytes: `vm.dirty_bytes = 50331648` e `vm.dirty_background_bytes = 16777216` em `/etc/sysctl.d/99-io-performance.conf`. |
| **Tela preta / Flickering na NVIDIA com Wayland** | Kernel carrega módulo de vídeo tardiamente; ausência de KMS e GBM backend. | Inclusão de `nvidia` no `MODULES` do `mkinitcpio.conf`, flags `nvidia_drm.modeset=1 nvidia_drm.fbdev=1` no bootloader e variáveis `GBM_BACKEND=nvidia-drm`. |
| **Travamento de builds do Gradle / Android Studio** | Limite padrão de 8.192 observadores do `inotify` é esgotado pelo indexador. | Injeção de `fs.inotify.max_user_watches = 524288` em `/etc/sysctl.d/99-android-inotify.conf`. |
| **Erro `no permissions` no ADB** | Dispositivos USB não têm grupo correspondente nas regras padrão do udev. | Instalação do pacote `android-udev`, criação do grupo `adbusers` e adição do usuário no script 06. |
| **Dolphin quebrado / Ícones ausentes fora do KDE** | Falta de temas Breeze, KIO-extras e bibliotecas de thumbnailing nativas Qt. | Instalação casada de `breeze-icons`, `kio-extras`, `kio-admin`, `ffmpegthumbs` e variáveis `QT_QPA_PLATFORMTHEME=qt6ct`. |
| **Quebra de build do yay em chroot / script** | `makepkg` recusa rodar como root; `sudo pacman` pede senha em terminal não-interativo. | Usuário executa compilação via `su - $TARGET_USER -c` com `NOPASSWD` temporário protegido por `trap cleanup EXIT`. |
| **Conflito de versões de Node.js e Python (PEP 668)** | O Arch é rolling release e bloqueia `pip install` global via PEP 668. | Adoção do `fnm` (Fast Node Manager) para Node LTS e do `uv` + `pipx` para isolamento de interpretadores Python. |
| **Interface do Steam sem texto / sem jogos 32-bit** | Falta de bibliotecas multilib e de fontes TrueType mandatórias (`ttf-liberation`). | Habilitação do repositório `[multilib]`, instalação de `lib32-nvidia-utils` e fontes nos scripts 02 e 05. |
| **Quebra de sistema em atualizações do Arch** | Pacotes rolling release atualizados podem ocasionalmente gerar regressões. | Particionamento Btrfs com subvolumes isolados e Snapper com hook `snap-pac` criando snapshots pré/pós transações pacman. |
| **Swapping agressivo em disco gerando stuttering** | Swap tradicional em partições NVMe consome I/O e desgasta células de memória. | Adoção do `zram-generator` criando disco de swap dinâmico na RAM compactado via Zstandard (`zram0`). |

---

## 5. Módulos Técnicos e Especificações de Código

### 5.1. `install.sh` (Orquestrador da Live ISO)
* **Validações Pré-Voo:**
  * Execução mandatória como root (`EUID -ne 0`).
  * Testa conectividade com `archlinux.org`.
  * Valida montagem mandatória dos pontos `mountpoint -q /mnt` e `mountpoint -q /mnt/boot`.
* **Operações Nucleares:**
  * Executa `pacstrap -K /mnt base base-devel linux linux-firmware networkmanager git sudo nano`.
  * Gera o `fstab` com UUIDs (`genfstab -U /mnt >> /mnt/etc/fstab`).
  * Copia a árvore de scripts para `/mnt/root/arch-bootstrap/`.
  * Executa ordenadamente via `arch-chroot /mnt` os módulos de `01` a `10`.
  * Limpa os scripts temporários ao finalizar.

### 5.2. `scripts/01-base-chroot.sh`
* **Localização e Fuso:** `America/Sao_Paulo`, locales `en_US.UTF-8` e `pt_BR.UTF-8`, console com `KEYMAP=br-abnt2`.
* **Kernel I/O Tuning:** `/etc/sysctl.d/99-io-performance.conf` com `vm.dirty_bytes` absoluto e `vm.swappiness = 10`.
* **ZRAM:** Instala `zram-generator` e grava `/etc/systemd/zram-generator.conf` com `compression-algorithm = zstd`.
* **Segurança e Rede:** Habilita `NetworkManager.service`, `firewalld.service` e `systemd-timesyncd.service`.
* **Controle de Acesso:** Usuário criado com shell `/usr/bin/fish`, membro de `wheel,video,audio,storage,input`. Sudoers configurado com timeout de 30 minutos em `/etc/sudoers.d/10-installer`.
* **Bootloader:** Inicializa `systemd-boot` com entrada apontando para o UUID da raiz.

### 5.3. `scripts/02-hardware.sh`
* **Multilib:** Habilita `[multilib]` no `/etc/pacman.conf`.
* **Microcode:** Injeta `intel-ucode` ou `amd-ucode` automaticamente no loader.
* **Stack NVIDIA:**
  * Suporta `nvidia-open-dkms` (padrão) ou `nvidia-dkms`.
  * Instala `nvidia-utils`, `lib32-nvidia-utils`, `nvidia-prime`, `libva-nvidia-driver`, `nvtop`.
  * Early KMS: injeta `nvidia nvidia_modeset nvidia_uvm nvidia_drm` no `MODULES` do `mkinitcpio.conf`.
  * Hook automático do pacman para regeneração do initramfs.
* **Áudio:** Pipeline completo PipeWire + WirePlumber.
* **Dell G15:** Compilação do `awccd-git` via AUR com sudo efêmero, módulo `dell-wmi` e ativação do daemon `awccd.service`.

### 5.4. `scripts/03-virtualization.sh`
* **Hipervisor KVM/QEMU & Virt-Manager:** `qemu-desktop`, `qemu-img`, `libvirt`, `virt-install`, `virt-manager`, `edk2-ovmf`, `dnsmasq`, `iptables-nft`.
* **Kernel:** Módulo `vhost_net` habilitado no boot.
* **Permissões:** Usuário membro de `kvm,libvirt`. Autostart da rede virtual `virbr0`.
* **Daemons:** `libvirtd.service` e `virtlogd.service` habilitados.

### 5.5. `scripts/04-cli-tools.sh` / `04-aur-yay.sh`
* Concede `NOPASSWD` temporário protegido por `trap cleanup EXIT`.
* Compila o `yay` via `makepkg -si` sob o usuário alvo.
* Revoga imediatamente o sudo sem senha e ativa as flags permanentes `--cleanafter --removemake`.

### 5.6. `scripts/05-packages.sh`
* **Desktop & Discos:** `dolphin`, `gparted`, drivers de sistema de arquivos (`dosfstools`, `ntfs-3g`, `exfatprogs`).
* **Compressão:** `ouch`, `tar`, `p7zip`, `unrar`, `unzip`, `zip`, `zstd`.
* **Jogos & Mídia:** `steam`, `obs-studio`, `vlc`, fontes `ttf-liberation`.
* **Matriz Java:** `jdk8-openjdk`, `jdk11-openjdk`, `jdk17-openjdk` (padrão), `jdk21-openjdk`.
* **Runtimes Python:** `python`, `python-pip`, `python-pipx`, `uv`.
* **AUR:** `visual-studio-code-bin`, `jetbrains-toolbox`, `atlauncher-bin`, `envycontrol`.

### 5.7. `scripts/06-android-dev.sh`
* **Comunicação Android:** `android-tools` (ADB/fastboot), `android-udev`, `scrcpy`, `gvfs-mtp`.
* **Kernel Tuning:** `fs.inotify.max_user_watches = 524288`.
* **SDK Path:** Configuração global em `/etc/profile.d/android.sh`.
* **IDE:** Instalação do `android-studio` via AUR.

### 5.8. `scripts/07-terminal-fish.sh`
* **Terminal & Shell:** `kitty`, `fish`, `starship`, `zoxide`, `eza`, `fzf`, `htop`, `fastfetch`, `tealdeer`.
* **Kitty:** Otimização de baixa latência (`sync_to_monitor yes`, `repaint_delay 8`, `input_delay 2`).
* **Fish (`config.fish`):**
  * Inicializações de `starship`, `zoxide` e `fnm`.
  * Aliases modernos com `eza` (`ls`, `ll`, `la`, `tree`), `cat="ouch decompress"`, `t="tldr"`.
  * Função `colinha`: Seletor interativo via `fzf` para consultar as cheatsheets locais do `tealdeer`.
* **Páginas Customizadas do Tealdeer:**
  * `arch-snapper`: Gestão e limpeza de snapshots Btrfs.
  * `arch-cachyos`: Configuração do repositório e kernels BORE.
  * `arch-nvidia`: Módulos NVIDIA, `prime-run` e `envycontrol`.
  * `arch-firewall`: Comandos de gerenciamento do `firewalld`.
  * `arch-java`: Alternância de JDKs com `archlinux-java`.
  * `arch-systemd`: Controle de daemons e análise de logs com `journalctl`.
  * `arch-compression`: Sintaxe universal do `ouch` e utilitários clássicos.
  * `arch-users-sudo`: Sessões sudo (`sudo -v`, `sudo -k`) e contas locais.
  * `arch-processes`: Sinais de processo, prioridades e `btop`.
  * `arch-maintenance`: Limpeza de cache pacman, órfãos e logs.

### 5.9. `scripts/08-dotfiles.sh`
* **Hyprland Monocle:** Zero bordas, zero gaps, animações e sombras desativadas.
* **Isolamento de Janelas:** Workspaces fixos para Terminal (1), IDEs (2), Arquivos (8), Navegador (9) e Jogos (10).
* **Autostart TTY1:** Gatilho condicional com flags de renderização NVIDIA Wayland (`GBM_BACKEND=nvidia-drm`, `LIBVA_DRIVER_NAME=nvidia`).

### 5.10. `scripts/09-dev-services.sh`
* **Node.js:** `nodejs`, `npm`, `fnm` (Fast Node Manager).
* **Docker:** Instalação de `docker`, `docker-compose`, `docker-buildx`, configuração de `/etc/docker/daemon.json` com limites de log, adição do usuário ao grupo `docker` e habilitação do serviço `docker.service`.
* **Agentes de IA:**
  * **Claude Code CLI:** `@anthropic-ai/claude-code` via npm global.
  * **Google Antigravity CLI:** `agy` instalado em `~/.local/bin/agy` via instalador oficial.

### 5.11. `scripts/10-btrfs-snapper.sh`
* **Validação:** Detecta se a raiz é Btrfs antes de prosseguir.
* **Provisionamento:** Configura perfis do Snapper para `/` e `/home`.
* **Retenção:** Limita histórico a 15 snapshots numéricos e 5 snapshots por hora.
* **Automação:** Ativa `snapper-timeline.timer` e `snapper-cleanup.timer`.
* **Rollback Boot:** Integração com `grub-btrfsd.service` caso o GRUB seja utilizado.

---

## 6. Critérios de Aceite e Verificação do Sistema

1. **Boot e Login:** O sistema inicializa no TTY1 pedindo login. Ao autenticar, o Hyprland inicia em menos de 1 segundo sem display manager, renderizando o Kitty com Starship prompt e Fastfetch.
2. **GPU NVIDIA:** `nvidia-smi` exibe a GPU dedicada ativa com processos do Hyprland rodando sob driver proprietário/open; `prime-run` direciona aplicações 3D para a dGPU.
3. **Áudio e Hardware:** `wpctl status` confirma endpoints PipeWire funcionais; `awcc-cli` responde com os modos do Dell G15.
4. **Armazenamento e Snapshots:**
   * `btrfs subvolume list /` exibe a estrutura de subvolumes planos.
   * `snapper -c root list` exibe snapshots ativos gerados automaticamente por `snap-pac`.
   * `safedrive` ejeta discos externos sem retenção no cache de RAM.
5. **Virtualização e Containers:**
   * `virsh list --all` executa sem sudo e a rede `default` (`virbr0`) está ativa.
   * `docker run --rm hello-world` roda sem `sudo` e limpa o container.
6. **Segurança e Rede:**
   * `sudo firewall-cmd --state` retorna `running`.
7. **Runtimes e IA:**
   * `archlinux-java get` retorna `java-17-openjdk`.
   * `claude --version` e `agy --version` respondem diretamente no prompt do usuário.
8. **Documentação Integrada:** O comando `colinha` abre o seletor FZF com todas as páginas do Tealdeer.
