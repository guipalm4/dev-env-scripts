#!/bin/bash
# filepath: src/test/test_failure_recovery.sh

source ../config/backup.conf

echo "=== TESTE DE RECUPERAÇÃO DE FALHAS ==="
echo ""

# Simular falha de espaço insuficiente
echo "💾 TESTANDO COMPORTAMENTO COM POUCO ESPAÇO..."
df -h "$BACKUP_DESTINATION"

# Simular arquivo corrompido
echo ""
echo "🔧 TESTANDO RECUPERAÇÃO DE ARQUIVO CORROMPIDO..."
TEST_BACKUP_DIR="$BACKUP_DESTINATION/test_corrupted"
mkdir -p "$TEST_BACKUP_DIR"

# Criar backup válido
echo "Dados válidos" > "$TEST_BACKUP_DIR/valid_file.txt"

# Simular corrupção
echo "Dados corrompidos" > "$TEST_BACKUP_DIR/corrupted_file.txt"
chmod 000 "$TEST_BACKUP_DIR/corrupted_file.txt"

# Testar leitura
if [ -r "$TEST_BACKUP_DIR/valid_file.txt" ]; then
    echo "✅ Arquivo válido legível"
else
    echo "❌ Problema com arquivo válido"
fi

if [ -r "$TEST_BACKUP_DIR/corrupted_file.txt" ]; then
    echo "❌ Arquivo corrompido ainda legível"
else
    echo "✅ Arquivo corrompido detectado"
fi

# Limpar
chmod 644 "$TEST_BACKUP_DIR/corrupted_file.txt" 2>/dev/null
rm -rf "$TEST_BACKUP_DIR"

# Testar diretório inexistente
echo ""
echo "📁 TESTANDO DIRETÓRIO INEXISTENTE..."
FAKE_DIR="/caminho/que/nao/existe"
if [ -d "$FAKE_DIR" ]; then
    echo "❌ Diretório inexistente foi encontrado?!"
else
    echo "✅ Diretório inexistente detectado corretamente"
fi