import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateUserDto {
  @ApiPropertyOptional({ example: 'John Doe' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ example: 'Available' })
  @IsOptional()
  @IsString()
  status_message?: string;

  @ApiPropertyOptional({ example: 'base64-encoded-public-key' })
  @IsOptional()
  @IsString()
  public_key?: string;
}
