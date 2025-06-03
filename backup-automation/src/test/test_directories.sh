#!/bin/bash

# Carrega as configurações
source ../../src/config/backup.conf

echo "=== TESTE DE ITERAÇÃO DOS DIRETÓRIOS ==="
echo ""

echo "📋 Diretórios configurados em backup.conf:"
for i in "${!SOURCE_DIRECTORIES[@]}"; do
    echo "[$((i+1))] ${SOURCE_DIRECTORIES[i]}"
done

echo ""
echo "🔍 Verificando existência dos diretórios:"

for dir in "${SOURCE_DIRECTORIES[@]}"; do
    if [ -e "$dir" ]; then
        if [ -d "$dir" ]; then
            # É um diretório
            file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
            dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "✅ DIRETÓRIO: $dir"
            echo "   ├─ Arquivos: $file_count"
            echo "   └─ Tamanho: $dir_size"
        elif [ -f "$dir" ]; then
            # É um arquivo
            file_size=$(ls -lh "$dir" 2>/dev/null | awk '{print $5}')
            echo "✅ ARQUIVO: $dir"
            echo "   └─ Tamanho: $file_size"
        fi
    else
        echo "❌ NÃO ENCONTRADO: $dir"
    fi
    echo ""
done

echo "📊 RESUMO:"
total_items=${#SOURCE_DIRECTORIES[@]}
existing_items=0

for dir in "${SOURCE_DIRECTORIES[@]}"; do
    if [ -e "$dir" ]; then
        existing_items=$((existing_items + 1))
    fi
done

echo "├─ Total configurado: $total_items"
echo "├─ Existentes: $existing_items"
echo "└─ Não encontrados: $((total_items - existing_items))"

if [ $existing_items -eq $total_items ]; then
    echo ""
    echo "🎉 Todos os diretórios/arquivos foram encontrados!"
else
    echo ""
    echo "⚠️  Alguns itens não foram encontrados - verifique a configuração"
fi