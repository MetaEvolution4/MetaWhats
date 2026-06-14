import { Module } from '@nestjs/common';
import { EventsGateway } from './events.gateway';
import { JwtModule } from '@nestjs/jwt';
import { PushModule } from '../push/push.module';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'super_secret_jwt_key_12345',
    }),
    PushModule,
  ],
  providers: [EventsGateway],
  exports: [EventsGateway],
})
export class EventsModule {}
