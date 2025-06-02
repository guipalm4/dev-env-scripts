#!/bin/bash

# Define cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define o diretório do projeto
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST_FILE="$HOME/Library/LaunchAgents/com.backup.automation.plist"
LAUNCHD_DIR="$PROJECT_DIR/launchd"
LOGS_DIR="$PROJECT_DIR/logs"

echo -e "${BLUE}=== INSTALAÇÃO DO SISTEMA DE BACKUP AUTOMATIZADO ===${NC}"

# Verifica se rsync está instalado
if ! command -v rsync &> /dev/null; then
    echo -e "${RED}❌ ERRO: rsync não encontrado!${NC}"
    echo -e "${YELLOW}Instale com: brew install rsync${NC}"
    exit 1
fi

# Cria diretórios necessários
echo -e "${YELLOW}📁 Criando diretórios...${NC}"
mkdir -p "$LOGS_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

# Carrega configurações
source "$PROJECT_DIR/src/config/backup.conf"

# Extrai hora e minuto do SCHEDULE
IFS=':' read -r HOUR MINUTE <<< "$SCHEDULE"

echo -e "${YELLOW}📄 Criando arquivo LaunchAgent...${NC}"

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
        <string>/usr/local/bin:/usr/bin:/bin</string>
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
chmod +x "$PROJECT_DIR/src/backup.sh"
chmod +x "$PROJECT_DIR/src/restore.sh"

# Descarrega serviço anterior (se existir)
echo -e "${YELLOW}🔄 Removendo serviço anterior...${NC}"
launchctl bootout gui/$(id -u)/com.backup.automation 2>/dev/null || true

# Carrega o novo serviço
echo -e "${YELLOW}🚀 Carregando serviço...${NC}"
if launchctl bootstrap gui/$(id -u) "$PLIST_FILE"; then
    echo -e "${GREEN}✅ Serviço carregado com sucesso${NC}"
else
    echo -e "${RED}❌ Erro ao carregar serviço${NC}"
    echo -e "${YELLOW}Tentando método alternativo...${NC}"
    
    # Método alternativo
    if launchctl load "$PLIST_FILE"; then
        echo -e "${GREEN}✅ Serviço carregado (método alternativo)${NC}"
    else
        echo -e "${RED}❌ Falha ao carregar serviço${NC}"
        exit 1
    fi
fi

# Verifica se foi carregado
echo -e "${YELLOW}🔍 Verificando status do serviço...${NC}"
if launchctl list | grep -q com.backup.automation; then
    echo -e "${GREEN}✅ Serviço ativo e funcionando${NC}"
    
    # Mostra informações do serviço
    echo -e "\n${BLUE}ℹ️  Informações do serviço:${NC}"
    launchctl list com.backup.automation
else
    echo -e "${RED}❌ Serviço não está ativo${NC}"
    exit 1
fi

# Verifica diretório de destino
echo -e "\n${YELLOW}📁 Verificando diretório de destino...${NC}"
if [ -d "$BACKUP_DESTINATION" ]; then
    echo -e "${GREEN}✅ Diretório de destino encontrado: $BACKUP_DESTINATION${NC}"
else
    echo -e "${YELLOW}⚠️  Criando diretório de destino: $BACKUP_DESTINATION${NC}"
    mkdir -p "$BACKUP_DESTINATION"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Diretório criado com sucesso${NC}"
    else
        echo -e "${RED}❌ Erro ao criar diretório de destino${NC}"
    fi
fi

# Teste opcional
echo -e "\n${YELLOW}🧪 Deseja executar um teste de backup agora? (s/N):${NC}"
read -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${BLUE}🚀 Executando teste de backup...${NC}"
    "$PROJECT_DIR/src/backup.sh" incremental
fi

echo -e "\n${GREEN}🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "\n${BLUE}📋 Resumo da configuração:${NC}"
echo -e "${YELLOW}├─${NC} Horário de execução: $SCHEDULE"
echo -e "${YELLOW}├─${NC} Destino: $BACKUP_DESTINATION"
echo -e "${YELLOW}├─${NC} Retenção: $BACKUP_RETENTION_DAYS dias"
echo -e "${YELLOW}└─${NC} Logs: $LOGS_DIR"

echo -e "\n${BLUE}🔧 Comandos úteis:${NC}"
echo -e "${YELLOW}├─${NC} Verificar status: launchctl list com.backup.automation"
echo -e "${YELLOW}├─${NC} Executar agora: launchctl start com.backup.automation"
echo -e "${YELLOW}├─${NC} Ver logs: tail -f $LOGS_DIR/launchd.log"
echo -e "${YELLOW}└─${NC} Restaurar: $PROJECT_DIR/src/restore.sh"

echo -e "\n${GREEN}✨ Sistema pronto para uso!${NC}"