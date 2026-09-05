# Android 고정 서명 설정

공식 GitHub Releases APK를 기존 앱 위에 계속 업데이트 설치하려면 동일한 Android 서명키를 모든 릴리스에 사용해야 합니다.

## 1. 로컬에서 한 번만 키 생성

```bash
keytool -genkeypair -v \
  -keystore apple-farm-release.jks \
  -alias apple-farm \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

생성한 `apple-farm-release.jks` 파일은 공개 저장소에 커밋하지 마세요. 안전한 개인 백업을 별도로 보관하세요.

## 2. keystore를 Base64로 변환

Linux/macOS:

```bash
base64 < apple-farm-release.jks | tr -d '\n'
```

Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('apple-farm-release.jks'))
```

## 3. GitHub Repository Secrets 등록

Repository → Settings → Secrets and variables → Actions → New repository secret 에 아래 4개를 등록합니다.

- `ANDROID_KEYSTORE_BASE64`: 위에서 만든 Base64 전체 문자열
- `ANDROID_KEYSTORE_PASSWORD`: keystore 비밀번호
- `ANDROID_KEY_ALIAS`: 예: `apple-farm`
- `ANDROID_KEY_PASSWORD`: key 비밀번호

## 4. 자동 적용

4개 Secret이 모두 존재하면 `.github/workflows/build-apk.yml`이 자동으로:

1. keystore 복원
2. Android release signing 설정
3. Release APK 빌드
4. APK 서명 검증
5. SHA-256 계산
6. GitHub Releases에 공식 APK 게시

Secret이 아직 없으면 빌드는 중단하지 않고 `fallback` 서명 모드로 진행합니다. 다만 fallback 모드의 APK는 향후 다른 서명으로 바뀌면 기존 앱 위에 업데이트 설치할 수 없을 수 있습니다.

## 중요

고정 서명을 처음 적용한 뒤에는 해당 keystore와 비밀번호를 잃어버리면 같은 앱 ID로 기존 설치본을 업데이트할 수 없습니다. 반드시 안전하게 백업하세요.
