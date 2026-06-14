import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { MessagesService } from './messages.service';
import { SendMessageDto, UpdateMessageDto, ReactMessageDto } from './dto/message.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';

@ApiTags('messages')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Get('conversations/:id/messages')
  @ApiOperation({ summary: 'Get messages for a conversation' })
  getMessages(@Request() req: any, @Param('id') id: string) {
    return this.messagesService.getMessages(req.user.userId, id);
  }

  @Post('conversations/:id/messages')
  @ApiOperation({ summary: 'Send a message' })
  send(@Request() req: any, @Param('id') id: string, @Body() dto: SendMessageDto) {
    return this.messagesService.send(req.user.userId, id, dto);
  }

  @Patch('messages/:id')
  @ApiOperation({ summary: 'Edit a message' })
  edit(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateMessageDto) {
    return this.messagesService.edit(req.user.userId, id, dto);
  }

  @Delete('messages/:id')
  @ApiOperation({ summary: 'Delete message for everyone' })
  deleteForEveryone(@Request() req: any, @Param('id') id: string) {
    return this.messagesService.deleteForEveryone(req.user.userId, id);
  }

  @Post('messages/:id/read')
  @ApiOperation({ summary: 'Mark message as read' })
  read(@Request() req: any, @Param('id') id: string) {
    return this.messagesService.read(req.user.userId, id);
  }

  @Post('messages/:id/delivered')
  @ApiOperation({ summary: 'Mark message as delivered' })
  delivered(@Request() req: any, @Param('id') id: string) {
    return this.messagesService.delivered(req.user.userId, id);
  }

  @Post('messages/:id/reaction')
  @ApiOperation({ summary: 'Add a reaction' })
  react(@Request() req: any, @Param('id') id: string, @Body() dto: ReactMessageDto) {
    return this.messagesService.react(req.user.userId, id, dto);
  }

  @Delete('messages/:id/reaction')
  @ApiOperation({ summary: 'Remove a reaction' })
  removeReaction(@Request() req: any, @Param('id') id: string, @Body('emoji') emoji: string) {
    return this.messagesService.removeReaction(req.user.userId, id, emoji);
  }
}
