import { Injectable, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDirectConversationDto, CreateGroupConversationDto } from './dto/create-conversation.dto';

@Injectable()
export class ConversationsService {
  constructor(private readonly prisma: PrismaService) {}

  async createDirect(userId: string, dto: CreateDirectConversationDto) {
    if (userId === dto.userId) {
      throw new BadRequestException('Cannot create a conversation with yourself');
    }

    // Check if a direct conversation already exists between these two users
    const existing = await this.prisma.conversation.findFirst({
      where: {
        type: 'direct',
        participants: {
          every: {
            user_id: { in: [userId, dto.userId] }
          }
        }
      },
      include: { participants: true }
    });

    // Need to verify it really only has these two. 
    // For simplicity, we just check if we found one where both participate.
    if (existing) {
      // additional check to ensure count is exactly 2
      const isExactMatch = existing.participants.length === 2;
      if (isExactMatch) return existing;
    }

    return this.prisma.conversation.create({
      data: {
        type: 'direct',
        created_by: userId,
        participants: {
          create: [
            { user_id: userId, role: 'owner' },
            { user_id: dto.userId, role: 'member' }
          ]
        }
      },
      include: { participants: true }
    });
  }

  async createGroup(userId: string, dto: CreateGroupConversationDto) {
    const participantsData = dto.userIds.map(id => ({ user_id: id, role: 'member' }));
    participantsData.push({ user_id: userId, role: 'owner' });

    return this.prisma.conversation.create({
      data: {
        type: 'group',
        title: dto.title,
        created_by: userId,
        participants: {
          create: participantsData,
        }
      },
      include: { participants: true }
    });
  }

  async findAllForUser(userId: string) {
    return this.prisma.conversation.findMany({
      where: {
        participants: {
          some: { user_id: userId, left_at: null }
        }
      },
      include: {
        participants: {
          include: {
            user: {
              select: { id: true, name: true, phone: true, avatar_url: true }
            }
          }
        },
        messages: {
          orderBy: { created_at: 'desc' },
          take: 1
        }
      },
      orderBy: { updated_at: 'desc' }
    });
  }

  async findOne(userId: string, conversationId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: {
        participants: {
          include: {
            user: {
              select: { id: true, name: true, phone: true, avatar_url: true }
            }
          }
        }
      }
    });

    if (!conversation) throw new NotFoundException('Conversation not found');

    const isParticipant = conversation.participants.some(p => p.user_id === userId && !p.left_at);
    if (!isParticipant) throw new ForbiddenException('You are not a participant');

    return conversation;
  }

  async archive(userId: string, conversationId: string) {
    // Find the participant record
    const participant = await this.prisma.conversationParticipant.findUnique({
      where: { conversation_id_user_id: { conversation_id: conversationId, user_id: userId } }
    });

    if (!participant) throw new ForbiddenException();

    return this.prisma.conversationParticipant.update({
      where: { id: participant.id },
      data: { archived_at: new Date() }
    });
  }

  async pin(userId: string, conversationId: string) {
    const participant = await this.prisma.conversationParticipant.findUnique({
      where: { conversation_id_user_id: { conversation_id: conversationId, user_id: userId } }
    });

    if (!participant) throw new ForbiddenException();

    return this.prisma.conversationParticipant.update({
      where: { id: participant.id },
      data: { pinned_at: new Date() }
    });
  }
}
