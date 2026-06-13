# MetaWhats

Projeto MVP de aplicativo de mensagens estilo WhatsApp.

## Estrutura do Projeto

- `/backend`: API REST e servidor WebSocket usando NestJS.
- `/mobile`: Aplicativo mobile desenvolvido com Flutter.
- `/docs`: Documentação do sistema.
- `/infra`: Arquivos de infraestrutura, reverse proxy (Nginx).
- `/postman`: Coleções para testes de rotas REST.

## Tecnologias

- **Backend**: Node.js, NestJS, TypeScript, Prisma ORM, PostgreSQL, Redis, Socket.IO.
- **Mobile**: Flutter, Dart, Riverpod, sqflite, hive.

## Como Executar Localmente

### Pré-requisitos
- Docker e Docker Compose.
- Node.js 18+ (opcional para rodar sem docker).
- Flutter SDK 3.19+ (para rodar o app mobile).

### Passo a passo

1. **Configuração de Ambiente**
   Copie `.env.example` para `.env` na raiz do projeto e dentro de `backend`.

   ```bash
   cp .env.example .env
   cp .env.example backend/.env
   ```

2. **Subir Infraestrutura**
   Na raiz do projeto:
   ```bash
   docker compose up -d
   ```
   Isso iniciará o PostgreSQL, Redis e o backend.

3. **Rodar Migrations**
   Caso as migrations não rodem automaticamente:
   ```bash
   docker compose exec backend npx prisma migrate deploy
   ```

4. **Executar Mobile**
   Acesse a pasta `mobile`:
   ```bash
   cd mobile
   flutter pub get
   flutter run
   ```

## Documentação

- [Arquitetura](docs/ARCHITECTURE.md)
- [API Endpoints e WebSocket](docs/API.md)
- [Deploy Linux](docs/DEPLOY_LINUX.md)
- [Segurança](docs/SECURITY.md)
- [Testes](docs/TESTS.md)
- [Build Mobile](docs/MOBILE_BUILD.md)
