# Biblioteca encantada — alinhamento do círculo

Data: 22/10/2026. Versão: **0.4.1+9**.

O usuário identificou que as letras não acompanhavam o círculo da base do livro. A arte era ajustada pelo centro do PNG, mas o selo está acima desse ponto: o livro ocupa mais espaço abaixo dele.

`CartoonLibrarySeal` agora posiciona a arte pelo centro do selo, alinhado ao centro da roda e do botão de embaralhar. Uma pequena compensação da proporção vertical corrige a leve elipse da ilustração. O ajuste acompanha o tamanho existente da roda. A imagem original, as posições das fichas, as áreas de toque e os eventos de arraste continuam os mesmos.

A coruja de canto da Biblioteca fica um pouco mais abaixo, livre da borda do livro reposicionado.

- [Antes da correção](antes-biblioteca/08-partida-biblioteca-desalinhada.png).
- [Captura da partida corrigida](antes-fundo-mar/08-partida-biblioteca.png).

Validação local: análise estática sem problemas; **31 testes aprovados** de temas, preferências e gestos, incluindo os três temas em oito tamanhos/orientações com texto 1×/2×. Formatação e whitespace verificados. Não foram criadas novas regras, dependências ou migrações de banco.

Integração Android aprovada no emulador API 35: seleção dos três temas, palavra por arraste na Biblioteca, embaralhamento e restauração do tema e das partidas após reabrir o banco. Captura final inspecionada: círculo, quatro letras e embaralhamento concêntricos, com coruja de canto visível. A fixture usa somente `themes_integration.db`; não limpa o banco normal. Não houve teste em aparelho físico.

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, entrada `lib/main.dart`. Atualização com `adb install -r`, preservando dados.

O APK 0.4.1+9 foi compilado, instalado por atualização com sucesso e iniciado no emulador.
