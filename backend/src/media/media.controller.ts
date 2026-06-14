import { Controller, Post, Get, Param, UseInterceptors, UploadedFile, UseGuards, Request, BadRequestException, Res } from '@nestjs/common';
import type { Response } from 'express';
import { createReadStream } from 'fs';
import { MediaService } from './media.service';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { v4 as uuidv4 } from 'uuid';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiConsumes, ApiBody } from '@nestjs/swagger';

@ApiTags('media')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/media')
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Post('upload')
  @ApiOperation({ summary: 'Upload media file' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @UseInterceptors(FileInterceptor('file', {
    storage: diskStorage({
      destination: process.env.UPLOAD_DIR || './uploads',
      filename: (req, file, cb) => {
        const uniqueSuffix = uuidv4() + extname(file.originalname);
        cb(null, uniqueSuffix);
      }
    }),
    limits: { fileSize: 50 * 1024 * 1024 } // 50MB
  }))
  uploadFile(@Request() req: any, @UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    return this.mediaService.saveMediaRecord(req.user.userId, file);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get media metadata' })
  getMedia(@Param('id') id: string) {
    return this.mediaService.getMedia(id);
  }

  @Get('download/:id')
  @ApiOperation({ summary: 'Download media file' })
  async downloadMedia(@Param('id') id: string, @Res() res: Response) {
    const media = await this.mediaService.getMedia(id);
    const file = createReadStream(media.storage_path);
    res.setHeader('Content-Type', media.mime_type);
    res.setHeader('Content-Disposition', `attachment; filename="${media.original_name}"`);
    file.pipe(res);
  }
}
