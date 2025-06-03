#!/bin/bash

echo "🧪 SUÍTE COMPLETA DE TESTES DO SISTEMA DE BACKUP"
echo "================================================"
echo ""

# Lista de testes
TESTS=(
    "test_environment.sh"
    "test_directories.sh" 
    "test_performance.sh"
    "test_integrity.sh"
    "test_failure_recovery.sh"
    "test_restore_complete.sh"
    "test_automation.sh"
)

PASSED=0
FAILED=0
TOTAL=${#TESTS[@]}

# Executar cada teste
for test_file in "${TESTS[@]}"; do
    echo "🔄 Executando: $test_file"
    echo "----------------------------------------"
    
    if [ -f "$test_file" ]; then
        chmod +x "$test_file"
        if ./"$test_file"; then
            echo "✅ $test_file: PASSOU"
            PASSED=$((PASSED + 1))
        else
            echo "❌ $test_file: FALHOU"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "❌ $test_file: ARQUIVO NÃO ENCONTRADO"
        FAILED=$((FAILED + 1))
    fi
    
    echo ""
    echo "========================================"
    echo ""
done

# Relatório final
echo "📊 RELATÓRIO FINAL DOS TESTES"
echo "=============================="
echo "Total de testes: $TOTAL"
echo "Passou: $PASSED"
echo "Falhou: $FAILED"
echo "Taxa de sucesso: $(( PASSED * 100 / TOTAL ))%"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "🎉 TODOS OS TESTES PASSARAM!"
    echo "Sistema pronto para produção."
else
    echo ""
    echo "⚠️  ALGUNS TESTES FALHARAM"
    echo "Revise os problemas antes de usar em produção."
fi