import { IsNotEmpty, IsString, IsArray, ArrayMinSize } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateDirectConversationDto {
  @ApiProperty({ example: 'uuid-of-the-other-user' })
  @IsNotEmpty()
  @IsString()
  userId: string;
}

export class CreateGroupConversationDto {
  @ApiProperty({ example: 'My Awesome Group' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiProperty({ type: [String], example: ['uuid-1', 'uuid-2'] })
  @IsArray()
  @IsString({ each: true })
  @ArrayMinSize(1)
  userIds: string[];
}
