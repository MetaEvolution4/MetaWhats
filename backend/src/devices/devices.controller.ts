import { Controller, Post, Body, Get, Param, UseGuards, Request } from '@nestjs/common';
import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/device.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('devices')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/devices')
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Post('register')
  async registerDevice(@Body() dto: RegisterDeviceDto, @Request() req: any) {
    return this.devicesService.registerDevice(req.user.userId, dto);
  }

  @Get('bundle/:userId')
  async getPreKeyBundle(@Param('userId') userId: string) {
    return this.devicesService.getPreKeyBundle(userId);
  }
}
