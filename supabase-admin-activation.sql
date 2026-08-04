-- 안전운전 캠페인 관리자 기능 활성화
-- 기존 참여자/응답 데이터는 삭제하지 않습니다.

begin;

alter table public.participants
  add column if not exists region text,
  add column if not exists regional_headquarters text;

-- RLS 정책은 초기 설정 SQL의 is_admin() 검사를 그대로 사용합니다.
-- 테이블 권한과 RLS를 모두 통과한 관리자만 아래 작업이 가능합니다.
grant select, insert, update, delete on table public.participants to authenticated;
grant select, update on table public.missions to authenticated;
grant select on table public.responses to authenticated;
grant select on table public.attendance to authenticated;
grant select on table public.admins to authenticated;
grant select, insert on table public.admin_logs to authenticated;

commit;

-- =========================================================
-- 관리자 계정 등록 방법
-- 1. Supabase Dashboard > Authentication > Users에서
--    이메일/비밀번호 관리자 사용자를 먼저 생성합니다.
-- 2. 아래 ADMIN_EMAIL_HERE를 실제 이메일로 바꾼 뒤
--    insert 문만 선택해서 실행합니다.
-- =========================================================

-- insert into public.admins (auth_user_id, admin_role, active_status)
-- select id, 'super', true
-- from auth.users
-- where lower(email) = lower('n.hong@bgf.co.kr')
-- on conflict (auth_user_id)
-- do update set admin_role = 'super', active_status = true;

