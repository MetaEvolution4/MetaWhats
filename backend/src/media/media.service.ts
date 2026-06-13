import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class MediaService {
  constructor(private readonly prisma: PrismaService) {}

  async saveMediaRecord(userId: string, file: Express.Multer.File) {
    // Generate public URL (for local MVP, we serve it via a static route, e.g., /uploads/...)
    // In production, this would be an S3 URL
    const publicUrl = `/uploads/${file.filename}`;
    
    // For MVP we just use the path where it was saved
    const storagePath = file.path;

    return this.prisma.mediaFile.create({
      data: {
        owner_user_id: userId,
        original_name: file.originalname,
        mime_type: file.mimetype,
        size_bytes: file.size,
        storage_path: storagePath,
        public_url: publicUrl,
        // duration_seconds: null // would be extracted with ffprobe for audio/video
      }
    });
  }

  async getMedia(id: string) {
    const media = await this.prisma.mediaFile.findUnique({ where: { id } });
    if (!media) throw new NotFoundException('Media not found');
    return media;
  }
}
