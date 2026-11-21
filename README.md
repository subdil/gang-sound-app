# GangSound
backend/  Express + Socket.IO + MongoDB  (deploy on its own)
frontend/ Flutter app: Android, Windows, Web, Linux, macOS (deploy on its own)

## Backend
cd backend && cp example.env .env   # fill in values
npm install && npm start

## Frontend
flutter create --platforms=android,windows,web,linux,macos gangsound_app
copy frontend/lib and frontend/pubspec.yaml over the generated ones, then:
set apiUrl in lib/config.dart (or --dart-define=API_URL=https://your-api)
follow ANDROID_SETUP.md, then: flutter pub get && flutter run
Web needs https (browsers block audio capture on plain http, except localhost).
"# gang-sound-app" 
