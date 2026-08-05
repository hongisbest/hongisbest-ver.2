-- =========================================================
-- 하루 30초 안전운전 챌린지 · MAIN 운영 전 점검
-- 기존 데이터를 변경하지 않는 조회 전용 스크립트입니다.
-- Supabase SQL Editor에서 실행해 운영 준비 상태를 확인하세요.
-- =========================================================

-- 1. 필수 테이블 존재 여부
select required.table_name,
       to_regclass('public.' || required.table_name) is not null as ready
from (values
  ('participants'),
  ('missions'),
  ('participant_sessions'),
  ('responses'),
  ('attendance'),
  ('admins'),
  ('admin_logs')
) as required(table_name);

-- 2. 실제 참여자와 미션 수
select
  (select count(*) from public.participants where employment_status = '재직') as active_participants,
  (select count(*) from public.missions) as mission_count,
  (select count(*) from public.admins where active_status = true) as active_admins;

-- 3. 미션 공개 일정 유효성
select mission_day, mission_title, open_at, close_at, active_status,
       close_at > open_at as schedule_valid
from public.missions
order by mission_day;

-- 4. 중복 사번 확인: 결과가 없어야 정상
select employee_number, count(*)
from public.participants
group by employee_number
having count(*) > 1;

-- 5. 참여자와 연결되지 않은 응답 확인: 결과가 없어야 정상
select r.response_id
from public.responses r
left join public.participants p on p.participant_id = r.participant_id
left join public.missions m on m.mission_id = r.mission_id
where p.participant_id is null or m.mission_id is null;

-- 6. 현재 데이터 규모
select
  pg_size_pretty(pg_total_relation_size('public.participants')) as participants_size,
  pg_size_pretty(pg_total_relation_size('public.responses')) as responses_size,
  pg_size_pretty(pg_total_relation_size('public.attendance')) as attendance_size;

