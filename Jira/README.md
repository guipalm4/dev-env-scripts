# Jira – Evidências de teste

`jira-evidencias.sh` publica evidências numa issue do Jira Cloud:

1. sobe as imagens de uma pasta como anexos da issue (pula as que já existem com o mesmo nome);
2. publica um comentário em **wiki markup** que mostra essas imagens inline.

## Pré-requisitos

- `zsh`, `curl` e `python3`
- Token de API do Jira: https://id.atlassian.com/manage-profile/security/api-tokens
- Variáveis de ambiente, ou um arquivo de secrets que as exporte:

```bash
export JIRA_API_TOKEN="..."
export JIRA_EMAIL="voce@empresa.com"
export JIRA_SITE="https://suaempresa.atlassian.net"
```

Se as variáveis não estiverem no ambiente, o script carrega `~/.config/zsh/secrets.zsh`. Para usar outro arquivo, defina `JIRA_SECRETS_FILE`.

## Uso

```bash
./jira-evidencias.sh [--dry-run] <ISSUE> <pasta-imagens> <comentario.txt>
```

- `--dry-run`: valida credenciais e issue, lista o que seria anexado e mostra o comentário. Não envia nada.
- Imagens aceitas: `png`, `jpg`, `jpeg` e `gif`. A ordem de envio é alfabética.

### Fluxo recomendado

```bash
mkdir -p ~/tmp/SOCC-1234/img
# 1. Copie as evidências com nomes legíveis e prefixo numérico (definem a ordem e o nome do anexo)
cp "Captura de Tela ... .png" ~/tmp/SOCC-1234/img/01-antes.png
cp "Captura de Tela ... .png" ~/tmp/SOCC-1234/img/02-depois.png

# 2. Escreva o comentário referenciando as imagens pelo nome
$EDITOR ~/tmp/SOCC-1234/comentario.txt

# 3. Confira e publique
./jira-evidencias.sh --dry-run SOCC-1234 ~/tmp/SOCC-1234/img ~/tmp/SOCC-1234/comentario.txt
./jira-evidencias.sh           SOCC-1234 ~/tmp/SOCC-1234/img ~/tmp/SOCC-1234/comentario.txt
```

## Modelo de comentário (wiki markup)

```text
h3. Teste integrado – SOCC-1234

*PR:* [#99|https://github.com/org/repo/pull/99]
*Perfil testado:* Fulano · *Ambiente:* DES

h4. Antes da correção
Descrição do problema.

!01-antes.png|width=900!

h4. Depois da correção
# Primeiro passo.
!02-depois.png|width=900!
# Segundo passo, com valor em {{monoespaçado}}.
!03-banco.png|width=900!
```

Sintaxe útil:

| Markup | Resultado |
|---|---|
| `h3.` / `h4.` | Títulos |
| `*texto*` | Negrito |
| `{{texto}}` | Monoespaçado |
| `[rótulo\|url]` | Link |
| `# item` | Lista numerada. A imagem na linha seguinte fica dentro do item e não quebra a numeração |
| `!arquivo.png\|width=900!` | Imagem anexada, exibida inline |
| `SOCC-1234` | Vira link para a issue automaticamente |

## Observações

- O comentário usa a API **v2** porque ela aceita wiki markup. A v3 exige ADF (JSON) e não referencia anexos pelo nome.
- O script não apaga nem edita nada. Para corrigir um comentário, edite-o ou apague-o na interface do Jira. Se um anexo precisar ser substituído, apague-o na issue antes de rodar o script de novo, já que anexos com o mesmo nome são pulados.
- As credenciais nunca são impressas.
