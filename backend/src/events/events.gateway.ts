import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket, OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { InjectRedis } from '@nestjs-modules/ioredis';
import { Redis } from 'ioredis';

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
    // Using simple redis client for presence
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
      if (!token) throw new Error('No token');
      
      const payload = this.jwtService.verify(token as string, { secret: process.env.JWT_SECRET || 'super_secret_jwt_key_12345' });
      client.data.user = payload;
      
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
          content: data.content,
          nonce: data.nonce,
        },
        include: { sender: { select: { id: true, name: true, phone: true } } }
      });

      // Emit to sender
      client.emit('message:sent', message);

      // Broadcast to others in the conversation room
      client.to(`conversation_${data.conversationId}`).emit('message:new', message);

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
}
