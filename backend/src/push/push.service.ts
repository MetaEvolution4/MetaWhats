import { Injectable, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor() {
    // In production, Firebase config should come from env or google-services.json
    // For now we try to initialize with default app if GOOGLE_APPLICATION_CREDENTIALS is set
    try {
      if (!admin.apps.length) {
        admin.initializeApp();
      }
    } catch (e) {
      this.logger.error('Failed to initialize Firebase Admin SDK. Did you set GOOGLE_APPLICATION_CREDENTIALS?', e);
    }
  }

  async sendPushToDevices(tokens: string[], conversationId: string) {
    if (!tokens || tokens.length === 0) return;
    if (!admin.apps.length) return; // If not initialized, skip

    try {
      const message = {
        tokens,
        notification: {
          title: 'MetaWhats',
          body: 'Nova mensagem', // NO SENSITIVE DATA
        },
        data: {
          conversationId,
          type: 'new_message'
        },
        android: {
          priority: 'high' as const,
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true,
            }
          }
        }
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      this.logger.log(`FCM send results: ${response.successCount} success, ${response.failureCount} failures`);
      
      // Cleanup invalid tokens could be done here based on response.responses
    } catch (error) {
      this.logger.error('Error sending FCM', error);
    }
  }
}
