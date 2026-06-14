import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ContactsModule } from './contacts/contacts.module';
import { ConversationsModule } from './conversations/conversations.module';
import { MessagesModule } from './messages/messages.module';
import { MediaModule } from './media/media.module';
import { DevicesModule } from './devices/devices.module';
import { PushModule } from './push/push.module';
import { EventsModule } from './events/events.module';

@Module({
  imports: [PrismaModule, AuthModule, UsersModule, ContactsModule, ConversationsModule, MessagesModule, MediaModule, EventsModule, DevicesModule, PushModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
