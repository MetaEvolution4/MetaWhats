# MetaWhats Architecture

## Overview

MetaWhats follows a modern client-server architecture with an emphasis on real-time communication.

### Mobile App (Client)
- **Framework**: Flutter (Dart)
- **Architecture**: Clean Architecture (Presentation, Domain, Data)
- **State Management**: Riverpod
- **Local Storage**: sqflite (structured data like messages/conversations), hive (key-value settings)
- **Network**: HTTP (Dio) for REST calls, `socket_io_client` for real-time events.

### Backend (Server)
- **Framework**: NestJS (Node.js/TypeScript)
- **Database**: PostgreSQL (relational data)
- **ORM**: Prisma
- **Cache/PubSub**: Redis (presence, typing indicators, horizontal scaling for websockets)
- **Real-time**: Socket.IO
- **Storage**: Local Disk (MVP), ready for S3

## Core Flows

### 1. Authentication Flow
1. User enters phone number.
2. Mobile requests OTP `/api/auth/request-otp`.
3. Backend generates OTP, logs to console, and stores in DB with expiration.
4. User enters OTP.
5. Mobile calls `/api/auth/verify-otp`.
6. Backend verifies, creates/updates User, generates JWT Access & Refresh tokens.
7. Mobile stores tokens securely and connects to WebSocket.

### 2. Message Sending Flow
1. User types and sends message.
2. Mobile stores message locally with status `pending` and emits `message:send` via WebSocket.
3. Backend receives, validates, saves to DB, sets status `sent`.
4. Backend emits `message:sent` back to sender, and `message:new` to recipients (if online).
5. Recipients receive `message:new`, save locally, and emit `message:delivered`.
6. Backend updates DB, emits `message:delivered` to original sender.

### 3. Offline Capabilities
- If WebSocket is disconnected, sent messages are saved as `pending`.
- Upon reconnection, app syncs pending messages.
- App syncs missed messages via REST `/api/conversations/:id/messages` or WebSocket payload on reconnect.

### 4. Presence and Typing
- Redis stores mapping: `user_id -> socket_id`.
- On connect, `presence:online` is broadcasted.
- On disconnect, backend updates `last_seen_at` in DB, broadcasts `presence:offline`.
- Typing status is temporary and relayed via Socket.IO using Redis Pub/Sub if needed for scaling.
