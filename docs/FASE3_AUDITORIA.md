# FASE 3: Auditoria do Projeto MetaWhats (Push Notifications & E2EE)

## 1. Visão Geral e Arquitetura Atual
**Mobile Framework:** Flutter (Dart).
**Backend:** NestJS (TypeScript) rodando em Node.js no servidor remoto (Coolify/Railway).
**Banco de Dados:** PostgreSQL (gerenciado via Prisma).
**Armazenamento Local:** SQLite via plugin `sqflite`.

## 2. Fluxo Atual de Envio/Recebimento de Mensagens
1. **Envio:** O cliente mobile faz uma requisição HTTP REST POST para `/api/conversations/:id/messages` enviando o conteúdo da mensagem em texto puro.
2. **Persistência:** O backend recebe e persiste a mensagem em texto puro no banco de dados PostgreSQL.
3. **Notificação em Tempo Real (Socket):** O backend dispara um evento Socket.IO (`message:new`) para a sala de conversação ou sala do usuário destinatário.
4. **Recepção:** O cliente receptor escuta via `socket_io_client` e atualiza a interface, chamando o backend REST para atualizar o status para `delivered` ou `read`.
5. **Fallback:** Foi adicionado um sistema de Polling a cada 10 segundos no mobile para garantir o recebimento caso a conexão do WebSocket caia (limitação do Cloudflare).

## 3. Identificação de Usuários e Dispositivos
- **Usuários:** Autenticados via JWT através de SMS OTP (burlado no dev via master OTP). Identificados por UUID (`user_id`).
- **Dispositivos:** Atualmente **NÃO EXISTE** gerenciamento de dispositivos (`device_id`). O sistema assume 1 usuário = 1 conexão. Isso impede o funcionamento correto da criptografia E2EE (Double Ratchet) e de Push Notifications se o usuário possuir mais de um celular.

## 4. Auditoria de Segurança (O que está errado)
- As mensagens estão trafegando com criptografia TLS/HTTPS, o que protege contra MITM, **MAS** estão sendo armazenadas em **texto puro** no banco de dados do servidor.
- O campo `content` na tabela `Message` no Prisma armazena o texto claro.
- A promessa de E2EE no `task.md` atual não foi implementada de fato, apenas mencionada como requisito usando `sqflite`. O `sqflite` atual não é protegido criptograficamente.

## 5. Auditoria de Push Notifications
- **Firebase / FCM:** Totalmente ausente. Nenhum pacote de push foi adicionado ao `pubspec.yaml` (como `firebase_messaging`).
- **Configurações Android/iOS:** Ausentes. O `google-services.json` e o `GoogleService-Info.plist` não estão no repositório. Nenhuma permissão `POST_NOTIFICATIONS` configurada no `AndroidManifest.xml`.
- **Tabela no Backend:** Não existe tabela no banco para salvar os tokens do FCM (`fcm_token`) associados aos usuários.

## 6. O Que Precisa Mudar (Plano de Ação)
### Backend:
- Alterar o `schema.prisma` para incluir a tabela `Device` ou `FCMToken`.
- Alterar a tabela `Message` para incluir `ciphertext` e remover `content` em texto puro.
- Implementar as rotas de PreKeys (Signal Protocol): `IdentityKey`, `SignedPreKey`, e `OneTimePreKeys`.
- Implementar o disparo de notificações FCM genéricas no endpoint de mensagens via Firebase Admin SDK.

### Mobile (Flutter):
- **E2EE:** Integrar o pacote `libsignal_protocol_dart`. Gerar as chaves de identidade no primeiro login. Armazenar as chaves privadas no sistema seguro de KeyStore (usando pacote `flutter_secure_storage`) e NÃO em texto claro no `sqflite`.
- **Push:** Integrar `firebase_core` e `firebase_messaging`. Pedir permissões no Android 13+ e iOS. Configurar o top-level handler para receber payloads em background e descriptografar/inserir localmente ou apenas acordar o app.

## 7. Riscos Técnicos e Limitações
1. **Limitações do iOS (Background Push):** O iOS limita agressivamente o "Silent Push" (content-available: 1). Se o FCM não contiver um campo genérico visível ("Nova Mensagem"), o iOS pode não acordar o app em background para descriptografar. A notificação *deve* mostrar o balão, e quando clicada, o app descriptografa e mostra a mensagem. O iOS 15+ permite `Notification Service Extension` para interceptar e descriptografar o payload antes de mostrar a notificação, MAS requer configuração nativa pesada no Xcode. Recomendado MVP: O push apenas avisa "Nova mensagem" e a descriptografia ocorre ao abrir o app.
2. **Limitações do Android:** OEMs (Xiaomi, Samsung) costumam matar o app em background. O Push precisa ser configurado com prioridade `high` no FCM.
3. **Complexidade do Signal Protocol:** O pacote `libsignal_protocol_dart` existe, mas gerenciar as sessões locais assíncronas no Flutter é sensível a corrompimentos. Se o banco SQLite corromper, o usuário precisará reinstalar o app.

## 8. Arquivos que serão alterados
- `backend/prisma/schema.prisma`
- `backend/src/messages/messages.service.ts`
- `mobile/pubspec.yaml`
- `mobile/lib/domain/...`
- `mobile/lib/presentation/screens/...`
- (Arquivos de configuração Android/iOS do Firebase).
