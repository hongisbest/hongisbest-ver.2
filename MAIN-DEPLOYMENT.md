# 안전운전 캠페인 MAIN 운영본

이 폴더는 프로토타입이 아닌 실제 운영용 작업본입니다.

## 운영 전 필수 확인

1. `assets/config.js`의 Supabase 프로젝트 URL과 Publishable Key를 확인합니다.
2. Supabase Authentication에서 Anonymous Sign-Ins가 활성화되어 있는지 확인합니다.
3. 관리자 사용자가 `admins` 테이블에 활성 상태로 등록되어 있는지 확인합니다.
4. 관리자 화면에서 실제 참여자 엑셀을 업로드합니다.
5. `supabase-main-production-check.sql`을 실행해 테이블, 미션 10개, 관리자와 일정 상태를 확인합니다.
6. 관리자 화면에서 미션 공개·마감 시간을 실제 운영 일정으로 저장합니다.
7. 참여자 사번으로 로그인, 제출, 재접속, 진행률 복원까지 점검합니다.

## 배포 대상

Cloudflare에 필요한 웹 파일은 다음과 같습니다.

- `index.html`
- `admin.html`
- `assets/` 전체

SQL과 Markdown 문서는 웹 실행 파일이 아니므로 Cloudflare 정적 자산에 포함할 필요가 없습니다.

## 보안 원칙

- Publishable Key는 브라우저에 포함되어도 되는 공개 키입니다.
- Service Role Key와 관리자 비밀번호는 GitHub 및 HTML/JavaScript에 저장하지 않습니다.
- 관리자 권한은 Supabase Auth 사용자와 `admins` 테이블, RLS 정책으로 확인합니다.
- 기존 운영 데이터가 들어간 뒤에는 `archive/prototype/supabase-initial-setup.sql`을 다시 실행하지 않습니다.

## 다음 적용 예정

- 동시 참여자 600명 입장 제한
- Supabase 요청 통합 및 캐시
- 요청 분산과 재시도 대기 화면
- 관리자 동시접속 현황과 제한 인원 설정
