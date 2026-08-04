-- 기존 참여/응답 데이터는 삭제하지 않는 v5 보정 스크립트입니다.
-- Supabase SQL Editor에서 1회 실행하세요.

begin;

update public.missions
set correct_answer = '"phone"'::jsonb,
    mission_type = 'hotspot',
    updated_at = now()
where mission_day = 4;

update public.missions
set accepted_answers = '["대중교통", "대리운전", "택시"]'::jsonb,
    updated_at = now()
where mission_day = 9;

update public.missions
set mission_title = '나의 최종 안전운전 실천 약속',
    mission_type = 'finalPledge',
    updated_at = now()
where mission_day = 10;

commit;

