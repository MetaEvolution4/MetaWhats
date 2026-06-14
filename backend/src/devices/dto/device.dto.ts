import { IsString, IsInt, IsArray, ValidateNested, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class PreKeyDto {
  @ApiProperty()
  @IsInt()
  key_id: number;

  @ApiProperty()
  @IsString()
  public_key: string;
}

export class RegisterDeviceDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  fcm_token?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  platform?: string;

  @ApiProperty()
  @IsInt()
  registration_id: number;

  @ApiProperty()
  @IsString()
  identity_key: string;

  @ApiProperty()
  @IsString()
  signed_pre_key: string;

  @ApiProperty()
  @IsString()
  signed_signature: string;

  @ApiProperty()
  @IsInt()
  signed_key_id: number;

  @ApiProperty({ type: [PreKeyDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PreKeyDto)
  pre_keys: PreKeyDto[];
}
