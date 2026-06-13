# Security Considerations

O MetaWhats implementa várias diretrizes básicas de segurança voltadas ao MVP.

## Implementado no MVP
- **Autenticação Segura**: Senhas/Tokens no `.env`, senhas/OTP hasheadas (se não em cache) e uso de JWT com expiração curta + refresh token.
- **Proteção de Rotas**: O NestJS implementará Guards para verificar a autoria e validade do token JWT.
- **WebSocket Seguro**: O token é verificado no handshake do Socket.io, e a sessão é mantida mapeada por User ID.
- **Autorização (RBAC/ABAC Básica)**: 
  - Um usuário NUNCA pode acessar as mensagens de uma conversa na qual não seja participante.
  - O backend checa se `userId` pertence a `conversationId` antes de retornar histórico ou autorizar novos envios.
- **CORS e Helmet**: No backend de produção, o CORS deve ser restrito ao IP/Domínio ou ao App (embora app native muitas vezes ignore CORS origin), e Helmet será ativado.
- **Limitação de Mídia**: Validação rigorosa de Mime Type no NestJS para evitar upload de scripts maliciosos. Limite de tamanho via multer configurável.

## Notas sobre Criptografia Ponta a Ponta (E2EE)

> [!WARNING]
> O MVP **não** implementa verdadeira criptografia ponta a ponta (E2EE - End-to-End Encryption).
> 
> As mensagens trafegam criptografadas em trânsito devido ao TLS/SSL (HTTPS/WSS), mas chegam "em texto limpo" no backend e são guardadas de forma legível no banco de dados PostgreSQL.

**Para fase 2 (Implementação E2EE Real)**:
Será necessário utilizar bibliotecas nativas de Signal Protocol ou similar (e.g., `libsignal`), implementando trocas de chaves Diffie-Hellman, armazenamento local de chaves privadas (Secure Enclave/Keystore no mobile), pré-chaves públicas geradas e enviadas ao servidor. Nesse cenário, o backend do MetaWhats será "cego" para o conteúdo das mensagens, armazenando apenas o payload cifrado. O MVP prepara a estrutura com colunas `content` e `type` flexíveis que poderão abrigar payloads E2EE no futuro.
