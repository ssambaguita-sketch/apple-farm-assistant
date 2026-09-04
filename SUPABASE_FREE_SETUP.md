# Supabase 무료 DB 연결 (휴대폰만 사용)

목표: Render 무료 서버가 재시작되어도 과수원/작업/관찰/재무/코치 기록이 사라지지 않게 PostgreSQL에 저장합니다.

## 1. Supabase 프로젝트 만들기
1. https://supabase.com 에 GitHub로 로그인합니다.
2. New project를 누릅니다.
3. 프로젝트 이름 예: apple-farm-assistant-db
4. 강력한 Database Password를 설정하고 별도 보관합니다.
5. Region은 한국과 가까운 리전을 선택합니다.

## 2. 연결 문자열 복사
1. Supabase 프로젝트 → Connect 또는 Database → Connection string으로 이동합니다.
2. Render에서 쓰기 위해 Shared Pooler의 Session mode 연결 문자열을 권장합니다.
3. 형식 예시:
   postgresql://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.com:5432/postgres
4. PASSWORD 부분에 실제 DB 비밀번호가 들어가야 합니다.

중요: 이 DATABASE_URL은 공개 GitHub 코드나 Flutter 앱에 넣지 마세요.

## 3. Render에 DATABASE_URL 등록
1. Render Dashboard → apple-farm-assistant-api 서비스 선택
2. Environment 탭
3. DATABASE_URL 값에 Supabase 연결 문자열 입력
4. Save Changes 후 재배포

## 4. 정상 동작 확인
브라우저에서 다음 주소를 엽니다.
https://YOUR-RENDER-URL/health

정상이면 JSON에 아래와 비슷하게 표시됩니다.
- ok: true
- database: postgresql
- database_ok: true

## 5. 앱 연결
새 APK 설치 후:
1. 설정 탭
2. 클라우드 서버 URL에 Render 주소 입력
3. 저장하고 연결 테스트
4. 서버 연결 성공 확인

## 무료 플랜 주의사항
- Supabase Free는 500MB DB 용량 제한이 있습니다.
- 활동이 매우 적으면 무료 프로젝트가 일시 정지될 수 있습니다.
- Render Free Web Service는 15분 비활동 후 잠들며 첫 요청 시 다시 깨어납니다.
