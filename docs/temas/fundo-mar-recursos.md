# Fundo do mar — artes e configuração

Data: 22/10/2026. Versão: **0.5.0+10**.

O usuário aprovou a [prévia cartoon](fundo-mar-aprovado.png) e autorizou a implementação. As três artes aprovadas foram copiadas sem alteração para o projeto e incluídas no pacote Android.

| Recurso local | Origem e uso |
|---|---|
| `assets/themes/fundo_mar/scenery-cartoon.png` | `01-fundo-mar-cartoon.png`: cenário vertical em aqua e turquesa, corais nas bordas e centro livre para leitura. |
| `assets/themes/fundo_mar/mascot-cartoon.png` | `02-tartaruga-cartoon.png`: tartaruguinha verde, PNG com transparência, usada na home, miniatura e canto da partida quando houver espaço. |
| `assets/themes/fundo_mar/shell-cartoon.png` | `03-concha-cartoon.png`: concha perolada transparente, somente decoração sob as fichas reais. |

As artes e a prévia foram geradas pela skill imagegen usando a ferramenta integrada `image_gen`, sem CLI/API, durante a proposta aprovada. Uso sujeito aos termos aplicáveis da ferramenta. Não houve nova geração na implementação. Arquivos finais no projeto, independentes do cache da ferramenta. Prompts completos e referências: [fundo-mar-prompts-aprovados.md](fundo-mar-prompts-aprovados.md).

A prévia é referência visual; não é embutida como tela. Textos, moedas, letras e controles são widgets reais, alimentados pelo estado da partida. As miniaturas usam as mesmas artes locais, sem arquivos duplicados.

## Configuração

- `lib/core/theme/visual_theme_catalog.dart`: identidade estável `fundo_mar`, título **Fundo do mar** e mascote.
- `lib/core/widgets/cartoon_ocean.dart`: cenário, variante discreta em telas auxiliares e concha. A base compensa a margem transparente com escala uniforme de 1,04 em torno do centro da roda, sem mover fichas ou áreas de toque.
- `lib/core/widgets/themed_reading_page.dart`: superfície clara compartilhada com a Biblioteca; a versão marinha tem contorno aqua. Preserva dimensões e rolagem das respostas.
- `lib/core/widgets/garden.dart`: fundo ativo e mascote de canto em telas com espaço suficiente.
- `lib/features/game/presentation/widgets/home_art.dart`: cenário, fichas decorativas creme e tartaruga na home.
- `lib/features/game/presentation/widgets/letter_wheel.dart`: concha atrás das letras e botão central verde-petróleo; usa a geometria e os eventos existentes.
- `lib/features/game/presentation/themes_screen.dart`: o catálogo dinâmico já acomoda a quarta opção em uma ou duas colunas, com rolagem.
- `pubspec.yaml`: versão e inclusão explícita dos três PNGs.

As ilustrações ignoram toque e leitura semântica. Falha de carregamento usa fundo claro, base simples ou dispensa o mascote, sem bloquear os controles. Não foram adicionados música, áudio ambiente, dependências, compras ou animação de mascote.

IDs anteriores preservados: `jardim_gatinho`, `capivara_lagoa`, `biblioteca_encantada`. O jardim permanece padrão, inclusive para IDs desconhecidos. O ID marinho usa `app_settings.visual_theme_id`, sem migração adicional: schema 6 e payload 2 continuam válidos.
