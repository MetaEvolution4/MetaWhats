import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateContactDto } from './dto/create-contact.dto';

@Injectable()
export class ContactsService {
  constructor(private readonly prisma: PrismaService) {}

  async addContact(ownerId: string, dto: CreateContactDto) {
    const contactUser = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    if (!contactUser) {
      throw new NotFoundException('User with this phone not found in the system');
    }

    if (ownerId === contactUser.id) {
      throw new BadRequestException('You cannot add yourself as a contact');
    }

    // Upsert contact
    const contact = await this.prisma.contact.upsert({
      where: {
        owner_user_id_contact_user_id: {
          owner_user_id: ownerId,
          contact_user_id: contactUser.id,
        },
      },
      update: {
        nickname: dto.nickname,
      },
      create: {
        owner_user_id: ownerId,
        contact_user_id: contactUser.id,
        nickname: dto.nickname,
      },
      include: {
        contact: {
          select: {
            id: true,
            phone: true,
            name: true,
            avatar_url: true,
            status_message: true,
            last_seen_at: true,
            is_online: true,
          }
        }
      }
    });

    return contact;
  }

  async getContacts(ownerId: string) {
    return this.prisma.contact.findMany({
      where: { owner_user_id: ownerId },
      include: {
        contact: {
          select: {
            id: true,
            phone: true,
            name: true,
            avatar_url: true,
            status_message: true,
            last_seen_at: true,
            is_online: true,
          }
        }
      }
    });
  }

  async removeContact(ownerId: string, contactId: string) {
    return this.prisma.contact.delete({
      where: {
        id: contactId,
        owner_user_id: ownerId, // ensure ownership
      },
    });
  }

  async blockContact(ownerId: string, contactId: string) {
    return this.prisma.contact.update({
      where: { id: contactId, owner_user_id: ownerId },
      data: { blocked_at: new Date() },
    });
  }

  async unblockContact(ownerId: string, contactId: string) {
    return this.prisma.contact.update({
      where: { id: contactId, owner_user_id: ownerId },
      data: { blocked_at: null },
    });
  }
}
