# Guia Definitivo de Arquitetura e Uso do Firewall (`firewalld`)

Este documento faz parte da documentação técnica e de contexto do projeto `arch-bootstrap` dentro do diretório `gemini/`. Ele foi projetado para servir como referência exaustiva para humanos e agentes autônomos de IA (**Antigravity CLI** e **Claude Code**) sobre como operar, auditar, proteger e diagnosticar a camada de rede do sistema.

---

## 1. Arquitetura do Firewalld no Linux

O `firewalld` é um daemon de segurança de espaço de usuário responsável pela gestão dinâmica e abstraída do subsistema de firewall do kernel Linux.

### 1.1. Backend Moderno: nftables
No Arch Linux moderno, o `firewalld` atua como camada de orquestração sobre o subsistema **nftables** (sucessor do antigo `iptables` / `ip6tables`). Suas principais vantagens técnicas incluem:
* **Operação Dinâmica sem Drop de Conexões:** Ao contrário dos scripts de firewall legados que precisavam zerar as tabelas do kernel para aplicar alterações, o Firewalld adiciona ou revoga regras cirurgicamente em tempo de execução sem derrubar sockets TCP/UDP já estabelecidos.
* **Isolamento de Zonas (Security Zones):** Separa o tráfego de acordo com o nível de confiança das interfaces de rede conectadas (ex: interface cabeada corporativa vs Wi-Fi público de cafeteria).
* **Suporte Completo a IPv4 e IPv6 Unificado:** Todas as regras, serviços e portas operam simultaneamente nas duas famílias de protocolos sem duplicidade de arquivos.

---

## 2. Conceito de Zonas de Rede (Network Zones)

Toda conexão ou pacote que entra na máquina é filtrado com base na **zona** à qual a interface de rede (ex: `wlan0`, `eth0`) ou o IP de origem pertence.

| Zona | Nível de Confiança | Comportamento Padrão de Entrada | Uso Recomendado |
| :--- | :--- | :--- | :--- |
| **`drop`** | Nulo (0%) | Descarta silenciosamente todos os pacotes sem enviar resposta ICMP (modo furtivo). | Redes públicas hostis, contenção de ataques. |
| **`block`** | Mínimo | Rejeita pacotes respondendo com mensagem ICMP *host-unreachable*. | Redes desconhecidas onde a rejeição explícita é permitida. |
| **`public`** | **Padrão (Default)** | Rejeita conexões de entrada não solicitadas. Apenas conexões de saída e serviços explicitamente autorizados são aceitos. | Estações de trabalho portáteis (nosso setup padrão). |
| **`external`** | Roteamento | Tráfego de entrada bloqueado com mascaramento NAT (IP Masquerading) ativado. | Gateways, roteadores ou compartilhamento de internet. |
| **`dmz`** | Intermediário | Zona desmilitarizada; apenas serviços públicos selecionados são acessíveis. | Servidores de teste expostos. |
| **`work`** | Alto | Maioria dos computadores da rede são considerados seguros. | Redes locais de escritório / ambiente profissional. |
| **`home`** | Alto | Confiança elevada em dispositivos da casa (facilita streaming/mDNS). | Redes domésticas privadas. |
| **`trusted`** | Máximo (100%) | Todas as conexões de rede de entrada são aceitas irrestritamente. | Interfaces de loopback ou bridges internas locais (ex: `docker0`, `virbr0`). |

---

## 3. Ciclo de Vida: Regras Runtime vs Regras Permanent

Uma das distinções mais importantes no Firewalld é a separação entre memória e disco:

1. **Modo Runtime (Em Memória):**
   * Comando executado **sem** a flag `--permanent`.
   * A regra entra em vigor imediatamente, porém é volátil: será apagada se o daemon reiniciar ou se for executado `firewall-cmd --reload`.
   * **Quando usar:** Testes rápidos de portas para desenvolvimento ou liberação emergencial temporária.
2. **Modo Permanente (No Disco):**
   * Comando executado **com** a flag `--permanent`.
   * A alteração é gravada no arquivo XML correspondente em `/etc/firewalld/zones/`.
   * **Atenção:** A regra permanente **não** entra em vigor imediatamente até que a tabela seja recarregada na memória via `sudo firewall-cmd --reload`.

> **Fluxo Canônico de Alteração Permanente:**
> ```bash
> sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
> sudo firewall-cmd --reload
> ```

---

## 4. Guia Prático de Operação via `firewall-cmd`

### 4.1. Diagnóstico e Inspeção de Estado
* **Verificar se o serviço está ativo:**
  ```bash
  sudo firewall-cmd --state
  # Retorna: running
  ```
* **Consultar qual interface está associada a qual zona:**
  ```bash
  sudo firewall-cmd --get-active-zones
  # Exemplo de saída:
  # public
  #   interfaces: wlan0 eth0
  ```
* **Listar toda a configuração da zona padrão ativa:**
  ```bash
  sudo firewall-cmd --list-all
  ```
* **Listar serviços pré-definidos disponíveis no sistema:**
  ```bash
  sudo firewall-cmd --get-services
  ```

---

### 4.2. Gestão de Serviços
O Firewalld possui definições XML prontas para centenas de protocolos conhecidos (incluindo portas TCP/UDP e módulos do kernel):

* **Liberar um serviço permanentemente (ex: SSH, Syncthing, KDE Connect):**
  ```bash
  sudo firewall-cmd --add-service=ssh --permanent
  sudo firewall-cmd --add-service=kdeconnect --permanent
  sudo firewall-cmd --reload
  ```
* **Revogar um serviço aberto anteriormente:**
  ```bash
  sudo firewall-cmd --remove-service=ssh --permanent
  sudo firewall-cmd --reload
  ```

---

### 4.3. Abertura e Fechamento de Portas Customizadas
* **Liberar porta TCP específica (ex: servidor Node.js/Vite na porta 5173 ou API Docker na 8000):**
  ```bash
  sudo firewall-cmd --add-port=5173/tcp --permanent
  sudo firewall-cmd --add-port=8000/tcp --permanent
  sudo firewall-cmd --reload
  ```
* **Liberar um intervalo de portas TCP ou UDP:**
  ```bash
  sudo firewall-cmd --add-port=3000-3005/tcp --permanent
  sudo firewall-cmd --reload
  ```
* **Liberar porta UDP (ex: servidor local de jogos ou streaming de áudio):**
  ```bash
  sudo firewall-cmd --add-port=19132/udp --permanent
  sudo firewall-cmd --reload
  ```
* **Fechar e revogar a porta:**
  ```bash
  sudo firewall-cmd --remove-port=5173/tcp --permanent
  sudo firewall-cmd --reload
  ```

---

### 4.4. Redirecionamento de Portas (Port Forwarding)
Útil para expor aplicações sem precisar conceder privilégios de root para escutar em portas baixas (< 1024):

* **Redirecionar tráfego recebido na porta 80 externa para a porta 8080 local:**
  ```bash
  sudo firewall-cmd --add-forward-port=port=80:proto=tcp:toport=8080 --permanent
  sudo firewall-cmd --reload
  ```

---

## 5. Regras Ricas (Rich Rules) para Controle Granular

As **Rich Rules** permitem criar regras condicionais complexas com restrição por IP de origem, limites de taxa (rate limit) e auditoria de logs.

### 5.1. Permitir Acesso Apenas a Partir de um IP ou Sub-rede Confiável
* Liberar a porta do SSH (22) **apenas** para o IP da sua estação interna:
  ```bash
  sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.1.50" service name="ssh" accept' --permanent
  sudo firewall-cmd --reload
  ```
* Liberar um banco de dados PostgreSQL (5432) apenas para a sub-rede dos containers:
  ```bash
  sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="172.18.0.0/16" port port="5432" protocol="tcp" accept' --permanent
  sudo firewall-cmd --reload
  ```

### 5.2. Bloqueio Imediato de IPs Agressivos (Blacklist)
* Bloquear e rejeitar todo o tráfego vindo de um IP hostil:
  ```bash
  sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="203.0.113.45" reject' --permanent
  sudo firewall-cmd --reload
  ```
* Descartar silenciosamente (drop) sem avisar o remetente:
  ```bash
  sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="203.0.113.45" drop' --permanent
  sudo firewall-cmd --reload
  ```

### 5.3. Rate Limiting e Auditoria de Ataques de Força Bruta
* Registrar e limitar tentativas de conexão ao SSH para no máximo 3 por minuto:
  ```bash
  sudo firewall-cmd --add-rich-rule='rule service name="ssh" log prefix="[FIREWALL_SSH_AUDIT] " level="notice" limit value="3/m" accept' --permanent
  sudo firewall-cmd --reload
  ```

---

## 6. O Dilema Crítico: Docker vs Firewalld

No ecossistema Linux, o relacionamento entre o daemon do Docker e o `firewalld` é uma das maiores causas de incidentes de segurança:

### 6.1. O Problema da Violação do Firewall pelo Docker
Por padrão, ao iniciar containers mapeando portas (ex: `docker run -p 8080:80 nginx`), o Docker injeta regras diretamente nas cadeias `PREROUTING` do `iptables` do kernel.
* **Consequência:** As regras do Docker **ignoram completamente** as políticas do Firewalld. Mesmo que a porta 8080 esteja fechada no `firewalld`, o Docker publica essa porta diretamente para o mundo externo (`0.0.0.0:8080`), expondo bancos de dados ou serviços internos para a internet.

### 6.2. Boas Práticas e Soluções Implementadas neste Setup

#### Solução A (Padrão de Ouro para Desenvolvimento e Produção):
Sempre amarre as portas publicadas explicitamente à interface de loopback (`127.0.0.1`), garantindo que apenas processos locais possam acessar:
```bash
# Maneira Segura:
docker run -d -p 127.0.0.1:8080:80 nginx
```
No `docker-compose.yml`:
```yaml
ports:
  - "127.0.0.1:8080:80"
  - "127.0.0.1:5432:5432"
```

#### Solução B (Isolamento da Interface Bridge do Docker):
Para que o Firewalld gerencie a comunicação interna entre o host e os containers sem interferir na conectividade externa:
* Adicionar a interface de bridge do Docker (`docker0`) à zona `trusted`:
  ```bash
  sudo firewall-cmd --zone=trusted --add-interface=docker0 --permanent
  sudo firewall-cmd --reload
  ```

---

## 7. Monitoramento, Logs e Solução de Problemas

### 7.1. Ativar Registro de Pacotes Bloqueados
Para descobrir por que uma aplicação ou jogo não consegue conectar:
* Ativar o log de pacotes descartados:
  ```bash
  sudo firewall-cmd --set-log-denied=all
  ```
* Acompanhar os drops em tempo real pelo journal:
  ```bash
  journalctl -k -f | grep -i "filter_drop"
  ```
* Desativar o log quando concluir o diagnóstico:
  ```bash
  sudo firewall-cmd --set-log-denied=off
  ```

### 7.2. Testar Conectividade Local de Portas
* Verificar se a porta está realmente escutando localmente:
  ```bash
  ss -tulpn | grep :8080
  ```
* Testar conexão através do terminal:
  ```bash
  nc -zv 127.0.0.1 8080
  curl -I http://127.0.0.1:8080
  ```

### 7.3. Desativação Temporária e Emergencial
Se você suspeitar que o firewall está impedindo uma comunicação crítica em rede de teste:
* **Parar o daemon temporariamente:**
  ```bash
  sudo systemctl stop firewalld.service
  ```
* **Reativar o daemon:**
  ```bash
  sudo systemctl start firewalld.service
  ```
