import { IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SendMessageDto {
  @ApiPropertyOptional({ example: 'Hello there!' })
  @IsOptional()
  @IsString()
  content?: string;

  @ApiProperty({ example: 'text', enum: ['text', 'image', 'audio', 'video', 'document', 'system'] })
  @IsNotEmpty()
  @IsString()
  type: string;

  @ApiPropertyOptional({ example: 'uuid-of-media' })
  @IsOptional()
  @IsString()
  media_id?: string;

  @ApiPropertyOptional({ example: 'base64-nonce' })
  @IsOptional()
  @IsString()
  nonce?: string;

  @ApiPropertyOptional({ example: 'uuid-of-message-replied-to' })
  @IsOptional()
  @IsString()
  reply_to_message_id?: string;
}

export class UpdateMessageDto {
  @ApiProperty({ example: 'Edited hello there!' })
  @IsNotEmpty()
  @IsString()
  content: string;
}

export class ReactMessageDto {
  @ApiProperty({ example: '👍' })
  @IsNotEmpty()
  @IsString()
  emoji: string;
}
