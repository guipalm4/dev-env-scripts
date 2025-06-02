# Sistema de Backup Automatizado para macOS

Sistema de backup inteligente e eficiente, otimizado para macOS, com suporte a backups incrementais e completos.

## 🌟 Características

- ⚡ **Backup Incremental**: Só copia arquivos modificados (economia de espaço e tempo)
- 📦 **Backup Completo**: Arquivo TAR compactado único para portabilidade
- 🕐 **Execução Automática**: Agendamento via LaunchAgent do macOS
- 📊 **Estatísticas Detalhadas**: Relatórios completos de cada execução
- 🔄 **Restauração Flexível**: Scripts dedicados para recuperação
- 🧹 **Limpeza Automática**: Remove backups antigos automaticamente
- 📝 **Logs Detalhados**: Rastreamento completo de todas as operações

## 📁 Estrutura do Projeto

```
backup-automation/
├── src/
│   ├── backup.sh              # Script principal de backup
│   ├── restore.sh             # Script de restauração
│   └── config/
│       └── backup.conf        # Arquivo de configuração
├── logs/                      # Logs do sistema
├── scripts/
│   ├── install.sh            # Script de instalação
│   └── uninstall.sh          # Script de desinstalação
├── launchd/
│   └── com.backup.automation.plist  # Configuração do LaunchAgent
└── README.md
```

## 🚀 Instalação Rápida

### 1. Clone/Baixe o projeto

```bash
cd ~/Dev/Scripts
git clone <repository-url> backup-automation
cd backup-automation
```

### 2. Configure os diretórios de backup

Edite o arquivo `src/config/backup.conf`:

```bash
# Diretórios a serem copiados
SOURCE_DIRECTORIES=(
    "$HOME/Música"
    "$HOME/Documents"
    "$HOME/.ssh"
    "$HOME/.aws"
    "$HOME/.zshrc"
    "$HOME/Pictures"
)

# Destino do backup
BACKUP_DESTINATION="/Volumes/Backups/MBook-Pro"

# Horário de execução (formato HH:MM)
SCHEDULE="20:00"

# Retenção de backups (em dias)
BACKUP_RETENTION_DAYS=14
```

### 3. Execute a instalação

```bash
./scripts/install.sh
```

O script de instalação irá:

- Verificar dependências (rsync)
- Criar diretórios necessários
- Configurar permissões
- Instalar o LaunchAgent para execução automática
- Executar um teste de backup

## 📖 Uso

### Backup Manual

#### Backup Incremental (Recomendado)

```bash
./src/backup.sh
# ou
./src/backup.sh incremental
```

**Vantagens do Backup Incremental:**

- 🚀 Extremamente rápido após o primeiro backup
- 💾 Economia de espaço com hard links
- 📈 Mantém histórico de versões
- 🔍 Fácil navegação pelos arquivos

**Exemplo de Eficiência:**

- **Dia 1**: 30GB de dados → Copia 30GB
- **Dia 2**: 3 arquivos modificados + 20MB novos → Copia apenas ~20MB
- **Economia**: 99.9% menos dados transferidos!

#### Backup Completo

```bash
./src/backup.sh full
```

Cria um arquivo `.tar.gz` único com todos os diretórios.

#### Limpeza de Backups Antigos

```bash
./src/backup.sh cleanup
```

### Restauração

#### Menu Interativo

```bash
./src/restore.sh
```

#### Linha de Comando

```bash
# Listar backups disponíveis
./src/restore.sh list-inc        # Backups incrementais
./src/restore.sh list-full       # Backups completos

# Restaurar backups
./src/restore.sh restore-inc /path/to/backup_dir [destino]
./src/restore.sh restore-full /path/to/backup.tar.gz [destino]
```

## ⚙️ Configuração Avançada

### Modificar Horário de Execução

1. Edite `src/config/backup.conf`:

```bash
SCHEDULE="02:30"  # 02:30 AM
```

2. Reinstale o serviço:

```bash
./scripts/uninstall.sh
./scripts/install.sh
```

### Adicionar/Remover Diretórios

Edite o array `SOURCE_DIRECTORIES` em `src/config/backup.conf`:

```bash
SOURCE_DIRECTORIES=(
    "$HOME/Documents"
    "$HOME/Pictures"
    "$HOME/Movies"           # Novo
    "$HOME/.config"          # Novo
    "$HOME/Development"      # Novo
)
```

### Alterar Retenção de Backups

```bash
BACKUP_RETENTION_DAYS=30  # Manter por 30 dias
```

## 📊 Monitoramento

### Logs do Sistema

```bash
# Logs principais
tail -f logs/backup_$(date +%Y-%m-%d).log

# Logs de restauração
tail -f logs/restore_$(date +%Y-%m-%d).log

# Logs do LaunchAgent
tail -f logs/launchd.log
tail -f logs/launchd_error.log

# Estatísticas de backup
cat logs/backup_stats_$(date +%Y-%m-%d).txt
```

### Verificar Status do Serviço

```bash
# Verificar se está carregado
launchctl list | grep backup

# Ver próxima execução
launchctl list com.backup.automation

# Forçar execução imediata
launchctl start com.backup.automation
```

### Estrutura de Backups

#### Backup Incremental

```
/Volumes/Backups/MBook-Pro/
├── backups/
│   ├── backup_20250602_140000/
│   │   ├── Documents/
│   │   ├── Pictures/
│   │   └── ...
│   ├── backup_20250603_140000/
│   │   ├── Documents/     # Hard links para arquivos não modificados
│   │   ├── Pictures/      # Apenas arquivos novos/modificados
│   │   └── ...
│   └── latest -> backup_20250603_140000/  # Link para o mais recente
```

#### Backup Completo

```
/Volumes/Backups/MBook-Pro/
├── backup_completo_20250602_140000.tar.gz
├── backup_manifest_20250602_140000.txt
└── ...
```

## 🛠️ Solução de Problemas

### Erro: Diretório de destino não existe

```bash
# Verifique se o volume está montado
ls /Volumes/

# Crie o diretório manualmente
mkdir -p "/Volumes/Backups/MBook-Pro"
```

### Erro: Permissão negada

```bash
# Verifique permissões dos scripts
chmod +x src/backup.sh src/restore.sh

# Verifique permissões do destino
ls -la "/Volumes/Backups/"
```

### Backup não executa automaticamente

```bash
# Verifique se o LaunchAgent está carregado
launchctl list | grep backup

# Reinstale o serviço
./scripts/uninstall.sh
./scripts/install.sh

# Verifique logs de erro
cat logs/launchd_error.log
```

### rsync não encontrado

```bash
# Instale via Homebrew
brew install rsync

# Ou baixe do site oficial
# https://rsync.samba.org/
```

## 🔧 Comandos Úteis

### Backup

```bash
# Backup incremental padrão
./src/backup.sh

# Backup completo
./src/backup.sh full

# Apenas limpeza
./src/backup.sh cleanup

# Ver ajuda
./src/backup.sh --help
```

### Serviço

```bash
# Parar serviço
launchctl unload ~/Library/LaunchAgents/com.backup.automation.plist

# Iniciar serviço
launchctl load ~/Library/LaunchAgents/com.backup.automation.plist

# Executar agora
launchctl start com.backup.automation
```

### Monitoramento

```bash
# Ver tamanho dos backups
du -sh /Volumes/Backups/MBook-Pro/*

# Contar arquivos por backup
find /Volumes/Backups/MBook-Pro/backups/*/Documents -type f | wc -l

# Ver estatísticas do último backup
cat logs/backup_stats_$(date +%Y-%m-%d).txt
```

## 📋 Melhores Práticas

### 1. **Teste Regularmente**

```bash
# Execute backup manual mensalmente
./src/backup.sh incremental

# Teste restauração em diretório temporário
./src/restore.sh restore-inc backup_dir /tmp/test_restore
```

### 2. **Monitor de Espaço**

```bash
# Verifique espaço livre no destino
df -h /Volumes/Backups/

# Configure alertas se necessário
```

### 3. **Backup do Sistema de Backup**

- Faça backup dos scripts de backup
- Documente suas configurações personalizadas
- Mantenha cópias dos logs importantes

### 4. **Segurança**

- Mantenha o volume de backup criptografado
- Configure permissões adequadas
- Considere backup offsite para dados críticos

## 🗑️ Desinstalação

```bash
./scripts/uninstall.sh
```

O script oferecerá opções para:

- Remover o LaunchAgent
- Manter ou excluir backups existentes
- Manter ou excluir logs

## 📞 Suporte

### Logs de Debug

```bash
# Executar backup com debug
bash -x ./src/backup.sh incremental

# Verificar configuração
source src/config/backup.conf && echo "Destino: $BACKUP_DESTINATION"
```

### Informações do Sistema

```bash
# Versão do macOS
sw_vers

# Espaço em disco
df -h

# Versão do rsync
rsync --version
```

## 📄 Licença

Este projeto é fornecido "como está" sem garantias. Use por sua conta e risco.

---

**Sistema de Backup Automatizado** - Feito para macOS com ❤️
