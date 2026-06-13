# MetaWhats API Documentation

## REST Endpoints

### Auth
- `POST /api/auth/request-otp`
  - Body: `{ "phone": "+5511999999999" }`
- `POST /api/auth/verify-otp`
  - Body: `{ "phone": "+5511999999999", "code": "123456" }`
  - Response: `{ "accessToken": "...", "refreshToken": "..." }`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `GET /api/auth/me`

### Users
- `GET /api/users/me`
- `PATCH /api/users/me` (Update name, status)
- `POST /api/users/avatar` (Multipart form-data)

### Contacts
- `GET /api/contacts`
- `POST /api/contacts` (Add contact by phone)
- `DELETE /api/contacts/:id`
- `POST /api/contacts/:id/block`
- `POST /api/contacts/:id/unblock`

### Conversations
- `GET /api/conversations`
- `POST /api/conversations/direct` (Create 1:1)
  - Body: `{ "userId": 2 }`
- `POST /api/conversations/group`
  - Body: `{ "title": "Group 1", "userIds": [2,3,4] }`
- `GET /api/conversations/:id`
- `PATCH /api/conversations/:id`
- `POST /api/conversations/:id/archive`
- `POST /api/conversations/:id/pin`
- `POST /api/conversations/:id/mute`

### Messages
- `GET /api/conversations/:id/messages`
- `POST /api/conversations/:id/messages` (Fallback if WS fails)
- `PATCH /api/messages/:id` (Edit)
- `DELETE /api/messages/:id` (Delete for everyone)
- `POST /api/messages/:id/read`
- `POST /api/messages/:id/reaction`
- `DELETE /api/messages/:id/reaction`

### Media
- `POST /api/media/upload` (Multipart form-data)
- `GET /api/media/:id`

### Health
- `GET /health`

---

## WebSocket Events

*Namespace: `/`*
*Auth*: Token passed in `query` or `auth` header during connection.

### Client Emits (to Server)
- `auth:authenticate` - Re-authenticate connection.
- `conversation:join` - `{ "conversationId": "uuid" }`
- `conversation:leave` - `{ "conversationId": "uuid" }`
- `message:send` - `{ "conversationId": "...", "type": "text", "content": "..." }`
- `message:delivered` - `{ "messageId": "..." }`
- `message:read` - `{ "messageId": "..." }`
- `typing:start` - `{ "conversationId": "..." }`
- `typing:stop` - `{ "conversationId": "..." }`
- `presence:update` - Update online status.

### Server Emits (to Client)
- `message:new` - Incoming new message payload.
- `message:sent` - Confirmation that server saved the message.
- `message:delivered` - Notification that recipient got it.
- `message:read` - Notification that recipient read it.
- `message:updated` - Content changed.
- `message:deleted` - Message deleted for everyone.
- `reaction:updated` - Someone reacted.
- `typing:start` / `typing:stop`
- `presence:online` / `presence:offline`
- `conversation:updated` - New conversation or group change.
