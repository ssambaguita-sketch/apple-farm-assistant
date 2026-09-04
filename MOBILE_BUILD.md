# 🍎 사과 재배 관리 비서 — 휴대폰 전용 APK 클라우드 빌드

컴퓨터 없이 GitHub Actions에서 APK를 자동 생성하도록 준비된 프로젝트입니다.

## 휴대폰에서 하는 일

1. GitHub 앱 또는 모바일 브라우저에서 새 저장소를 만듭니다.
   추천 이름: apple-farm-assistant

2. 프로젝트 루트에 아래 파일/폴더를 올립니다.
   - .github/workflows/build-apk.yml
   - lib/
   - backend/
   - pubspec.yaml
   - README.md
   - MOBILE_BUILD.md

3. main/master 브랜치에 업로드되면 Actions가 자동 실행됩니다.
   또는 저장소 → Actions → Build Android APK → Run workflow

4. 빌드 성공 후:
   Actions → 최근 성공 실행 → Artifacts → apple-farm-assistant-apk → 다운로드

5. ZIP을 풀어 app-release.apk를 설치합니다.

## 중요
현재 lib/services/farm_api.dart의 기본 서버 주소
http://10.0.2.2:8000 은 Android 에뮬레이터 전용입니다.
실제 휴대폰에서는 외부에서 접근 가능한 FastAPI 서버 주소로 변경해야 합니다.

KMA API 키, Telegram Bot Token, Chat ID 같은 비밀값은 앱에 넣지 말고
백엔드 서버 환경변수로 보관하세요.
