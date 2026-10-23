# Refúgio na neve — artes e configuração

Data: 23/10/2026. Versão: **0.8.0+13**.

O usuário aprovou a [prévia cartoon](refugio-neve-aprovado.png) e autorizou a implementação.

| Recurso local | Origem e uso |
|---|---|
| `assets/themes/refugio_neve/scenery-cartoon.png` | `01-fundo-refugio-neve-cartoon.png`: cenário com neve, pinheiros nas bordas, cabana de janelas iluminadas e centro livre para leitura. |
| `assets/themes/refugio_neve/mascot-cartoon.png` | `02-pinguim-cartoon.png`: pinguim com cachecol coral e fundo transparente; home, miniatura e canto da partida quando houver espaço. |
| `assets/themes/refugio_neve/ice-disc-cartoon.png` | `03-disco-gelo-cartoon.png`: disco de gelo com transparência e centro livre, somente decoração sob fichas interativas reais. |

As artes e a prévia foram criadas com a skill imagegen e a ferramenta integrada `image_gen` na proposta aprovada. Não houve nova geração ou edição de PNG na implementação. Uso sujeito aos termos aplicáveis da ferramenta. Arquivos finais copiados sem alteração para o projeto, independentes do cache. Prompts e referências: [refugio-neve-prompts-aprovados.md](refugio-neve-prompts-aprovados.md).

A prévia não é embutida como tela: textos, valores, letras e controles continuam widgets reais. As miniaturas reutilizam as mesmas artes locais. As fichas da partida têm gradiente azul-gelo, letras em petróleo escuro e embaralhamento menta; durante a seleção preservam os destaques existentes.

## Configuração

- `lib/core/theme/visual_theme_catalog.dart`: ID estável `refugio_neve`, título **Refúgio na neve** e mascote.
- `lib/core/widgets/cartoon_snow.dart`: cenário e variante discreta para telas auxiliares. A base compensa as margens transparentes e arredonda os eixos medidos do disco (1157 × 1137 pixels, centro 626,5 × 626,5 no PNG de 1254 × 1254). Somente a arte recebe escala, mantendo as coordenadas existentes das fichas, conexão e toque.
- `lib/core/widgets/themed_reading_page.dart`: superfície creme com contorno azul suave, sem mudar tamanho ou rolagem das respostas.
- `lib/core/widgets/garden.dart`: cenário e pinguim de canto quando houver espaço.
- `lib/features/game/presentation/widgets/home_art.dart`: cenário nevado, fichas decorativas creme e mascote na home.
- `lib/features/game/presentation/widgets/letter_wheel.dart`: disco e acabamento das fichas e embaralhamento. A lógica de gesto não muda.
- `lib/features/game/presentation/themes_screen.dart`: o catálogo dinâmico acomoda sete opções com rolagem e uma ou duas colunas.
- `pubspec.yaml`: inclusão explícita dos três PNGs e versão do pacote.

As ilustrações ignoram toque e leitura semântica. Se uma imagem falhar, há fundo claro, base simples ou ausência do mascote, sem bloquear o jogo. Não foram adicionados áudio ambiente, dependências, compras ou animação de mascote.

Os seis IDs anteriores continuam válidos; Jardim do Gatinho permanece padrão e fallback. A escolha usa `app_settings.visual_theme_id`, sem nova migração: schema SQLite 6 e payload 2 preservados.

