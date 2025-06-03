#!/bin/bash
# filepath: src/test/test_automation.sh

echo "=== TESTE DE AUTOMAÇÃO E AGENDAMENTO ==="
echo ""

# Verificar LaunchAgent
echo "🤖 VERIFICANDO LAUNCHAGENT..."
PLIST_FILE="$HOME/Library/LaunchAgents/com.backup.automation.plist"

if [ -f "$PLIST_FILE" ]; then
    echo "✅ Arquivo plist existe"
    
    # Verificar sintaxe
    if plutil -lint "$PLIST_FILE" >/dev/null 2>&1; then
        echo "✅ Sintaxe do plist válida"
    else
        echo "❌ Sintaxe do plist inválida"
    fi
    
    # Verificar se está carregado
    if launchctl list | grep -q com.backup.automation; then
        echo "✅ Serviço carregado"
        
        # Obter informações
        STATUS=$(launchctl list com.backup.automation)
        echo "📊 Status do serviço:"
        echo "$STATUS" | grep -E "(PID|LastExitStatus|Label)"
    else
        echo "❌ Serviço não carregado"
    fi
else
    echo "❌ Arquivo plist não encontrado"
fi

# Testar execução manual
echo ""
echo "🧪 TESTANDO EXECUÇÃO MANUAL..."
if launchctl start com.backup.automation 2>/dev/null; then
    echo "✅ Comando de start executado"
    sleep 5
    
    # Verificar logs
    if [ -f "../../logs/launchd.log" ]; then
        echo "✅ Log criado"
        echo "Últimas 3 linhas do log:"
        tail -3 "../../logs/launchd.log"
    else
        echo "⚠️  Log não encontrado"
    fi
else
    echo "❌ Falha ao executar comando start"
fi

# Verificar próxima execução
echo ""
echo "⏰ VERIFICANDO AGENDAMENTO..."
SCHEDULE_INFO=$(launchctl print gui/$(id -u)/com.backup.automation 2>/dev/null | grep -A5 "start calendar interval\|StartCalendarInterval")
if [ -n "$SCHEDULE_INFO" ]; then
    echo "✅ Agendamento configurado"
else
    echo "⚠️  Informações de agendamento não encontradas"
fi