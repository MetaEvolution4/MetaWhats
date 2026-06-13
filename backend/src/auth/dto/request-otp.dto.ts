import { IsNotEmpty, IsPhoneNumber, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RequestOtpDto {
  @ApiProperty({ example: '+5511999999999' })
  @IsNotEmpty()
  @IsString()
  phone: string;
}
