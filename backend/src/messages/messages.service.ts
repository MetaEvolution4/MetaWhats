import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SendMessageDto, UpdateMessageDto, ReactMessageDto } from './dto/message.dto';

@Injectable()
export class MessagesService {
  constructor(private readonly prisma: PrismaService) {}

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
        statuses: { where: { user_id: userId } },
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
        content: dto.content,
        nonce: dto.nonce,
        media_id: dto.media_id,
        reply_to_message_id: dto.reply_to_message_id,
      },
      include: { media: true, reactions: true }
    });

    // Update conversation updated_at
    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: { updated_at: new Date() }
    });

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
      data: { content: dto.content, edited_at: new Date() }
    });
  }

  async deleteForEveryone(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message || message.sender_id !== userId) throw new ForbiddenException();

    return this.prisma.message.update({
      where: { id: messageId },
      data: { deleted_for_everyone_at: new Date(), content: null, media_id: null }
    });
  }

  async read(userId: string, messageId: string) {
    return this.prisma.messageStatus.upsert({
      where: { message_id_user_id_status: { message_id: messageId, user_id: userId, status: 'read' } },
      update: { status_at: new Date() },
      create: { message_id: messageId, user_id: userId, status: 'read' }
    });
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
