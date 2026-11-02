#!/usr/bin/env bash
#
# scripts/03-virtualization.sh - Stack KVM, QEMU e Libvirt (CLI-Only)
# Responsabilidades:
# 1. Instalar hipervisor QEMU/KVM, firmwares UEFI (OVMF) e ferramentas CLI (virt-install)
# 2. Configurar dependências de rede virtual (dnsmasq, iptables-nft, vhost-net)
# 3. Adicionar o usuário alvo aos grupos kvm e libvirt (gerenciamento sem sudo)
# 4. Ajustar permissões dos sockets UNIX do libvirt (/etc/libvirt/libvirtd.conf)
# 5. Ativar autostart da rede default (virbr0) diretamente no sistema de arquivos
# 6. Habilitar os daemons do libvirt no systemd
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[03-VIRT]${NC} $1"; }
log_success() { echo -e "${GREEN}[03-VIRT:OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[03-VIRT:AVISO]${NC} $1"; }
log_err()     { echo -e "${RED}[03-VIRT:ERRO]${NC} $1" >&2; }

TARGET_USER="${TARGET_USER:-kayran}"

# -----------------------------------------------------------------------------
# 1. Instalação de Pacotes da Stack de Virtualização
# -----------------------------------------------------------------------------
log_info "Instalando QEMU, Libvirt, OVMF e utilitários de rede..."

VIRT_PACKAGES=(
    qemu-desktop       # Emulador e integração KVM completa
    qemu-img           # Manipulação de formatos de disco (qcow2, raw)
    libvirt            # Daemon de gerenciamento de virtualização
    virt-install       # Criação de VMs via linha de comando
    edk2-ovmf          # Firmware UEFI x86_64 para VMs modernas
    dnsmasq            # Servidor DHCP/DNS local para a bridge virtual
    iptables-nft       # Regras de NAT e firewall para tráfego das VMs
    bridge-utils       # Utilitários de manipulação de interfaces bridge
    dmidecode          # Leitura de tabelas DMI/SMBIOS dentro das VMs
)

pacman -S --noconfirm --needed "${VIRT_PACKAGES[@]}"
log_success "Pacotes de virtualização instalados com êxito."

# -----------------------------------------------------------------------------
# 2. Permissões de Usuário e Grupos do Hipervisor
# -----------------------------------------------------------------------------
log_info "Adicionando ${TARGET_USER} aos grupos de virtualização (kvm, libvirt)..."

# Garante que os grupos existam antes de associar o usuário
groupadd -f kvm
groupadd -f libvirt

usermod -aG kvm,libvirt "${TARGET_USER}"
log_success "Usuário ${TARGET_USER} associado aos grupos kvm e libvirt."

# -----------------------------------------------------------------------------
# 3. Otimização do Módulo de Rede KVM (vhost-net)
# -----------------------------------------------------------------------------
log_info "Configurando carregamento do módulo vhost_net no boot..."

# vhost_net move a emulação de camada de rede do espaço de usuário para o kernel,
# reduzindo latência e overhead de CPU em tráfego de rede pesado nas VMs
cat <<EOF > /etc/modules-load.d/vhost-net.conf
vhost_net
EOF
log_success "Módulo vhost_net registrado em /etc/modules-load.d/."

# -----------------------------------------------------------------------------
# 4. Configuração dos Sockets de Acesso do Libvirt
# -----------------------------------------------------------------------------
log_info "Ajustando políticas de socket UNIX em /etc/libvirt/libvirtd.conf..."

LIBVIRTD_CONF="/etc/libvirt/libvirtd.conf"

if [[ -f "${LIBVIRTD_CONF}" ]]; then
    # Define o grupo de acesso dos sockets para 'libvirt'
    sed -i 's/^#*unix_sock_group = .*/unix_sock_group = "libvirt"/' "${LIBVIRTD_CONF}"
    # Define leitura e escrita restritas aos membros do grupo libvirt (0770)
    sed -i 's/^#*unix_sock_rw_perm = .*/unix_sock_rw_perm = "0770"/' "${LIBVIRTD_CONF}"
    # Habilita autenticação baseada em sockets locais do sistema
    sed -i 's/^#*auth_unix_rw = .*/auth_unix_rw = "none"/' "${LIBVIRTD_CONF}"
fi
log_success "Políticas de permissão do socket do libvirt aplicadas."

# -----------------------------------------------------------------------------
# 5. Configuração da Rede NAT virbr0 (Autostart sem depender do daemon ativo)
# -----------------------------------------------------------------------------
log_info "Configurando autostart da rede virtual default (virbr0)..."

NETWORKS_DIR="/etc/libvirt/qemu/networks"
AUTOSTART_DIR="${NETWORKS_DIR}/autostart"
DEFAULT_NET_SRC="${NETWORKS_DIR}/default.xml"
DEFAULT_NET_LINK="${AUTOSTART_DIR}/default.xml"

# Se o template padrão não tiver sido gerado pelo pacote, cria a definição padrão
if [[ ! -f "${DEFAULT_NET_SRC}" ]]; then
    mkdir -p "${NETWORKS_DIR}"
    cat <<'EOF' > "${DEFAULT_NET_SRC}"
<network>
  <name>default</name>
  <uuid>d56b4676-5776-47b2-84bc-80512f45e2a2</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:2d:4b:18'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
fi

# Cria o link simbólico de autostart
mkdir -p "${AUTOSTART_DIR}"
ln -sf "${DEFAULT_NET_SRC}" "${DEFAULT_NET_LINK}"
log_success "Link simbólico de autostart criado para /etc/libvirt/qemu/networks/default.xml."

# -----------------------------------------------------------------------------
# 6. Habilitação de Serviços no Systemd
# -----------------------------------------------------------------------------
log_info "Habilitando serviços do Libvirt no systemd..."

# Habilita o daemon tradicional ou os sockets modulares
systemctl enable libvirtd.service
systemctl enable virtlogd.service

log_success "Serviços libvirtd e virtlogd habilitados para inicialização no boot."
log_success "Módulo 03-virtualization.sh finalizado com sucesso."