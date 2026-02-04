# Loder

Collaborative macOS приложение для меню-бара с room-based системой, которое показывает активность пользователей в реальном времени. Пользователи могут создавать комнаты, приглашать коллег и видеть, когда кто-то активно работает.

## Версия: 1.3.0

### Новые функции
- **Statistics Window**: Glassmorphism дизайн, frameless окно с custom title bar
- **Settings Window**: Управление аватаром, logout, удаление аккаунта
- **Focus Mode**: Скрыть свой статус от других участников
- **Account Deletion**: Анонимизация данных при удалении аккаунта

## Технологии

### Клиент (macOS)
- **Язык**: Swift 5.0
- **Фреймворк**: SwiftUI + AppKit
- **Платформа**: macOS 13.0+
- **Bundle ID**: `com.kedicode.loder`

### Сервер (Python)
- **Фреймворк**: Flask
- **БД**: SQLite
- **URL**: `https://loder.kedicode.cloud/api/v1`

## Структура клиента

```
Loder/
├── LoderApp.swift              # Точка входа, AppDelegate, NSPopover
├── ActivityMonitor.swift       # Мониторинг foreground app + idle time
├── Info.plist                  # Конфигурация приложения
├── Media.xcassets              # Ресурсы
│
├── Models/
│   ├── User.swift              # Модель пользователя
│   ├── Room.swift              # Модель комнаты
│   ├── Participant.swift       # Модель участника (+ focusMode)
│   └── Statistics.swift        # Модели статистики
│
├── Services/
│   ├── APIClient.swift         # HTTP клиент для API
│   ├── UserService.swift       # Регистрация, аватар, удаление
│   ├── RoomService.swift       # CRUD комнат, статистика
│   └── HeartbeatService.swift  # Polling каждые 5 сек
│
├── Views/
│   ├── PopoverContentView.swift  # Контейнер для popover
│   ├── RegistrationView.swift    # Экран регистрации
│   ├── LobbyView.swift           # Лобби (без комнаты)
│   ├── RoomView.swift            # Экран комнаты
│   ├── AvatarUploadView.swift    # Загрузка аватара
│   ├── AvatarView.swift          # Компонент аватара
│   ├── AvatarStackView.swift     # Стек аватаров для меню-бара
│   ├── StatisticsWindow.swift    # Окно статистики (frameless, dock icon)
│   └── SettingsWindow.swift      # Окно настроек
│
└── Utilities/
    ├── DeviceIdentifier.swift  # Hardware UUID
    ├── AppState.swift          # ObservableObject синглтон (+ focusMode)
    └── ImageCache.swift        # Кэширование аватаров
```

## Структура сервера

```
loder-server/
├── app.py              # Точка входа Flask
├── config.py           # Конфигурация
├── database.py         # SQLite setup
├── models.py           # Dataclasses
├── requirements.txt    # Зависимости
├── routes/
│   ├── users.py        # /api/v1/users/* (+ DELETE для удаления)
│   └── rooms.py        # /api/v1/rooms/* (+ focusMode)
├── utils/
│   └── room_id.py      # Генерация 7-char ID
└── avatars/            # Хранение аватаров
```

## Поведение меню-бара

| Состояние | Отображение | Действие по клику |
|-----------|-------------|-------------------|
| Не зарегистрирован | 🔑 | Открыть popover, авто-регистрация |
| Лобби (без комнаты) | "zzz" | Открыть popover с опциями |
| В комнате (активные) | Аватары | Открыть popover со списком |
| Focus Mode | Скрыт | Статус не показывается другим |

## API Endpoints

### Пользователи
- `POST /users/register` — регистрация по deviceId
- `POST /users/{id}/avatar` — загрузка аватара (multipart)
- `GET /users/{id}/avatar` — получение аватара
- `DELETE /users/{id}` — удаление аккаунта с анонимизацией данных

### Комнаты
- `POST /rooms/create` — создание комнаты (+ password)
- `GET /rooms/{id}/check` — проверка существования и пароля
- `POST /rooms/{id}/join` — присоединение к комнате (+ password)
- `POST /rooms/{id}/leave` — выход из комнаты
- `GET /rooms/{id}` — информация о комнате
- `POST /rooms/{id}/heartbeat` — отправка статуса (+ focusMode)
- `GET /rooms/{id}/stats` — статистика комнаты

## Мониторинг активности

Приложение отслеживает:
1. **Foreground app** — текущее активное приложение через `NSWorkspace`
2. **Idle time** — время простоя через IOKit HIDIdleTime
3. **Focus Mode** — скрытие статуса от других участников

**Алгоритм:**
- Если idle > 5 секунд → показывает "Idle"
- Если Focus Mode включен → статус скрыт, данные не логируются
- Иначе → показывает название foreground app

## Сборка (Development)

```bash
xcodebuild -scheme Loder -configuration Debug build
```

Или открыть `Loder.xcodeproj` в Xcode и собрать (Cmd+B).

## Дистрибуция (Release)

### Требования
- **Сертификат**: Developer ID Application: Arbi Bashaev (6355K3CJ5C)
- **Keychain Profile**: `loder-notarization` (для notarytool)
- **Hardened Runtime**: Включен
- **Notarization**: Обязательно для распространения

### Сборка Release

```bash
xcodebuild -scheme Loder -configuration Release -derivedDataPath build \
  CODE_SIGN_IDENTITY="Developer ID Application: Arbi Bashaev (6355K3CJ5C)" \
  CODE_SIGN_STYLE="Manual" \
  DEVELOPMENT_TEAM="6355K3CJ5C" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--options runtime --timestamp" \
  clean build
```

### Notarization

```bash
# Создать ZIP
ditto -c -k --keepParent build/Build/Products/Release/Loder.app Loder-notarize.zip

# Отправить на notarization
xcrun notarytool submit Loder-notarize.zip --keychain-profile "loder-notarization" --wait

# Staple ticket
xcrun stapler staple build/Build/Products/Release/Loder.app
```

### Создание DMG

```bash
rm -rf dmg_temp && mkdir dmg_temp
cp -R build/Build/Products/Release/Loder.app dmg_temp/
ln -s /Applications dmg_temp/Applications
hdiutil create -volname "Loder" -srcfolder dmg_temp -ov -format UDZO Loder.dmg
rm -rf dmg_temp Loder-notarize.zip
```

### Проверка подписи

```bash
# Проверить Gatekeeper
spctl -a -vvv -t install build/Build/Products/Release/Loder.app

# Ожидаемый результат:
# accepted
# source=Notarized Developer ID
```

### Настройка Keychain Profile (один раз)

```bash
xcrun notarytool store-credentials "loder-notarization" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "6355K3CJ5C"
```

App-Specific Password создаётся на [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords.

## Сервер (Docker на kedicode)

Сервер запущен в Docker контейнере:

```bash
# Расположение
/root/containers/loder/

# Управление
ssh kedicode
cd /root/containers/loder
docker-compose up -d      # Запуск
docker-compose down       # Остановка
docker-compose logs -f    # Логи
docker-compose build      # Пересборка

# Данные хранятся в Docker volume
docker volume inspect loder_data
```

### Структура контейнеров на сервере

| Домен | Контейнер | Порт |
|-------|-----------|------|
| loder.kedicode.cloud | loder | 5000 |
| kedicode.cloud | (host) | - |

## Зависимости

### Клиент
- Foundation, SwiftUI, AppKit, Charts
- IOKit (для Hardware UUID и Idle Time)
- NSWorkspace (для Foreground App)

### Сервер
- Flask 3.0.0
- Flask-CORS 4.0.0
- Gunicorn 21.2.0
