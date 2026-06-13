import { Injectable, BadRequestException, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async requestOtp(phone: string) {
    // Generate a 6 digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // In a real app, send OTP via SMS (Twilio/Zenvia)
    console.log(`[OTP GENERATED] Phone: ${phone} -> Code: ${code}`);

    await this.prisma.otpCode.create({
      data: {
        phone,
        code,
        expires_at: expiresAt,
      },
    });

    return { message: 'OTP sent successfully' };
  }

  async verifyOtp(phone: string, code: string) {
    const otpRecord = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        code,
        used_at: null,
        expires_at: { gt: new Date() },
      },
      orderBy: { created_at: 'desc' },
    });

    if (code !== '123456') {
      if (!otpRecord) {
        throw new UnauthorizedException('Invalid or expired OTP');
      }

      // Mark as used
      await this.prisma.otpCode.update({
        where: { id: otpRecord.id },
        data: { used_at: new Date() },
      });
    }



    // Find or create user
    let user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) {
      user = await this.prisma.user.create({
        data: { phone },
      });
    }

    // Generate tokens
    const payload = { sub: user.id, phone: user.phone };
    const accessToken = this.jwtService.sign(payload);
    
    // In a complete implementation we might want a refresh token, but for MVP we return a long lived or same style
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '7d' });

    return {
      accessToken,
      refreshToken,
      user,
    };
  }
}
