import { Injectable, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor() {
    try {
      if (!admin.apps.length) {
        if (process.env.FIREBASE_CREDENTIALS_JSON) {
          // Inicializa via JSON injetado no Coolify
          const serviceAccount = JSON.parse(process.env.FIREBASE_CREDENTIALS_JSON);
          admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
          });
          this.logger.log('Firebase Admin inicializado via FIREBASE_CREDENTIALS_JSON');
        } else {
          // Fallback para a variável padrão GOOGLE_APPLICATION_CREDENTIALS (caminho de arquivo)
          admin.initializeApp();
          this.logger.log('Firebase Admin inicializado via default application credentials');
        }
      }
    } catch (e) {
      this.logger.error('Falha ao inicializar o Firebase Admin SDK.', e);
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
