# admin-ui-flutter

Flutter admin UI, адаптированный под bearer-auth backend.

## Запуск

```bash
flutter create . --platforms=web,android
flutter pub get
flutter run -d chrome --dart-define=CONFIGURATOR_API_BASE_URL=http://localhost:8080
```

Для Android emulator:

```bash
flutter run -d emulator-5554 --dart-define=CONFIGURATOR_API_BASE_URL=http://10.0.2.2:8080
```
