#!/bin/bash
# filepath: src/test/test_restore_complete.sh

source ../config/backup.conf

echo "=== TESTE COMPLETO DE RESTAURAÇÃO ==="
echo ""

# Criar dados de teste
TEST_SOURCE="/tmp/restore_test_source"
TEST_RESTORE="/tmp/restore_test_target"
TEST_BACKUP="$BACKUP_DESTINATION/test_restore_backup"

mkdir -p "$TEST_SOURCE"/{dir1,dir2,dir3}

# Criar estrutura de teste
echo "📁 CRIANDO ESTRUTURA DE TESTE..."
echo "Arquivo 1" > "$TEST_SOURCE/file1.txt"
echo "Arquivo 2" > "$TEST_SOURCE/dir1/file2.txt"
echo "Arquivo 3" > "$TEST_SOURCE/dir2/file3.txt"
echo "Arquivo especial" > "$TEST_SOURCE/.hidden_file"
ln -s "$TEST_SOURCE/file1.txt" "$TEST_SOURCE/link_to_file1"

echo "├─ Arquivos criados: $(find "$TEST_SOURCE" -type f | wc -l)"
echo "├─ Diretórios criados: $(find "$TEST_SOURCE" -type d | wc -l)"
echo "└─ Links criados: $(find "$TEST_SOURCE" -type l | wc -l)"

# Fazer backup
echo ""
echo "💾 EXECUTANDO BACKUP..."
rsync -av "$TEST_SOURCE/" "$TEST_BACKUP/" >/dev/null 2>&1
echo "✅ Backup concluído"

# Restaurar
echo ""
echo "🔄 TESTANDO RESTAURAÇÃO..."
mkdir -p "$TEST_RESTORE"
rsync -av "$TEST_BACKUP/" "$TEST_RESTORE/" >/dev/null 2>&1

# Verificar restauração
echo ""
echo "🔍 VERIFICANDO RESTAURAÇÃO..."

# Comparar arquivos
ORIGINAL_FILES=$(find "$TEST_SOURCE" -type f | wc -l)
RESTORED_FILES=$(find "$TEST_RESTORE" -type f | wc -l)

echo "├─ Arquivos originais: $ORIGINAL_FILES"
echo "├─ Arquivos restaurados: $RESTORED_FILES"

if [ "$ORIGINAL_FILES" -eq "$RESTORED_FILES" ]; then
    echo "✅ Contagem de arquivos correta"
else
    echo "❌ Contagem de arquivos diferente"
fi

# Verificar conteúdo
if diff -r "$TEST_SOURCE" "$TEST_RESTORE" >/dev/null 2>&1; then
    echo "✅ Conteúdo idêntico"
else
    echo "❌ Conteúdo divergente"
fi

# Verificar permissões
ORIGINAL_PERMS=$(find "$TEST_SOURCE" -type f -exec stat -f "%p" {} \; | sort)
RESTORED_PERMS=$(find "$TEST_RESTORE" -type f -exec stat -f "%p" {} \; | sort)

if [ "$ORIGINAL_PERMS" = "$RESTORED_PERMS" ]; then
    echo "✅ Permissões preservadas"
else
    echo "⚠️  Permissões podem ter mudado"
fi

# Limpeza
rm -rf "$TEST_SOURCE" "$TEST_RESTORE" "$TEST_BACKUP"