import { Module } from '@nestjs/common';
import { MessagesController } from './messages.controller';
import { MessagesService } from './messages.service';
import { PrismaModule } from '../prisma/prisma.module';
import { EventsModule } from '../events/events.module';
import { PushModule } from '../push/push.module';

@Module({
  imports: [PrismaModule, EventsModule, PushModule],
  controllers: [MessagesController],
  providers: [MessagesService]
})
export class MessagesModule {}
