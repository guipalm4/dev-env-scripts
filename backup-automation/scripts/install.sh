#!/bin/bash
# filepath: scripts/install.sh

# Define cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define o diretório do projeto
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST_FILE="$HOME/Library/LaunchAgents/com.backup.automation.plist"
LOGS_DIR="$PROJECT_DIR/logs"

echo -e "${BLUE}=== INSTALAÇÃO DO SISTEMA DE BACKUP AUTOMATIZADO ===${NC}"

# Verifica se rsync está instalado
if ! command -v rsync &> /dev/null; then
    echo -e "${RED}❌ ERRO: rsync não encontrado!${NC}"
    echo -e "${YELLOW}Instale com: brew install rsync${NC}"
    exit 1
fi

# Verifica se diskutil está disponível (macOS)
if ! command -v diskutil &> /dev/null; then
    echo -e "${YELLOW}⚠️  AVISO: diskutil não encontrado - funcionalidade de desmontagem pode não funcionar${NC}"
fi

# Cria diretórios necessários
echo -e "${YELLOW}📁 Criando diretórios...${NC}"
mkdir -p "$LOGS_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

# Carrega configurações
if [ ! -f "$PROJECT_DIR/src/config/backup.conf" ]; then
    echo -e "${RED}❌ ERRO: Arquivo de configuração não encontrado!${NC}"
    echo -e "${YELLOW}Esperado: $PROJECT_DIR/src/config/backup.conf${NC}"
    exit 1
fi

source "$PROJECT_DIR/src/config/backup.conf"

# Verifica se o script principal existe
if [ ! -f "$PROJECT_DIR/src/backup.sh" ]; then
    echo -e "${RED}❌ ERRO: Script backup.sh não encontrado!${NC}"
    exit 1
fi

# Torna o script executável
chmod +x "$PROJECT_DIR/src/backup.sh"
chmod +x "$PROJECT_DIR/src/restore.sh" 2>/dev/null

# Extrai hora e minuto do SCHEDULE
IFS=':' read -r HOUR MINUTE <<< "$SCHEDULE"

# Valida formato do horário
if ! [[ "$HOUR" =~ ^[0-9]{1,2}$ ]] || ! [[ "$MINUTE" =~ ^[0-9]{1,2}$ ]]; then
    echo -e "${RED}❌ ERRO: Formato de horário inválido: $SCHEDULE${NC}"
    echo -e "${YELLOW}Use formato HH:MM (ex: 09:00)${NC}"
    exit 1
fi

# Converte para inteiros
HOUR=$((10#$HOUR))
MINUTE=$((10#$MINUTE))

# Valida intervalos
if [ $HOUR -lt 0 ] || [ $HOUR -gt 23 ] || [ $MINUTE -lt 0 ] || [ $MINUTE -gt 59 ]; then
    echo -e "${RED}❌ ERRO: Horário fora do intervalo válido: $SCHEDULE${NC}"
    exit 1
fi

echo -e "${YELLOW}📄 Criando arquivo LaunchAgent...${NC}"

# Remove arquivo anterior se existir
[ -f "$PLIST_FILE" ] && rm -f "$PLIST_FILE"

# Cria o arquivo plist
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.backup.automation</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/src/backup.sh</string>
        <string>incremental</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$HOUR</integer>
        <key>Minute</key>
        <integer>$MINUTE</integer>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$LOGS_DIR/launchd.log</string>
    
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/launchd_error.log</string>
    
    <key>RunAtLoad</key>
    <false/>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
</dict>
</plist>
EOF

# Verifica a sintaxe do plist
echo -e "${YELLOW}🔍 Verificando sintaxe do arquivo plist...${NC}"
if plutil -lint "$PLIST_FILE" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Arquivo plist válido${NC}"
else
    echo -e "${RED}❌ ERRO: Arquivo plist inválido${NC}"
    plutil -lint "$PLIST_FILE"
    exit 1
fi

# Define permissões corretas
chmod 644 "$PLIST_FILE"

# Descarrega serviço anterior (se existir)
echo -e "${YELLOW}🔄 Removendo serviço anterior...${NC}"
launchctl bootout gui/$(id -u)/com.backup.automation 2>/dev/null || true

# Carrega o novo serviço
echo -e "${YELLOW}🚀 Carregando serviço...${NC}"
if launchctl bootstrap gui/$(id -u) "$PLIST_FILE" 2>/dev/null; then
    echo -e "${GREEN}✅ Serviço carregado com sucesso${NC}"
elif launchctl load "$PLIST_FILE" 2>/dev/null; then
    echo -e "${GREEN}✅ Serviço carregado (método alternativo)${NC}"
else
    echo -e "${RED}❌ Erro ao carregar serviço${NC}"
    echo -e "${YELLOW}Verificando logs de erro...${NC}"
    
    # Mostrar erros se houver
    if [ -f "$LOGS_DIR/launchd_error.log" ]; then
        echo -e "${YELLOW}Últimas linhas do log de erro:${NC}"
        tail -5 "$LOGS_DIR/launchd_error.log"
    fi
    exit 1
fi

# Verifica se foi carregado
echo -e "${YELLOW}🔍 Verificando status do serviço...${NC}"
sleep 2
if launchctl list | grep -q com.backup.automation; then
    echo -e "${GREEN}✅ Serviço ativo e funcionando${NC}"
else
    echo -e "${RED}❌ Serviço não está ativo${NC}"
    exit 1
fi

# Verifica diretório de destino
echo -e "\n${YELLOW}📁 Verificando diretório de destino...${NC}"
if [ -d "$BACKUP_DESTINATION" ]; then
    echo -e "${GREEN}✅ Diretório de destino acessível: $BACKUP_DESTINATION${NC}"
    
    # Testa permissões
    if touch "$BACKUP_DESTINATION/.test_write" 2>/dev/null; then
        rm -f "$BACKUP_DESTINATION/.test_write"
        echo -e "${GREEN}✅ Permissões de escrita verificadas${NC}"
    else
        echo -e "${YELLOW}⚠️  AVISO: Sem permissões de escrita no destino${NC}"
        echo -e "${YELLOW}   O backup pode falhar. Verifique as permissões.${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Diretório de destino não acessível: $BACKUP_DESTINATION${NC}"
    if [[ "$BACKUP_DESTINATION" =~ ^/Volumes/ ]]; then
        echo -e "${YELLOW}   Certifique-se de que o volume externo está conectado.${NC}"
    fi
fi

# Teste opcional
echo -e "\n${YELLOW}🧪 Deseja executar um teste de backup agora? (s/N):${NC}"
read -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${BLUE}🚀 Executando teste de backup...${NC}"
    if "$PROJECT_DIR/src/backup.sh" incremental; then
        echo -e "${GREEN}✅ Teste de backup concluído com sucesso!${NC}"
    else
        echo -e "${RED}❌ Teste de backup falhou - verifique as configurações${NC}"
    fi
fi

echo -e "\n${GREEN}🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "\n${BLUE}📋 Resumo da configuração:${NC}"
echo -e "${YELLOW}├─${NC} Horário de execução: $SCHEDULE"
echo -e "${YELLOW}├─${NC} Destino: $BACKUP_DESTINATION"
echo -e "${YELLOW}├─${NC} Retenção: $BACKUP_RETENTION_DAYS dias"
echo -e "${YELLOW}├─${NC} Auto-desmontagem: ${AUTO_UNMOUNT:-false}"
echo -e "${YELLOW}└─${NC} Logs: $LOGS_DIR"

echo -e "\n${BLUE}🔧 Comandos úteis:${NC}"
echo -e "${YELLOW}├─${NC} Verificar status: launchctl list com.backup.automation"
echo -e "${YELLOW}├─${NC} Executar agora: launchctl start com.backup.automation"
echo -e "${YELLOW}├─${NC} Ver logs: tail -f $LOGS_DIR/launchd.log"
echo -e "${YELLOW}├─${NC} Ver erros: tail -f $LOGS_DIR/launchd_error.log"
echo -e "${YELLOW}└─${NC} Restaurar: $PROJECT_DIR/src/restore.sh"

echo -e "\n${GREEN}✨ Sistema pronto para uso!${NC}"
echo -e "${YELLOW}💡 Próximo backup agendado para: $SCHEDULE${NC}"