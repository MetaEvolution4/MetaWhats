import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDeviceDto } from './dto/device.dto';

@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    // Para simplificar a Fase 3 e manter "1 usuário = 1 dispositivo", apagamos dispositivos antigos do usuário
    await this.prisma.device.deleteMany({ where: { user_id: userId } });

    // Criar o novo dispositivo com chaves Signal
    const device = await this.prisma.device.create({
      data: {
        user_id: userId,
        fcm_token: dto.fcm_token,
        platform: dto.platform,
        registration_id: dto.registration_id,
        identity_key: dto.identity_key,
        signed_pre_key: dto.signed_pre_key,
        signed_signature: dto.signed_signature,
        signed_key_id: dto.signed_key_id,
        pre_keys: {
          create: dto.pre_keys.map(pk => ({
            key_id: pk.key_id,
            public_key: pk.public_key,
          }))
        }
      }
    });
    return device;
  }

  async getPreKeyBundle(userId: string) {
    // Obter o bundle de chaves do destinatário
    const device = await this.prisma.device.findFirst({
      where: { user_id: userId },
      include: {
        pre_keys: {
          take: 1, // Pega uma One-Time PreKey
        }
      },
      orderBy: { created_at: 'desc' }
    });

    if (!device) throw new NotFoundException('Device not found or not provisioned for E2EE');

    const preKey = device.pre_keys[0];

    // Remove a One-Time PreKey usada (se houver) para Perfect Forward Secrecy
    if (preKey) {
      await this.prisma.preKey.delete({ where: { id: preKey.id } });
    }

    return {
      registration_id: device.registration_id,
      device_id: device.id,
      identity_key: device.identity_key,
      signed_pre_key: device.signed_pre_key,
      signed_signature: device.signed_signature,
      signed_key_id: device.signed_key_id,
      pre_key: preKey ? {
        key_id: preKey.key_id,
        public_key: preKey.public_key,
      } : null
    };
  }
}
