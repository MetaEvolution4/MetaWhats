import { Controller, Get, Post, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { ContactsService } from './contacts.service';
import { CreateContactDto } from './dto/create-contact.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';

@ApiTags('contacts')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/contacts')
export class ContactsController {
  constructor(private readonly contactsService: ContactsService) {}

  @Get()
  @ApiOperation({ summary: 'Get my contacts' })
  getContacts(@Request() req: any) {
    return this.contactsService.getContacts(req.user.userId);
  }

  @Post()
  @ApiOperation({ summary: 'Add a new contact by phone' })
  addContact(@Request() req: any, @Body() dto: CreateContactDto) {
    return this.contactsService.addContact(req.user.userId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Remove a contact' })
  removeContact(@Request() req: any, @Param('id') id: string) {
    return this.contactsService.removeContact(req.user.userId, id);
  }

  @Post(':id/block')
  @ApiOperation({ summary: 'Block a contact' })
  blockContact(@Request() req: any, @Param('id') id: string) {
    return this.contactsService.blockContact(req.user.userId, id);
  }

  @Post(':id/unblock')
  @ApiOperation({ summary: 'Unblock a contact' })
  unblockContact(@Request() req: any, @Param('id') id: string) {
    return this.contactsService.unblockContact(req.user.userId, id);
  }
}
