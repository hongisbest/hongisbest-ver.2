# 관리자 화면 활성화 순서

## 1. 관리자 권한 SQL

Supabase SQL Editor에서 `supabase-admin-activation.sql`의 `begin;`부터 `commit;`까지 실행합니다.

## 2. 관리자 로그인 계정 생성

Supabase Dashboard의 `Authentication > Users`에서 관리자 이메일과 비밀번호 사용자를 생성합니다.

## 3. admins 권한표 등록

`supabase-admin-activation.sql` 아래쪽의 주석 처리된 `insert into public.admins` 구문에서 `ADMIN_EMAIL_HERE`를 방금 생성한 실제 이메일로 바꿉니다. 해당 insert 구문의 `--`를 제거하고 SQL Editor에서 실행합니다.

## 4. 관리자 화면 확인

배포 주소 뒤에 `/admin.html`을 붙여 접속한 뒤 생성한 이메일과 비밀번호로 로그인합니다.

활성화되는 기능:

- 전체 참여자·오늘 참여자·평균 완료 미션·완주자 집계
- DAY별 참여 인원과 전체 진행률
- 지역본부별 순위·참가자 수·출석률·완주자 수
- 권역·지역본부·진행상태·성함/사번 필터
- 참여자 단건 등록과 Excel/CSV 일괄 등록
- 참여현황·응답 데이터 Excel 다운로드
- 미션별 참여율·정답률·응답 내용
- 미션 공개일·마감일·활성 상태 저장

브라우저에는 publishable key만 포함되어 있습니다. 관리자 권한은 Supabase 로그인 사용자 UUID와 `admins` 표, RLS 정책으로 검사합니다.

