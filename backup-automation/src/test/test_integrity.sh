#!/bin/bash

source ../config/backup.conf

echo "=== TESTE DE INTEGRIDADE DE DADOS ==="
echo ""

# Criar arquivo de teste com checksum conhecido
TEST_FILE="/tmp/integrity_test.txt"
echo "Teste de integridade $(date)" > "$TEST_FILE"
ORIGINAL_MD5=$(md5 -q "$TEST_FILE")

echo "🔒 TESTANDO INTEGRIDADE..."
echo "├─ Arquivo original: $TEST_FILE"
echo "├─ MD5 original: $ORIGINAL_MD5"

# Executar backup do arquivo de teste
echo "├─ Executando backup..."
mkdir -p "$BACKUP_DESTINATION/integrity_test"
cp "$TEST_FILE" "$BACKUP_DESTINATION/integrity_test/"

# Verificar integridade no backup
BACKUP_MD5=$(md5 -q "$BACKUP_DESTINATION/integrity_test/$(basename "$TEST_FILE")")
echo "├─ MD5 do backup: $BACKUP_MD5"

if [ "$ORIGINAL_MD5" = "$BACKUP_MD5" ]; then
    echo "✅ Integridade PRESERVADA"
else
    echo "❌ Integridade COMPROMETIDA"
fi

# Teste com arquivo binário
echo ""
echo "🎯 TESTANDO ARQUIVO BINÁRIO..."
dd if=/dev/urandom of="/tmp/binary_test.bin" bs=1024 count=10 2>/dev/null
BINARY_MD5=$(md5 -q "/tmp/binary_test.bin")

cp "/tmp/binary_test.bin" "$BACKUP_DESTINATION/integrity_test/"
BACKUP_BINARY_MD5=$(md5 -q "$BACKUP_DESTINATION/integrity_test/binary_test.bin")

if [ "$BINARY_MD5" = "$BACKUP_BINARY_MD5" ]; then
    echo "✅ Arquivo binário íntegro"
else
    echo "❌ Arquivo binário corrompido"
fi

# Limpeza
rm -f "$TEST_FILE" "/tmp/binary_test.bin"
rm -rf "$BACKUP_DESTINATION/integrity_test"