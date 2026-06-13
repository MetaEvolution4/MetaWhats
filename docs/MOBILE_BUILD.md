# Mobile Build e Push Notifications

## Android

### Build Debug / APK
Para testar a aplicação em um dispositivo Android sem publicá-la:
```bash
cd mobile
flutter build apk --debug
```
O arquivo APK será gerado em `build/app/outputs/flutter-apk/app-debug.apk`.

### Build Release / AAB
Para publicar a aplicação na Google Play Store, você precisa gerar um App Bundle assinado.
1. Crie um arquivo `key.properties` dentro de `android/` referenciando sua keystore (conforme documentação do Flutter).
2. Execute:
```bash
flutter build appbundle
```
O arquivo estará em `build/app/outputs/bundle/release/app-release.aab`.

### Permissões Android
Certifique-se de que `android/app/src/main/AndroidManifest.xml` contenha as seguintes permissões necessárias para mensagens e mídia:
- `INTERNET`
- `CAMERA`
- `RECORD_AUDIO`
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`

## iOS

### Build iOS
1. Abra um terminal no Mac.
2. Navegue para `mobile/ios` e instale as dependências:
```bash
cd mobile/ios
pod install
```
3. Abra o Xcode:
```bash
open Runner.xcworkspace
```
4. Na aba de `Signing & Capabilities`, configure o `Team` com sua conta Apple Developer.
5. Para gerar arquivo, no Flutter use:
```bash
flutter build ios --release
```
Isso compilará o `.app`. Para `.ipa` (App Store), faça o *Archive* via Xcode.

### Permissões Info.plist
As descrições (Privacy notes) precisam estar claras sobre o porquê o aplicativo usa câmera ou microfone, ou a Apple rejeitará o aplicativo.

## Notificações Push (Preparação)
Para a próxima fase do projeto (Firebase Cloud Messaging):
1. Acesse o [Console do Firebase](https://console.firebase.google.com).
2. Crie um novo projeto "MetaWhats".
3. Adicione o app Android e iOS, faça o download do `google-services.json` (para Android) e do `GoogleService-Info.plist` (para iOS).
4. No backend, usaremos a biblioteca `firebase-admin` do Node.js.
5. A cada novo login, o App enviará para `/api/users/me` (ou rota similar de tokens) o device FCM Token. O NestJS atualizará isso no model `PushToken`.
