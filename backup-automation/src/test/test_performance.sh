#!/bin/bash
# filepath: src/test/test_performance.sh

source ../config/backup.conf

echo "=== TESTE DE PERFORMANCE ==="
echo ""

# Criar arquivos de teste
TEST_DIR="/tmp/backup_performance_test"
mkdir -p "$TEST_DIR"

echo "📊 CRIANDO DADOS DE TESTE..."

# Arquivos pequenos (muitos)
echo "Criando 1000 arquivos pequenos..."
for i in {1..100}; do
    echo "Arquivo de teste $i - $(date)" > "$TEST_DIR/small_$i.txt"
done

# Arquivos médios
echo "Criando arquivos médios..."
for i in {1..10}; do
    dd if=/dev/zero of="$TEST_DIR/medium_$i.dat" bs=1024 count=1024 2>/dev/null
done

# Arquivo grande
echo "Criando arquivo grande..."
dd if=/dev/zero of="$TEST_DIR/large_file.dat" bs=1024 count=10240 2>/dev/null

echo ""
echo "🏃‍♂️ TESTANDO PERFORMANCE DE BACKUP..."

# Backup inicial
START_TIME=$(date +%s)
rsync -av "$TEST_DIR/" "$BACKUP_DESTINATION/test_performance/" >/dev/null 2>&1
INITIAL_TIME=$(($(date +%s) - START_TIME))

echo "├─ Backup inicial: ${INITIAL_TIME}s"

# Modificar alguns arquivos
echo "Modificando arquivos..."
for i in {1..5}; do
    echo "Arquivo modificado $(date)" >> "$TEST_DIR/small_$i.txt"
done

# Backup incremental
START_TIME=$(date +%s)
rsync -av --link-dest="$BACKUP_DESTINATION/test_performance" "$TEST_DIR/" "$BACKUP_DESTINATION/test_performance_inc/" >/dev/null 2>&1
INCREMENTAL_TIME=$(($(date +%s) - START_TIME))

echo "├─ Backup incremental: ${INCREMENTAL_TIME}s"

# Calcular eficiência
if [ $INITIAL_TIME -gt 0 ]; then
    EFFICIENCY=$((100 - (INCREMENTAL_TIME * 100 / INITIAL_TIME)))
    echo "└─ Eficiência incremental: ${EFFICIENCY}%"
fi

# Limpeza
rm -rf "$TEST_DIR"
rm -rf "$BACKUP_DESTINATION/test_performance"*

echo ""
echo "📈 TESTE DE CARGA DE DIRETÓRIOS:"
for dir in "${SOURCE_DIRECTORIES[@]}"; do
    if [ -e "$dir" ]; then
        if [ -d "$dir" ]; then
            FILE_COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
            echo "├─ $dir: $FILE_COUNT arquivos"
        else
            echo "├─ $dir: arquivo individual"
        fi
    fi
done