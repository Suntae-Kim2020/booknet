# Booknet

책을 등록·관리하고, 다 읽은 책을 판매 꾸러미로 묶어 내놓고, 독서토론 모임을 찾고, 한 줄 평을 남기고 음성으로 읽어주는 **Flutter 기반 안드로이드/iOS 앱**.

## 주요 기능

- 도서 등록
  - ISBN 바코드 스캔 (`mobile_scanner`)
  - 키워드 검색 (네이버 책 검색 API)
- 내 책장
  - 읽음 / 안 읽음 표시
  - 판매 중 표시
  - 독서토론 희망 표시
- 판매
  - 여러 책을 묶어 **꾸러미** 단위로 판매
- 독서토론
  - 책 / 지역 / 온·오프라인으로 검색
- 한 줄 평
  - 작성, 목록
  - **TTS로 읽어주기** (`flutter_tts`, ko-KR)

## 기술 스택

- **Flutter** (Material 3, Riverpod, go_router)
- **Supabase** (Auth + Postgres + RLS)
- **네이버 책 검색 API** (도서 메타데이터)
- `mobile_scanner`, `flutter_tts`, `dio`

## 최초 설정

이 저장소에는 Flutter 소스(`lib/`)와 `pubspec.yaml`만 들어 있습니다. 안드로이드/iOS 플랫폼 폴더는 `flutter create`로 생성하세요.

```bash
# 1) Flutter SDK 설치 (https://docs.flutter.dev/get-started/install)
flutter --version

# 2) 플랫폼 폴더 생성 (현재 디렉토리에 android/, ios/ 추가)
flutter create . --project-name booknet --org io.booknet --platforms=android,ios

# 3) 의존성 설치
flutter pub get

# 4) 환경변수 파일
cp .env.example .env
# .env에 SUPABASE_URL / SUPABASE_ANON_KEY / NAVER_CLIENT_ID / NAVER_CLIENT_SECRET 입력

# 5) Supabase 프로젝트 만들고 docs/supabase_schema.sql 실행

# 6) 실행
flutter run
```

### 권한 (수동 추가 필요)

`flutter create` 후 다음 권한을 추가하세요.

**Android — `android/app/src/main/AndroidManifest.xml`**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

**iOS — `ios/Runner/Info.plist`**
```xml
<key>NSCameraUsageDescription</key>
<string>ISBN 바코드 스캔에 사용합니다.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>가까운 독서 토론을 찾는 데 사용합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>음성 기능을 위해 사용합니다.</string>
```

## 디렉토리 구조

```
lib/
  main.dart              # 진입점, dotenv, Supabase init
  app.dart               # MaterialApp.router
  router.dart            # go_router 설정
  theme.dart
  providers.dart         # Riverpod providers
  models/                # Book, SaleBundle, Discussion, Review
  services/              # naver_book_api, supabase_repository, tts_service
  features/
    home/                # 하단 탭 셸
    library/             # 내 책장
    search/              # 도서 검색 / ISBN 스캔
    book_detail/         # 책 상세 (읽음/판매/토론 토글)
    marketplace/         # 판매 꾸러미
    discussion/          # 독서토론 검색
    reviews/             # 한 줄 평 + TTS
docs/
  supabase_schema.sql    # DB 스키마 + RLS
```

## 개발 메모

- 인증은 아직 구현 전 — `owner_id`/`user_id`는 `auth.uid()` 적용 필요
- 한 줄 평 작성 화면에 책 선택 UI 미구현 (TODO)
- Supabase realtime / 푸시 알림 미구현
