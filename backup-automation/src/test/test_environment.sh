#!/bin/bash

source ../config/backup.conf

echo "=== TESTE DE AMBIENTE E CONFIGURAÇÃO ==="
echo ""

# Verificar dependências
echo "🔧 VERIFICANDO DEPENDÊNCIAS:"
DEPS=("rsync" "tar" "find" "du" "launchctl")
for dep in "${DEPS[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        VERSION=$(command -v "$dep" | xargs ls -l 2>/dev/null || echo "N/A")
        echo "✅ $dep: $(which "$dep")"
    else
        echo "❌ $dep: NÃO ENCONTRADO"
    fi
done

echo ""
echo "📁 VERIFICANDO ESTRUTURA DE DIRETÓRIOS:"
REQUIRED_DIRS=("../config" "../../logs" "../../scripts")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir existe"
    else
        echo "❌ $dir não encontrado"
    fi
done

echo ""
echo "📄 VERIFICANDO ARQUIVOS ESSENCIAIS:"
REQUIRED_FILES=("../backup.sh" "../restore.sh" "../config/backup.conf" "../../scripts/install.sh")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        PERM=$(ls -l "$file" | cut -d' ' -f1)
        echo "✅ $file ($PERM)"
    else
        echo "❌ $file não encontrado"
    fi
done

echo ""
echo "🎯 VERIFICANDO CONFIGURAÇÕES:"
echo "├─ Destino: $BACKUP_DESTINATION"
echo "├─ Horário: $SCHEDULE"  
echo "├─ Retenção: $BACKUP_RETENTION_DAYS dias"
echo "└─ Total de fontes: ${#SOURCE_DIRECTORIES[@]}"

# Verificar destino
if [ -d "$BACKUP_DESTINATION" ]; then
    SPACE=$(df -h "$BACKUP_DESTINATION" | tail -1 | awk '{print $4}')
    echo "💾 Espaço disponível: $SPACE"
else
    echo "⚠️  Destino não montado: $BACKUP_DESTINATION"
fi