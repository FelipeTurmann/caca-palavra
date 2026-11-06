# Autoria dos catálogos

## Campanha 3 e APK Beta

Os 2.500 níveis e o léxico da nova campanha ficam em `catalog-v3/`. O app online
carrega a versão informada pela API. Rodadas salvas com a versão anterior
continuam com suas fichas, respostas e regras do Explorador.

```powershell
git clone --no-checkout https://github.com/LuceleneL/PortiLexicon-UD.git build/portilexicon-ud
curl.exe -fsSL https://raw.githubusercontent.com/LibreOffice/dictionaries/4f1df64b2e8e14751aa7c2205d170ca016071315/pt_BR/pt_BR.dic -o build/vero-pt_BR.dic
node tool/content/generate_levels.mjs --v3 build/portilexicon-ud tool/content/catalog-v3 build/vero-pt_BR.dic
dart tool/validate_catalog.dart --levels tool/content/catalog-v3/levels.json --lexicon tool/content/catalog-v3/lexicon_pt_br.json --report build/catalog-v3-validation.json
flutter build apk --release -t lib/main_catalog_preview.dart --android-project-arg=catalogPreview=true
```

O APK **Conecte palavras Beta** tem um identificador Android separado e usa
progresso local. Ele permite testar a campanha 3 enquanto o ambiente online usa
a versão 2.

- O gerador lê os dados do PortiLexicon-UD em uma revisão fixa diretamente do Git. A revisão, a atribuição e a finalidade constam no léxico gerado. O arquivo de licença do repositório acompanha a saída. O portal de dados indica a licença [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- As respostas partem da lista editorial com dicas próprias. São elegíveis substantivos e adjetivos com uso no singular e verbos no infinitivo. Uma forma verbal também pode entrar pelo uso independente revisado, como o adjetivo **ABERTO**.
- `clues_v3.tsv` contém as revisões que se aplicam apenas à campanha 3. O gerador registra a versão de cada frase revisada.
- O Explorador aceita as formas registradas de 3 a 6 letras que podem ser montadas em alguma rodada da campanha ou do diário usado na validação. As fichas ignoram acentos. Em colisões, a forma editorial tem prioridade e cada sequência vale uma descoberta.
- As entradas adicionais da referência fserb precisam corresponder a uma entrada minúscula do dicionário VERO. O gerador confere o SHA-256 da revisão de referência.
- A mesma resposta precisa ficar fora dos cinco níveis seguintes. Cada resposta tem teto de 45 usos na campanha e de 25 na mesma faixa de dificuldade. O relatório registra os limites observados.

## Campanha 2

`vocabulary.tsv` é a seleção explícita do projeto, com grafia, classe gramatical, familiaridade e frase própria. Entradas adicionais do protótipo são lidas da fixture `test/fixtures/lexicon_v1.json`, com revisão explícita das conjugações excluídas. `rejected.json` documenta as exclusões. Nenhuma palavra é admitida apenas por constar no corpus de referência.

## Reprodução

Executar na raiz do projeto com Node.js e Dart/Flutter já instalados:

```powershell
node tool/content/prepare_vocabulary.mjs
node tool/content/generate_levels.mjs
dart run tool/validate_catalog.dart
```

O gerador escreve os catálogos locais e `generation_report.json`. A ordem é determinística; não usa rede, relógio ou aleatoriedade de execução. A data-base do diário é preservada. O conteúdo carregado pelo app não depende do Node.js ou dos arquivos de autoria.

Para uma correção aditiva apenas de extras, como `NÃO` na versão 0.13.1+24, executar somente `prepare_vocabulary.mjs` e o validador, preservando os arquivos de níveis. Rodar o gerador completo com um vocabulário diferente pode mudar respostas e fingerprints. O relatório de geração permanece histórico; o relatório de validação registra o léxico atualizado.

O validador usa a mesma normalização, formação de palavras e política de catálogo que o aplicativo. Seu código de saída é 1 quando há erro, e o relatório contém arquivo, nível, palavra, regra e detalhe. Caminhos podem ser substituídos por `--levels`, `--lexicon`, `--daily` e `--report` para validar candidatos sem substituir os assets.

## Referência e licença

A grafia foi conferida no [léxico de Fernando Serboncini](https://github.com/fserb/pt-br), commit `93ba2a6f3b2f85262fba72df09d448c6bb2fa50a`, distribuído sob [MIT](https://github.com/fserb/pt-br/blob/93ba2a6f3b2f85262fba72df09d448c6bb2fa50a/LICENSE).

O arquivo fixado em `source/lexico.txt` tem SHA-256 `1148de44d58d59e40ef0a6695acefc031acf3f3e6bbfbfcc4c18d85660bde7c1`. A licença integral está em `source/LICENSE-fserb.txt` e é empacotada no app em `assets/data/LICENSE-fserb.txt`. `source/fserb-commit.txt` registra a revisão. O corpus completo não entra no APK.

O corpus contém lemas; plurais e femininos escolhidos aparecem explicitamente no TSV. `referenceLemma` registra o lema de conferência, incluindo relações irregulares aprovadas. A transformação de flexão serve apenas para conferência de entradas já selecionadas; ela nunca gera automaticamente palavras aceitas durante o jogo. As frases foram redigidas para este projeto, sem copiar definições do corpus.

O campo `familiarity` é uma classificação editorial assistida (1: muito familiar; 2: comum; 3: pouco familiar). Entradas 3 e comprimentos fora de 3–6 ficam excluídos. Não se trata de uma frequência estatística de corpus nem de aprovação por especialistas humanos.

## Geração e pontuação

- Candidatos partem de palavras da seleção; extensões de uma ficha só são admitidas quando as respostas selecionadas usam coletivamente todas as fichas, incluindo suas multiplicidades.
- Cada nível tem 3–6 respostas, pelo menos uma extra e uma resposta com extensão de pelo menos `fichas - 1`.
- A identidade é o multiconjunto ordenado de fichas mais o conjunto ordenado de respostas. Alterar ordem, ID ou meta de extras não torna um nível distinto.
- O mesmo multiconjunto exige intervalo mínimo de 100 posições. Cada variante tem respostas diferentes; um custo de repetição também favorece palavras menos usadas e evita repetições nos cinco níveis próximos.
- A pontuação inteira é `20*(fichas-4) + 8*(respostas-3) + soma(2*(comprimento-3) + 5*(familiaridade-1)) + 2*anagramasAdicionais`.
- `anagramasAdicionais` é a quantidade de respostas menos a quantidade de assinaturas de anagramas diferentes. Por exemplo, três respostas de um mesmo grupo acrescentam duas unidades desse fator.
- Os limites de faixas estão no gerador e na política validada em Dart; `levels.json.policy` registra os parâmetros distribuídos. Alterar os parâmetros exige atualizar e validar os dois lados.
- Cada bloco reserva uma posição leve no final. Sua pontuação é menor que a dos quatro desafios anteriores e todas as suas palavras têm familiaridade 1. A média de dificuldade aumenta de faixa para faixa, sem exigir aumento a cada nível.

`generation_report.json` registra inventário, médias, frequência das respostas e palavras que ainda aparecem apenas como possíveis extras. A validação com jogadores e a revisão linguística humana integral continuam pendentes.
