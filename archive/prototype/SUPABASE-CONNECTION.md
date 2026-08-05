# Supabase 연결 확인

이 버전의 `index.html`은 다음 기능을 Supabase에 연결합니다.

- 사번 조회: `lookup_participant`
- 익명 인증 후 참여자 확인: `confirm_participant`
- 현재 참여자 복원: `current_participant`
- 미션 목록 및 공개 정보 조회: `missions`
- 참여 현황 복원: `attendance`, `responses`
- 미션 제출·정답 판정·출석 저장: `submit_mission`

## 최초 1회 설정

1. 기존 초기화 SQL을 아직 실행하지 않았다면 먼저 실행합니다. 운영 데이터가 생긴 뒤에는 초기화 SQL을 다시 실행하지 마세요.
2. `supabase-v5-update.sql`을 SQL Editor에서 1회 실행합니다.
3. Supabase Dashboard → Authentication → Sign In / Providers에서 Anonymous Sign-Ins를 활성화합니다.
4. 테스트 사번 `2610100`으로 로그인, 미션 제출, 새로고침 후 진행률 복원을 확인합니다.
5. 운영 전 DAY 01~10의 `open_at`, `close_at`을 실제 캠페인 기간으로 변경합니다.

## 보안 및 운영 주의

- HTML에 포함된 값은 publishable key뿐이며 service role key는 넣지 않습니다.
- 사내 공용망에서는 많은 사용자가 같은 공인 IP로 접속할 수 있습니다. Anonymous Sign-In의 IP 기준 제한을 운영 규모에 맞춰 조정하고 Turnstile을 적용하세요.
- `admin.html`은 Supabase 관리자 인증과 실제 참여·응답 데이터에 연결되어 있습니다.
- 기존 프로젝트에서는 `supabase-admin-activation.sql`을 먼저 실행하고, Authentication 사용자 UUID를 `admins`에 등록해야 합니다.
- 새 프로젝트에서는 `supabase-initial-setup.sql`을 먼저 실행한 뒤 관리자 활성화 SQL을 실행합니다.
