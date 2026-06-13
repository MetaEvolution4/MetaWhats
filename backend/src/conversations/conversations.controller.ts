import { Controller, Get, Post, Body, Param, UseGuards, Request } from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import { CreateDirectConversationDto, CreateGroupConversationDto } from './dto/create-conversation.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';

@ApiTags('conversations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/conversations')
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Get()
  @ApiOperation({ summary: 'List all my conversations' })
  findAll(@Request() req: any) {
    return this.conversationsService.findAllForUser(req.user.userId);
  }

  @Post('direct')
  @ApiOperation({ summary: 'Create or get 1:1 conversation' })
  createDirect(@Request() req: any, @Body() dto: CreateDirectConversationDto) {
    return this.conversationsService.createDirect(req.user.userId, dto);
  }

  @Post('group')
  @ApiOperation({ summary: 'Create a group conversation' })
  createGroup(@Request() req: any, @Body() dto: CreateGroupConversationDto) {
    return this.conversationsService.createGroup(req.user.userId, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get conversation details' })
  findOne(@Request() req: any, @Param('id') id: string) {
    return this.conversationsService.findOne(req.user.userId, id);
  }

  @Post(':id/archive')
  @ApiOperation({ summary: 'Archive a conversation' })
  archive(@Request() req: any, @Param('id') id: string) {
    return this.conversationsService.archive(req.user.userId, id);
  }

  @Post(':id/pin')
  @ApiOperation({ summary: 'Pin a conversation' })
  pin(@Request() req: any, @Param('id') id: string) {
    return this.conversationsService.pin(req.user.userId, id);
  }
}
