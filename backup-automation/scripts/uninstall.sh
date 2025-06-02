#!/bin/bash

# Script de desinstalação do sistema de backup automatizado

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLIST_DEST="$HOME/Library/LaunchAgents/com.backup.automation.plist"

echo "=== Desinstalação do Sistema de Backup Automatizado ==="
echo ""

# Para e remove o LaunchAgent
if [ -f "$PLIST_DEST" ]; then
    echo "Parando e removendo serviço automatizado..."
    launchctl unload "$PLIST_DEST" 2>/dev/null
    rm "$PLIST_DEST"
    echo "✅ Serviço removido"
else
    echo "ℹ️  Serviço não estava instalado"
fi

# Pergunta sobre remoção dos backups
echo ""
read -p "Deseja remover todos os backups existentes? (s/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    source "$PROJECT_DIR/src/config/backup.conf"
    if [ -d "$BACKUP_DESTINATION" ]; then
        echo "⚠️  ATENÇÃO: Isto irá remover TODOS os backups em:"
        echo "   $BACKUP_DESTINATION"
        echo ""
        read -p "Tem certeza? Digite 'CONFIRMAR' para prosseguir: " confirmation
        
        if [ "$confirmation" = "CONFIRMAR" ]; then
            rm -rf "$BACKUP_DESTINATION"
            echo "✅ Backups removidos"
        else
            echo "ℹ️  Backups mantidos"
        fi
    fi
fi

# Pergunta sobre remoção dos logs
echo ""
read -p "Deseja remover os logs? (s/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    rm -rf "$PROJECT_DIR/logs"/*
    echo "✅ Logs removidos"
fi

echo ""
echo "=== DESINSTALAÇÃO CONCLUÍDA ==="
echo ""
echo "O sistema de backup foi removido."
echo "Os scripts ainda estão disponíveis em: $PROJECT_DIR"
echo ""
echo "Para reinstalar: $PROJECT_DIR/scripts/install.sh"