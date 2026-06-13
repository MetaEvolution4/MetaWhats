# Estratégia de Testes - MetaWhats

## Backend (NestJS)

### Testes Unitários
O foco dos testes unitários no backend recai sobre a regra de negócio central, desacoplada do banco.
- `AuthService`: Geração de OTP, validação de OTP e emissão de JWT.
- `MessagesService`: Regras de negócio de tempo limite para deletar/editar mensagens, ou de autorização de leitura.
- `ConversationsService`: Criação de grupos e limitação de permissões de admin.

Para rodar:
```bash
cd backend
npm run test
```

### Testes End-to-End (E2E)
Testam o fluxo completo de endpoints da API (ex: `POST /api/auth/request-otp` resultando numa alteração no Prisma). Usam banco InMemory ou Dockerizado isolado.
Para rodar:
```bash
npm run test:e2e
```

---

## Mobile (Flutter)

### Testes Unitários
Testes nas classes de camada de Domínio e Data (Repositories e Models).
- Parse de JSON de mensagens via API.
- Teste de providers do Riverpod mockando as chamadas Dio/HTTP.

Para rodar:
```bash
cd mobile
flutter test
```

### Testes de Widget
Focam em verificar as interfaces de `Login` e de listagem de conversas. Validam também exibições de estado de loading ou de lista vazia.
Execução via `flutter test`.

### Testes de Integração
Localizados na pasta `integration_test/`, simulam o app real abrindo no emulador e passando pelo fluxo completo até a tela de mensagens.
```bash
flutter test integration_test/app_test.dart
```
