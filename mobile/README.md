# MetaWhats Mobile (Flutter)

Este é o aplicativo móvel do MetaWhats. Foi projetado utilizando Clean Architecture e Riverpod.

## Estrutura
- `lib/core`: Contém configuração de rede (Dio, interceptors), temas (light/dark) e injeção de dependências estáticas.
- `lib/data`: Modelos DTOs, Repositórios reais que conectam à API REST e WebSocket.
- `lib/domain`: Entidades e regras de negócio.
- `lib/presentation`: Widgets e UI do app organizados por feature (auth, chats, profile).

## Como Executar

1. Tenha o Flutter SDK instalado na sua máquina (>= 3.2.0).
2. Execute `flutter pub get` para baixar as dependências listadas no `pubspec.yaml`.
3. Para Android, certifique-se de configurar o Android SDK. Para iOS, configure o Xcode e rode `pod install` na pasta `ios/`.
4. Inicie o emulador.
5. Execute `flutter run`.

## Testes

- `flutter test`: Roda os testes unitários da camada de dados e domínio.

> Observação: A infraestrutura base foi gerada, mas como a máquina de deploy atual não possui o CLI do Flutter no PATH, a compilação completa não pôde ser verificada na esteira automatizada. Siga os passos acima localmente.
