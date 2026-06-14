import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SendMessageDto, UpdateMessageDto, ReactMessageDto } from './dto/message.dto';
import { EventsGateway } from '../events/events.gateway';
import { PushService } from '../push/push.service';

@Injectable()
export class MessagesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly eventsGateway: EventsGateway,
    private readonly pushService: PushService,
  ) {}

  async checkParticipant(userId: string, conversationId: string) {
    const participant = await this.prisma.conversationParticipant.findUnique({
      where: { conversation_id_user_id: { conversation_id: conversationId, user_id: userId } }
    });
    if (!participant || participant.left_at) {
      throw new ForbiddenException('Not a participant of this conversation');
    }
    return participant;
  }

  async getMessages(userId: string, conversationId: string) {
    await this.checkParticipant(userId, conversationId);

    return this.prisma.message.findMany({
      where: { conversation_id: conversationId },
      include: {
        media: true,
        reactions: true,
        statuses: true,
      },
      orderBy: { created_at: 'asc' },
    });
  }

  async send(userId: string, conversationId: string, dto: SendMessageDto) {
    await this.checkParticipant(userId, conversationId);

    const message = await this.prisma.message.create({
      data: {
        conversation_id: conversationId,
        sender_id: userId,
        type: dto.type,
        ciphertext: dto.ciphertext,
        cipher_type: dto.cipher_type,
        nonce: dto.nonce,
        media_id: dto.media_id,
        reply_to_message_id: dto.reply_to_message_id,
      },
      include: { media: true, reactions: true, sender: { select: { id: true, name: true, phone: true } } }
    });

    // Update conversation updated_at
    const conversation = await this.prisma.conversation.update({
      where: { id: conversationId },
      data: { updated_at: new Date() },
      include: { participants: true }
    });

    // Broadcast to conversation room (for active chat screens)
    this.eventsGateway.server.to(`conversation_${conversationId}`).emit('message:new', message);

    // Broadcast to all participants' personal rooms (for Home screens and notifications)
    const fcmTokens = [];
    for (const participant of conversation.participants) {
      this.eventsGateway.server.to(`user_${participant.user_id}`).emit('message:new', message);

      if (participant.user_id !== userId) {
        // Collect FCM tokens for offline/background users
        const devices = await this.prisma.device.findMany({ where: { user_id: participant.user_id } });
        for (const device of devices) {
          if (device.fcm_token) fcmTokens.push(device.fcm_token);
        }
      }
    }

    if (fcmTokens.length > 0) {
      await this.pushService.sendPushToDevices(fcmTokens, conversationId);
    }

    return message;
  }

  async edit(userId: string, messageId: string, dto: UpdateMessageDto) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message || message.sender_id !== userId) throw new ForbiddenException();

    // Limit time to edit? (e.g. 15 minutes)
    const timeDiff = Date.now() - message.created_at.getTime();
    if (timeDiff > 15 * 60 * 1000) {
      throw new BadRequestException('Time limit for editing has passed');
    }

    return this.prisma.message.update({
      where: { id: messageId },
      data: { ciphertext: dto.ciphertext, edited_at: new Date() }
    });
  }

  async deleteForEveryone(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message || message.sender_id !== userId) throw new ForbiddenException();

    return this.prisma.message.update({
      where: { id: messageId },
      data: { deleted_for_everyone_at: new Date(), ciphertext: null, media_id: null }
    });
  }

  async read(userId: string, messageId: string) {
    console.log(`[MessagesService] read called for messageId=${messageId} by userId=${userId}`);
    const status = await this.prisma.messageStatus.upsert({
      where: { message_id_user_id_status: { message_id: messageId, user_id: userId, status: 'read' } },
      update: { status_at: new Date() },
      create: { message_id: messageId, user_id: userId, status: 'read' }
    });

    const msg = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: { conversation: true }
    });

    if (msg) {
      console.log(`[MessagesService] Emitting read status to user_${msg.sender_id}`);
      this.eventsGateway.server.to(`user_${msg.sender_id}`).emit('message:status', {
        messageId: messageId,
        conversationId: msg.conversation_id,
        userId: userId,
        status: 'read'
      });
    }

    return status;
  }

  async delivered(userId: string, messageId: string) {
    console.log(`[MessagesService] delivered called for messageId=${messageId} by userId=${userId}`);
    const status = await this.prisma.messageStatus.upsert({
      where: { message_id_user_id_status: { message_id: messageId, user_id: userId, status: 'delivered' } },
      update: { status_at: new Date() },
      create: { message_id: messageId, user_id: userId, status: 'delivered' }
    });

    const msg = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: { conversation: true }
    });

    if (msg) {
      console.log(`[MessagesService] Emitting delivered status to user_${msg.sender_id}`);
      this.eventsGateway.server.to(`user_${msg.sender_id}`).emit('message:status', {
        messageId: messageId,
        conversationId: msg.conversation_id,
        userId: userId,
        status: 'delivered'
      });
    }

    return status;
  }

  async react(userId: string, messageId: string, dto: ReactMessageDto) {
    return this.prisma.messageReaction.upsert({
      where: { message_id_user_id_emoji: { message_id: messageId, user_id: userId, emoji: dto.emoji } },
      update: { created_at: new Date() },
      create: { message_id: messageId, user_id: userId, emoji: dto.emoji }
    });
  }

  async removeReaction(userId: string, messageId: string, emoji: string) {
    return this.prisma.messageReaction.delete({
      where: { message_id_user_id_emoji: { message_id: messageId, user_id: userId, emoji } }
    });
  }
}
