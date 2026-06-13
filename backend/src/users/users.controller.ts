import { Controller, Get, Patch, Post, Body, UseGuards, Request, Param } from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current logged in user from token' })
  getMe(@Request() req: any) {
    return this.usersService.findById(req.user.userId);
  }

  @Get(':id/public-key')
  @ApiOperation({ summary: 'Get another users public key for E2EE' })
  getPublicKey(@Param('id') id: string) {
    return this.usersService.getPublicKey(id);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update my profile' })
  updateMe(@Request() req: any, @Body() dto: UpdateUserDto) {
    return this.usersService.update(req.user.userId, dto);
  }

  // Avatar upload will be handled by media module and just update the URL here, 
  // or we could do it here. For MVP, we'll let the user provide the URL after uploading.
  @Post('avatar')
  @ApiOperation({ summary: 'Update avatar URL' })
  updateAvatar(@Request() req: any, @Body('avatarUrl') avatarUrl: string) {
    return this.usersService.updateAvatar(req.user.userId, avatarUrl);
  }
}
