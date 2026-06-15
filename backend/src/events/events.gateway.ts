import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket, OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { InjectRedis } from '@nestjs-modules/ioredis';
import { Redis } from 'ioredis';
import { PushService } from '../push/push.service';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class EventsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private jwtService: JwtService,
    private prisma: PrismaService,
    private pushService: PushService,
  ) {}

  // Since we haven't formally setup @nestjs-modules/ioredis module, 
  // we'll instantiate a simple ioredis client directly for MVP presence.
  private redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379'),
  });

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token || client.handshake.query?.token;
      if (!token) {
        console.log(`[Socket] Connection rejected: No token for client ${client.id}`);
        throw new Error('No token');
      }
      
      const payload = this.jwtService.verify(token as string, { secret: process.env.JWT_SECRET || 'super_secret_jwt_key_12345' });
      client.data.user = payload;
      
      // Join a personal room for this user to receive direct updates
      client.join(`user_${payload.sub}`);
      console.log(`[Socket] Client ${client.id} connected and joined user_${payload.sub}`);
      
      // Update presence
      await this.redisClient.set(`presence:${payload.sub}`, client.id);
      
      // Update DB
      await this.prisma.user.update({
        where: { id: payload.sub },
        data: { is_online: true },
      });

      // Broadcast presence
      this.server.emit('presence:online', { userId: payload.sub });
      
      console.log(`Client connected: ${client.id} (User: ${payload.sub})`);
    } catch (err) {
      client.disconnect();
    }
  }

  async handleDisconnect(client: Socket) {
    const user = client.data.user;
    if (user) {
      await this.redisClient.del(`presence:${user.sub}`);
      
      // Update DB
      await this.prisma.user.update({
        where: { id: user.sub },
        data: { is_online: false, last_seen_at: new Date() },
      });

      this.server.emit('presence:offline', { userId: user.sub, lastSeenAt: new Date() });
      console.log(`Client disconnected: ${client.id} (User: ${user.sub})`);
    }
  }

  @SubscribeMessage('conversation:join')
  handleJoinConversation(@MessageBody() data: { conversationId: string }, @ConnectedSocket() client: Socket) {
    client.join(`conversation_${data.conversationId}`);
    return { status: 'joined', conversationId: data.conversationId };
  }

  @SubscribeMessage('conversation:leave')
  handleLeaveConversation(@MessageBody() data: { conversationId: string }, @ConnectedSocket() client: Socket) {
    client.leave(`conversation_${data.conversationId}`);
    return { status: 'left', conversationId: data.conversationId };
  }

  @SubscribeMessage('message:send')
  async handleSendMessage(@MessageBody() data: any, @ConnectedSocket() client: Socket) {
    const user = client.data.user;
    // Usually we would call MessagesService here, but for simplicity in MVP gateway:
    try {
      const message = await this.prisma.message.create({
        data: {
          conversation_id: data.conversationId,
          sender_id: user.sub,
          type: data.type || 'text',
          ciphertext: data.ciphertext || '',
          cipher_type: data.cipher_type || 3,
          nonce: data.nonce,
        },
        include: { sender: { select: { id: true, name: true, phone: true } } }
      });

      // Emit to sender
      client.emit('message:sent', message);

      // Broadcast to others in the conversation room
      client.to(`conversation_${data.conversationId}`).emit('message:new', message);

      // Fetch conversation participants for FCM
      const conversation = await this.prisma.conversation.findUnique({
        where: { id: data.conversationId },
        include: { participants: true }
      });

      if (conversation) {
        const fcmTokens = [];
        for (const participant of conversation.participants) {
          if (participant.user_id !== user.sub) {
            const devices = await this.prisma.device.findMany({ where: { user_id: participant.user_id } });
            for (const device of devices) {
              if (device.fcm_token) fcmTokens.push(device.fcm_token);
            }
          }
        }
        if (fcmTokens.length > 0) {
          await this.pushService.sendPushToDevices(fcmTokens, data.conversationId);
        }
      }

      return { status: 'ok', messageId: message.id };
    } catch (e) {
      return { status: 'error', error: e.message };
    }
  }

  @SubscribeMessage('typing:start')
  handleTypingStart(@MessageBody() data: { conversationId: string }, @ConnectedSocket() client: Socket) {
    client.to(`conversation_${data.conversationId}`).emit('typing:start', { 
      userId: client.data.user.sub,
      conversationId: data.conversationId
    });
  }

  @SubscribeMessage('typing:stop')
  handleTypingStop(@MessageBody() data: { conversationId: string }, @ConnectedSocket() client: Socket) {
    client.to(`conversation_${data.conversationId}`).emit('typing:stop', { 
      userId: client.data.user.sub,
      conversationId: data.conversationId
    });
  }

  @SubscribeMessage('message:read')
  async handleMessageRead(@MessageBody() data: { messageId: string, conversationId: string }, @ConnectedSocket() client: Socket) {
    const user = client.data.user;
    try {
      // Update DB
      await this.prisma.messageStatus.upsert({
        where: { message_id_user_id_status: { message_id: data.messageId, user_id: user.sub, status: 'read' } },
        update: {},
        create: { message_id: data.messageId, user_id: user.sub, status: 'read' }
      });
      // Broadcast read receipt
      client.to(`conversation_${data.conversationId}`).emit('message:status', {
        messageId: data.messageId,
        userId: user.sub,
        status: 'read'
      });
    } catch(e) {}
  }

  // --- WebRTC Signaling ---
  
  @SubscribeMessage('call:start')
  handleCallStart(@MessageBody() payload: { conversationId: string, recipientId?: string, offer: any }, @ConnectedSocket() client: Socket) {
    if (payload.recipientId) {
      client.to(`user_${payload.recipientId}`).emit('call:incoming', {
        callerId: client.data.user.sub,
        conversationId: payload.conversationId,
        offer: payload.offer,
      });
    } else {
      client.to(`conversation_${payload.conversationId}`).emit('call:incoming', {
        callerId: client.data.user.sub,
        conversationId: payload.conversationId,
        offer: payload.offer,
      });
    }
  }

  @SubscribeMessage('call:answer')
  handleCallAnswer(@MessageBody() payload: { conversationId: string, recipientId?: string, answer: any }, @ConnectedSocket() client: Socket) {
    if (payload.recipientId) {
      client.to(`user_${payload.recipientId}`).emit('call:answer', {
        conversationId: payload.conversationId,
        answer: payload.answer,
      });
    } else {
      client.to(`conversation_${payload.conversationId}`).emit('call:answer', {
        conversationId: payload.conversationId,
        answer: payload.answer,
      });
    }
  }

  @SubscribeMessage('call:ice-candidate')
  handleCallIceCandidate(@MessageBody() payload: { conversationId: string, recipientId?: string, candidate: any }, @ConnectedSocket() client: Socket) {
    if (payload.recipientId) {
      client.to(`user_${payload.recipientId}`).emit('call:ice-candidate', {
        conversationId: payload.conversationId,
        candidate: payload.candidate,
      });
    } else {
      client.to(`conversation_${payload.conversationId}`).emit('call:ice-candidate', {
        conversationId: payload.conversationId,
        candidate: payload.candidate,
      });
    }
  }

  @SubscribeMessage('call:end')
  handleCallEnd(@MessageBody() data: { targetUserId: string }, @ConnectedSocket() client: Socket) {
    client.to(`user_${data.targetUserId}`).emit('call:end', {
      userId: client.data.user.sub
    });
  }

  @SubscribeMessage('call:reject')
  handleCallReject(@MessageBody() data: { targetUserId: string }, @ConnectedSocket() client: Socket) {
    client.to(`user_${data.targetUserId}`).emit('call:reject', {
      userId: client.data.user.sub
    });
  }
}
