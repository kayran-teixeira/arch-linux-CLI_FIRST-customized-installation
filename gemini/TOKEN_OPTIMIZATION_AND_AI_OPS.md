# Otimização de Tokens e Operações de IA no Sistema CLI-First

Este documento define as diretrizes de engenharia de prompt, consulta de baixo overhead e economia de tokens para assistentes CLI de inteligência artificial (**Antigravity CLI - `agy`** e **Claude Code - `claude`**) ao administrar, monitorar e evoluir este sistema operacional.

---

## 1. O Problema do Desperdício de Tokens em Administração Linux

Agentes de IA frequentemente esgotam janelas de contexto e gastam milhares de tokens desnecessários ao executar comandos de auditoria que cospem saídas verbosas descontroladas no terminal (ex: `journalctl`, `dmesg`, `pacman -Qe`, `ps aux` ou dumps completos de arquivos de configuração).

### Regra de Ouro:
> **"Nunca traga para o contexto do modelo mais dados do que o necessário para tomar a próxima decisão determinística."**

---

## 2. Padrões de Consulta com Economia de Tokens (Token-Efficient CLI)

Ao executar inspeções de sistema, os agentes devem seguir rigorosamente os filtros abaixo:

| Tarefa | Comando Ingênuo (Desperdiça Tokens) | Comando Otimizado (Econômico) | Economia Média |
| :--- | :--- | :--- | :--- |
| **Status de Daemons** | `systemctl status docker` (dump de logs longos) | `systemctl is-active docker && systemctl is-enabled docker` | ~90% tokens |
| **Logs de Erro** | `journalctl -u docker` (milhares de linhas) | `journalctl -u docker -n 25 --no-pager -p err` | ~95% tokens |
| **Logs do Kernel** | `dmesg` ou `journalctl -k` | `journalctl -k -b -p 3 -n 20 --no-pager` | ~98% tokens |
| **Pacotes Instalados** | `pacman -Q` (lista 1.000+ pacotes) | `pacman -Q <pacote>` ou `pacman -Qs <keyword>` | ~99% tokens |
| **Uso de Armazenamento** | `df -h` e `mount` verbosos | `lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS` | ~80% tokens |
| **Processos em Execução** | `ps aux` (dump de centenas de PIDs) | `pgrep -l <nome>` ou `ps aux --sort=-%mem \| head -n 10` | ~85% tokens |
| **Snapshots Btrfs** | `btrfs subvolume list /` (árvore bruta) | `snapper -c root list \| tail -n 15` | ~75% tokens |
| **Regras de Firewall** | Inspecionar iptables/nftables bruto | `firewall-cmd --list-all` | ~90% tokens |

---

## 3. Integração com Recursos Nativos do Antigravity CLI (`agy`)

O **Antigravity CLI** possui capacidades arquiteturais mapeadas para economizar tokens e acelerar a resolução de problemas no sistema:

### 3.1. Compactação de Histórico (`/compact`)
* Quando uma sessão de depuração de sistema ou compilação de pacotes se estender, o agente deve sugerir ou acionar o comando `/compact`.
* Isso resume o histórico de comandos anteriores liberando espaço imediato na janela de contexto.

### 3.2. Delegação para Subagente Especializado (`research`)
* Para tarefas pesadas de exploração (ex: varredura em código-fonte de drivers AUR, documentação de APIs ou leitura de múltiplos arquivos extensos), **não polua o contexto principal**.
* Delegue a pesquisa para o subagente `research` (em sandbox somente-leitura), que retornará apenas o resumo sintetizado com os pontos de ação.

### 3.3. Uso da Colinha Local Offline (`tealdeer`)
* Em vez de pesquisar na web ou abrir `man pages` de centenas de linhas, o modelo pode ler diretamente as páginas curtas e sintetizadas criadas em `~/.local/share/tealdeer/pages/custom/` via `tldr <pagina>` (ex: `tldr arch-snapper`).

---

## 4. Edição Cirúrgica de Arquivos (Evitar Rewrites Completos)

Ao modificar arquivos de configuração e scripts do repositório:
1. **Preferir `edit_file` a `write_file` em arquivos existentes:** Não substitua um script de 200 linhas inteiro apenas para adicionar uma variável. Utilize substituições cirúrgicas com âncoras exatas de contexto.
2. **Leituras Segmentadas:** Ao inspecionar arquivos grandes, use `StartLine` e `EndLine` no `read_file` em vez de carregar arquivos inteiros para a memória do agente.

---

## 5. Skills de Consulta Sintética para Agentes

### Skill: `skill-quick-diagnose`
Permite à IA auditar a integridade global do sistema em uma única chamada compacta:

```bash
echo "=== SAÚDE DO SISTEMA ==="
echo "Boot: $(systemctl is-system-running)"
echo "Falhas: $(systemctl --failed --quiet && echo 'Nenhuma' || systemctl --failed --no-legend | wc -l)"
echo "Kernel: $(uname -r)"
echo "ZRAM: $(swapon --show | grep zram0 | awk '{print $1, $3, $4}')"
echo "Btrfs: $(btrfs filesystem usage / | grep 'Free (estimated)' | xargs)"
echo "Firewall: $(firewall-cmd --state 2>/dev/null || echo 'Inativo')"
echo "GPU: $(nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu --format=csv,noheader 2>/dev/null || echo 'GPU off')"
```
*(Saída total: ~8 linhas de texto = menos de 80 tokens, contra 3.000+ tokens de comandos individuais).*
