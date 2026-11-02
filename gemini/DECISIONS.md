# Registro de Decisões de Arquitetura (`DECISIONS.md`)

Este documento registra formalmente todas as decisões arquiteturais, escolhas técnicas e trade-offs de engenharia realizados no projeto `arch-bootstrap`.

> **Para Engenheiros e Agentes de IA:** Antes de propor a substituição de qualquer ferramenta ou padrão adotado neste repositório, consulte o ADR correspondente para compreender os motivos e lições aprendidas que justificaram a escolha atual.

---

## Índice de Decisões (ADR)

* [ADR-001: Adoção do Compositor Wayland Monocle (Hyprland) sem Display Manager](#adr-001-adoção-do-compositor-wayland-monocle-hyprland-sem-display-manager)
* [ADR-002: Btrfs com Layout de Subvolumes Planos e Compressão Zstandard](#adr-002-btrfs-com-layout-de-subvolumes-planos-e-compressão-zstandard)
* [ADR-003: Snapper e snap-pac para Snapshots Automáticos vs Timeshift](#adr-003-snapper-e-snap-pac-para-snapshots-automáticos-vs-timeshift)
* [ADR-004: Módulo NVIDIA Open-DKMS como Padrão Moderno vs Proprietário Legado](#adr-004-módulo-nvidia-open-dkms-como-padrão-moderno-vs-proprietário-legado)
* [ADR-005: Swap Comprimido em RAM via ZRAM (zstd) vs Swapfile em NVMe](#adr-005-swap-comprimido-em-ram-via-zram-zstd-vs-swapfile-em-nvme)
* [ADR-006: Firewalld com Backend nftables vs Scripts Estáticos de iptables](#adr-006-firewalld-com-backend-nftables-vs-scripts-estáticos-de-iptables)
* [ADR-007: Elevação de Privilégios Efêmera (NOPASSWD Temporário) para Builds de AUR](#adr-007-elevação-de-privilégios-efêmera-nopasswd-temporário-para-builds-de-aur)
* [ADR-008: Isolamento de Ambientes de Desenvolvimento: FNM, UV e PEP 668](#adr-008-isolamento-de-ambientes-de-desenvolvimento-fnm-uv-e-pep-668)
* [ADR-009: Injeção de Buffer I/O Absoluto no Sysctl vs dirty_ratio Relativo](#adr-009-injeção-de-buffer-io-absoluto-no-sysctl-vs-dirty_ratio-relativo)

---

### ADR-001: Adoção do Compositor Wayland Monocle (Hyprland) sem Display Manager
* **Status:** Aceito
* **Contexto:** Ambientes de desktop tradicionais (GNOME, KDE Plasma) iniciam dezenas de daemons de segundo plano, indexadores de arquivo e gerenciadores de login (GDM, SDDM) consumindo 1.5 GB a 2.5 GB de RAM em repouso. No entanto, usar TTY puro inviabiliza aceleração por GPU moderna, navegadores com renderização complexa e espelhamento do Android (`scrcpy`).
* **Decisão:** Configurar o Hyprland em modo monocle puro (sem bordas, sem gaps, sem blur e sem animações), disparado exclusivamente após o login no `/dev/tty1`. As janelas ocupam 100% da tela e são alocadas em workspaces rígidos por categoria.
* **Alternativas Rejeitadas:**
  * *Sway / i3:* Não possuem pipeline de renderização nativo tão maduro para drivers NVIDIA em Wayland quanto o Hyprland com suporte a explicit sync e DRM moderno.
  * *TTY puro com KMSCON / fbcon:* Não suporta aceleração 3D por hardware para navegadores modernos ou jogos Steam.
* **Consequências:** Inicialização instantânea (< 1 segundo), consumo de RAM em repouso inferior a 450 MB e foco 100% voltado para produtividade em teclado.

---

### ADR-002: Btrfs com Layout de Subvolumes Planos e Compressão Zstandard
* **Status:** Aceito
* **Contexto:** Sistemas de arquivos convencionais (Ext4) não oferecem proteção nativa contra corrupção silenciosa de dados (bit rot), deduplicação ou snapshots instantâneos.
* **Decisão:** Adotar Btrfs com layout plano de subvolumes:
  * `@` montado em `/`
  * `@home` montado em `/home`
  * `@pkg` montado em `/var/cache/pacman/pkg`
  * `@log` montado em `/var/log`
  * `@snapshots` montado em `/.snapshots`
  Todos montados com a flag `compress=zstd:3,ssd,discard=async`.
* **Alternativas Rejeitadas:**
  * *Ext4 padrão:* Estável, porém sem suporte a snapshots do sistema para reversão imediata de atualizações com falha.
  * *ZFS no Linux:* Depende de módulos fora da árvore oficial do kernel que costumam quebrar a cada atualização de kernel do Arch Linux.
* **Consequências:** Economia de até 30% de espaço em disco graças à compressão Zstd em tempo real, maior vida útil do SSD NVMe e possibilidade de rollbacks atômicos.

---

### ADR-003: Snapper e snap-pac para Snapshots Automáticos vs Timeshift
* **Status:** Aceito
* **Contexto:** O Arch Linux é rolling release. Uma atualização de kernel ou driver NVIDIA pode ocasionalmente quebrar a inicialização gráfica.
* **Decisão:** Utilizar o `snapper` integrado ao hook `snap-pac` do pacman. Antes e depois de qualquer operação do gerenciador de pacotes, um snapshot pré/pós é gerado automaticamente.
* **Alternativas Rejeitadas:**
  * *Timeshift:* Exige layout de subvolumes específico rígido (`@` e `@home`) e não tem integração CLI tão nativa ou granular quanto o Snapper para servidores e terminais.
* **Consequências:** Permite reverter transações problemáticas do pacman em segundos ou restaurar o sistema diretamente pelo menu do boot com `grub-btrfs`.

---

### ADR-004: Módulo NVIDIA Open-DKMS como Padrão Moderno vs Proprietário Legado
* **Status:** Aceito
* **Contexto:** A NVIDIA oferece dois módulos para Linux: o binário proprietário fechado clássico (`nvidia-dkms`) e os módulos com código aberto (`nvidia-open-dkms`) lançados a partir da série R515.
* **Decisão:** Adotar `nvidia-open-dkms` como padrão recomendado no script [02-hardware.sh](../scripts/02-hardware.sh) (ideal para arquiteturas Turing, Ampere, Ada Lovelace e Blackwell), mantendo chave de configuração para fallback ao `nvidia-dkms` para quem possui GPUs mais antigas (GTX 9xx/10xx).
* **Alternativas Rejeitadas:**
  * *Driver Nouveau open-source reverso:* Não possui suporte a re-clocking de GPU, inviabilizando jogos 3D e aceleração CUDA.
* **Consequências:** Maior estabilidade com kernels customizados (como CachyOS e Zen), melhor conformidade com a GPL do kernel e menor incidência de bugs de gerenciamento de energia ao suspender o notebook.

---

### ADR-005: Swap Comprimido em RAM via ZRAM (zstd) vs Swapfile em NVMe
* **Status:** Aceito
* **Contexto:** Criar partições ou arquivos de swap em SSDs NVMe causa desgaste contínuo de células de escrita flash e gera congelamentos de I/O quando o sistema atinge o teto de memória RAM.
* **Decisão:** Utilizar `zram-generator` criando o dispositivo de bloco virtual `/dev/zram0` com algoritmo de compressão `zstd` em RAM.
* **Alternativas Rejeitadas:**
  * *Partição Swap física:* Lenta comparada à RAM e consome espaço estático do disco.
  * *Zswap:* Exige um dispositivo de swap físico de apoio, enquanto o ZRAM opera de forma 100% isolada na memória RAM.
* **Consequências:** Sistema ganha o equivalente a 1.5x a 2x de capacidade efetiva de memória sob carga pesada sem gerar lentidão perceptível no desktop.

---

### ADR-006: Firewalld com Backend nftables vs Scripts Estáticos de iptables
* **Status:** Aceito
* **Contexto:** A segurança em estações móveis conectadas a redes Wi-Fi diversas exige bloqueio de conexões de entrada sem intervenção manual contínua.
* **Decisão:** Habilitar o `firewalld` com zona padrão `public` em substituição a regras estáticas.
* **Alternativas Rejeitadas:**
  * *UFW (Uncomplicated Firewall):* Embora simples, o UFW utiliza regras estáticas mais antigas e frequentemente tem conflitos severos de roteamento com a interface de bridge do Docker (`docker0`).
  * *nftables puro sem daemon:* Exige edição manual de arquivos de configuração para abrir uma simples porta de desenvolvimento.
* **Consequências:** Facilidade de gerenciar portas com `firewall-cmd --add-port` em tempo real e suporte nativo a zonas de rede dinâmicas.

---

### ADR-007: Elevação de Privilégios Efêmera (NOPASSWD Temporário) para Builds de AUR
* **Status:** Aceito
* **Contexto:** O `makepkg` do Arch Linux proíbe categoricamente a compilação de código como usuário `root` por motivos de segurança. No entanto, durante scripts de automação não-interativos, o `makepkg -si` chama o `sudo pacman` para instalar dependências e trava solicitando senha.
* **Decisão:** Criar um arquivo temporário em `/etc/sudoers.d/` concedendo `NOPASSWD: ALL` ao usuário alvo durante a compilação, com garantia de remoção imediata através de um `trap cleanup EXIT`.
* **Alternativas Rejeitadas:**
  * *Deixar o usuário permanentemente com NOPASSWD no sudoers:* Grave vulnerabilidade de segurança operacional.
  * *Passar a senha via `echo password | sudo -S`:* Expõe credenciais em texto claro na tabela de processos (`ps`).
* **Consequências:** Execução 100% não-interativa e determinística durante a instalação, sem comprometer a segurança permanente pós-boot.

---

### ADR-008: Isolamento de Ambientes de Desenvolvimento: FNM, UV e PEP 668
* **Status:** Aceito
* **Contexto:** O Arch Linux adotou a especificação **PEP 668**, bloqueando o comando `pip install` global para proteger as bibliotecas de sistema escritas em Python. Similarmente, instalar versões globais do Node.js com múltiplos frameworks web gera quebras frequentes em dependências.
* **Decisão:**
  * Para Node.js: Utilizar o **FNM (Fast Node Manager)** em Rust, garantindo alternância transparente de versões com `.node-version`.
  * Para Python: Utilizar o **UV** (gerenciador ultrarrápido em Rust) e o **pipx** para CLI isoladas.
* **Alternativas Rejeitadas:**
  * *NVM tradicional:* Escrito em shell script lento, adiciona centenas de milissegundos ao tempo de abertura de cada novo terminal Fish.
  * *Remover a flag EXTERNALLY-MANAGED do Python:* Risco real de corromper utilitários do sistema operacional gerenciados pelo pacman.
* **Consequências:** Isolamento hermético de dependências de projetos sem comprometer o sistema base do Arch.

---

### ADR-009: Injeção de Buffer I/O Absoluto no Sysctl vs dirty_ratio Relativo
* **Status:** Aceito
* **Contexto:** Ao transferir arquivos grandes (ex: ISOs de 4 GB) para pendrives USB ou cartões de memória, o Linux padrão aloca até 20% da memória RAM em cache de escrita (`vm.dirty_ratio`). Em máquinas com 32 GB de RAM, isso representa mais de 6 GB retidos no buffer. Ao ejetar o dispositivo (`umount`), o sistema congela completamente por minutos até que todo o cache seja esvaziado na velocidade real da controladora USB (geralmente lenta).
* **Decisão:** Definir limites absolutos em bytes no `/etc/sysctl.d/99-io-performance.conf`:
  * `vm.dirty_background_bytes = 16777216` (16 MB)
  * `vm.dirty_bytes = 50331648` (48 MB)
* **Alternativas Rejeitadas:**
  * *Montar discos com a flag `sync`:* Destrói a performance de escrita aleatória e desgasta prematuramente memórias flash.
* **Consequências:** A barra de progresso da cópia de arquivos reflete a velocidade real da mídia e a ejeção via `safedrive` (`udisksctl unmount`) torna-se praticamente instantânea, eliminando congelamentos do desktop.
