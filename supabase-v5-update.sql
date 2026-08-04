-- =========================================================
-- 하루 30초 안전운전 챌린지
-- Supabase 운영용 통합 초기화 스크립트
--
-- 주의:
-- 이 스크립트는 기존 테스트용 테이블과 데이터를 삭제한 뒤
-- 운영용 구조를 새로 만듭니다.
-- 실제 운영 데이터가 들어간 뒤에는 다시 실행하지 마세요.
-- =========================================================

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------
-- 1. 기존 함수와 테이블 정리
-- ---------------------------------------------------------

drop table if exists public.admin_logs cascade;
drop table if exists public.attendance cascade;
drop table if exists public.responses cascade;
drop table if exists public.participant_sessions cascade;
drop table if exists public.missions cascade;
drop table if exists public.admins cascade;
drop table if exists public.participants cascade;

drop function if exists public.submit_mission(uuid, jsonb, timestamptz, integer, text) cascade;
drop function if exists public.current_participant() cascade;
drop function if exists public.confirm_participant(text) cascade;
drop function if exists public.lookup_participant(text) cascade;
drop function if exists public.is_admin() cascade;

-- ---------------------------------------------------------
-- 2. 테이블 생성
-- ---------------------------------------------------------

create table public.participants (
  participant_id uuid primary key default gen_random_uuid(),
  employee_number text not null unique,
  employee_name text not null,
  department text,
  position text,
  workplace text,
  employment_status text not null default '재직',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint participants_employee_number_length
    check (char_length(trim(employee_number)) between 1 and 50),
  constraint participants_employee_name_length
    check (char_length(trim(employee_name)) between 1 and 100)
);

create table public.missions (
  mission_id uuid primary key default gen_random_uuid(),
  mission_day integer not null unique check (mission_day between 1 and 10),
  mission_title text not null,
  mission_type text not null,
  mission_content jsonb not null default '{}'::jsonb,
  correct_answer jsonb,
  accepted_answers jsonb,
  safety_message text not null,
  open_at timestamptz not null,
  close_at timestamptz not null,
  active_status boolean not null default true,
  allow_review boolean not null default true,
  allow_late_participation boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mission_time_check check (close_at > open_at)
);

create table public.participant_sessions (
  auth_user_id uuid primary key,
  participant_id uuid not null
    references public.participants(participant_id) on delete cascade,
  confirmed_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table public.responses (
  response_id uuid primary key default gen_random_uuid(),
  participant_id uuid not null
    references public.participants(participant_id) on delete cascade,
  mission_id uuid not null
    references public.missions(mission_id) on delete cascade,
  response_value jsonb not null,
  correct_status boolean,
  completed_status boolean not null default true,
  started_at timestamptz,
  completed_at timestamptz not null default now(),
  duration_seconds integer,
  device_type text,
  attempt_count integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (participant_id, mission_id)
);

create table public.attendance (
  attendance_id uuid primary key default gen_random_uuid(),
  participant_id uuid not null
    references public.participants(participant_id) on delete cascade,
  mission_day integer not null check (mission_day between 1 and 10),
  attendance_date date not null default current_date,
  completion_status boolean not null default true,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (participant_id, mission_day)
);

create table public.admins (
  admin_id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique,
  admin_role text not null default 'operator'
    check (admin_role in ('super', 'operator', 'viewer')),
  active_status boolean not null default true,
  created_at timestamptz not null default now(),
  last_login_at timestamptz
);

create table public.admin_logs (
  log_id bigint generated always as identity primary key,
  auth_user_id uuid,
  action_type text not null,
  details jsonb,
  created_at timestamptz not null default now()
);

create index idx_participants_employee_number
  on public.participants (upper(trim(employee_number)));

create index idx_responses_participant_id
  on public.responses (participant_id);

create index idx_responses_mission_id
  on public.responses (mission_id);

create index idx_attendance_participant_day
  on public.attendance (participant_id, mission_day);

-- ---------------------------------------------------------
-- 3. RLS 활성화
-- ---------------------------------------------------------

alter table public.participants enable row level security;
alter table public.missions enable row level security;
alter table public.participant_sessions enable row level security;
alter table public.responses enable row level security;
alter table public.attendance enable row level security;
alter table public.admins enable row level security;
alter table public.admin_logs enable row level security;

-- ---------------------------------------------------------
-- 4. 기본 권한
-- ---------------------------------------------------------

grant usage on schema public to anon, authenticated;

revoke all on table public.participants from anon, authenticated;
revoke all on table public.missions from anon, authenticated;
revoke all on table public.participant_sessions from anon, authenticated;
revoke all on table public.responses from anon, authenticated;
revoke all on table public.attendance from anon, authenticated;
revoke all on table public.admins from anon, authenticated;
revoke all on table public.admin_logs from anon, authenticated;

grant select on table public.missions to anon, authenticated;
grant select on table public.participant_sessions to authenticated;
grant select on table public.responses to authenticated;
grant select on table public.attendance to authenticated;
grant select on table public.admins to authenticated;

-- ---------------------------------------------------------
-- 5. 관리자 여부 확인 함수
-- ---------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admins as a
    where a.auth_user_id = auth.uid()
      and a.active_status = true
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------
-- 6. 사번 조회 함수
-- 로그인 전 이름 확인에 사용
-- ---------------------------------------------------------

create or replace function public.lookup_participant(p_employee_number text)
returns table (
  participant_id uuid,
  employee_number text,
  employee_name text,
  department text
)
language sql
security definer
set search_path = public
as $$
  select
    p.participant_id,
    p.employee_number,
    p.employee_name,
    p.department
  from public.participants as p
  where upper(trim(p.employee_number)) = upper(trim(p_employee_number))
    and coalesce(p.employment_status, '재직') <> '퇴직'
  limit 1;
$$;

revoke all on function public.lookup_participant(text) from public;
grant execute on function public.lookup_participant(text) to anon, authenticated;

-- ---------------------------------------------------------
-- 7. 참여자 본인 확인 함수
-- employee_number 모호성 오류 수정 완료
-- ---------------------------------------------------------

create or replace function public.confirm_participant(p_employee_number text)
returns table (
  participant_id uuid,
  employee_number text,
  employee_name text,
  department text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant public.participants%rowtype;
begin
  if auth.uid() is null then
    raise exception '로그인 세션이 없습니다.';
  end if;

  select p.*
  into v_participant
  from public.participants as p
  where upper(trim(p.employee_number)) = upper(trim(p_employee_number))
    and coalesce(p.employment_status, '재직') <> '퇴직'
  limit 1;

  if v_participant.participant_id is null then
    raise exception '등록된 참여자가 아닙니다.';
  end if;

  insert into public.participant_sessions (
    auth_user_id,
    participant_id,
    confirmed_at,
    last_seen_at
  )
  values (
    auth.uid(),
    v_participant.participant_id,
    now(),
    now()
  )
  on conflict (auth_user_id)
  do update set
    participant_id = excluded.participant_id,
    confirmed_at = now(),
    last_seen_at = now();

  return query
  select
    v_participant.participant_id,
    v_participant.employee_number,
    v_participant.employee_name,
    v_participant.department;
end;
$$;

revoke all on function public.confirm_participant(text) from public;
grant execute on function public.confirm_participant(text) to authenticated;

-- ---------------------------------------------------------
-- 8. 현재 참여자 조회 함수
-- ---------------------------------------------------------

create or replace function public.current_participant()
returns table (
  participant_id uuid,
  employee_number text,
  employee_name text,
  department text
)
language sql
security definer
set search_path = public
as $$
  select
    p.participant_id,
    p.employee_number,
    p.employee_name,
    p.department
  from public.participant_sessions as s
  join public.participants as p
    on p.participant_id = s.participant_id
  where s.auth_user_id = auth.uid()
  limit 1;
$$;

revoke all on function public.current_participant() from public;
grant execute on function public.current_participant() to authenticated;

-- ---------------------------------------------------------
-- 9. 미션 제출 함수
-- 날짜/시간 검증, 정답 판정, 출석 저장
-- ---------------------------------------------------------

create or replace function public.submit_mission(
  p_mission_id uuid,
  p_response_value jsonb,
  p_started_at timestamptz,
  p_duration_seconds integer,
  p_device_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant_id uuid;
  v_mission public.missions%rowtype;
  v_correct boolean;
  v_normalized text;
  v_answer text;
  v_existing_attempt_count integer;
begin
  select s.participant_id
  into v_participant_id
  from public.participant_sessions as s
  where s.auth_user_id = auth.uid();

  if v_participant_id is null then
    raise exception '참여자 확인이 필요합니다.';
  end if;

  select m.*
  into v_mission
  from public.missions as m
  where m.mission_id = p_mission_id
    and m.active_status = true;

  if v_mission.mission_id is null then
    raise exception '미션을 찾을 수 없습니다.';
  end if;

  if now() < v_mission.open_at then
    raise exception '아직 공개되지 않은 미션입니다.';
  end if;

  if now() > v_mission.close_at
     and not v_mission.allow_late_participation then
    raise exception '미션 참여 기간이 종료되었습니다.';
  end if;

  v_correct := null;

  if v_mission.accepted_answers is not null then
    v_normalized := regexp_replace(
      lower(coalesce(p_response_value #>> '{}', '')),
      '\s+',
      '',
      'g'
    );

    select a.value
    into v_answer
    from jsonb_array_elements_text(v_mission.accepted_answers) as a(value)
    where regexp_replace(lower(a.value), '\s+', '', 'g') = v_normalized
    limit 1;

    v_correct := v_answer is not null;

  elsif v_mission.correct_answer is not null
    and v_mission.mission_type in ('sequence', 'compare', 'hotspot') then
    v_correct := p_response_value = v_mission.correct_answer;
  end if;

  select r.attempt_count
  into v_existing_attempt_count
  from public.responses as r
  where r.participant_id = v_participant_id
    and r.mission_id = p_mission_id;

  insert into public.responses (
    participant_id,
    mission_id,
    response_value,
    correct_status,
    completed_status,
    started_at,
    completed_at,
    duration_seconds,
    device_type,
    attempt_count
  )
  values (
    v_participant_id,
    p_mission_id,
    p_response_value,
    v_correct,
    true,
    p_started_at,
    now(),
    p_duration_seconds,
    p_device_type,
    coalesce(v_existing_attempt_count, 0) + 1
  )
  on conflict (participant_id, mission_id)
  do update set
    response_value = excluded.response_value,
    correct_status = excluded.correct_status,
    completed_status = true,
    started_at = excluded.started_at,
    completed_at = now(),
    duration_seconds = excluded.duration_seconds,
    device_type = excluded.device_type,
    attempt_count = public.responses.attempt_count + 1,
    updated_at = now();

  insert into public.attendance (
    participant_id,
    mission_day,
    attendance_date,
    completion_status,
    completed_at
  )
  values (
    v_participant_id,
    v_mission.mission_day,
    (now() at time zone 'Asia/Seoul')::date,
    true,
    now()
  )
  on conflict (participant_id, mission_day)
  do nothing;

  return jsonb_build_object(
    'correct', v_correct,
    'correct_answer', v_mission.correct_answer,
    'safety_message', v_mission.safety_message,
    'mission_day', v_mission.mission_day
  );
end;
$$;

revoke all on function public.submit_mission(
  uuid, jsonb, timestamptz, integer, text
) from public;

grant execute on function public.submit_mission(
  uuid, jsonb, timestamptz, integer, text
) to authenticated;

-- ---------------------------------------------------------
-- 10. RLS 정책
-- ---------------------------------------------------------

create policy "missions_readable"
on public.missions
for select
to anon, authenticated
using (active_status = true);

create policy "participant_session_own"
on public.participant_sessions
for select
to authenticated
using (auth_user_id = auth.uid());

create policy "response_own"
on public.responses
for select
to authenticated
using (
  participant_id in (
    select s.participant_id
    from public.participant_sessions as s
    where s.auth_user_id = auth.uid()
  )
);

create policy "attendance_own"
on public.attendance
for select
to authenticated
using (
  participant_id in (
    select s.participant_id
    from public.participant_sessions as s
    where s.auth_user_id = auth.uid()
  )
);

create policy "admin_participants"
on public.participants
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admin_missions"
on public.missions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admin_responses"
on public.responses
for select
to authenticated
using (public.is_admin());

create policy "admin_attendance"
on public.attendance
for select
to authenticated
using (public.is_admin());

create policy "admin_admins"
on public.admins
for select
to authenticated
using (public.is_admin());

create policy "admin_logs"
on public.admin_logs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- ---------------------------------------------------------
-- 11. 샘플 참여자
-- ---------------------------------------------------------

insert into public.participants (
  employee_number,
  employee_name,
  department
)
values
  ('2610100', '홍가은', '경영지원'),
  ('2610101', '홍나은', '영업'),
  ('2610102', '홍다은', '물류'),
  ('2610103', '홍라은', '상품'),
  ('2610104', '홍마은', 'IT');

-- ---------------------------------------------------------
-- 12. DAY 1~10 샘플 미션
-- 테스트 기간: 실행 시점부터 30일간 전체 공개
-- 실제 운영 전 open_at, close_at을 수정하세요.
-- ---------------------------------------------------------

insert into public.missions (
  mission_day,
  mission_title,
  mission_type,
  correct_answer,
  accepted_answers,
  safety_message,
  open_at,
  close_at
)
values
  (
    1,
    '안전운전, 나를 아는 것부터 시작합니다.',
    'checklist',
    null,
    null,
    '나의 운전습관을 알아차리는 것이 안전운전의 첫걸음입니다.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    2,
    '오늘의 안전운전 암호를 풀어보세요.',
    'text',
    '"금지"'::jsonb,
    '["금지"]'::jsonb,
    '운전 중 휴대전화 사용은 금지입니다.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    3,
    '오늘의 안전운전 약속을 한 단어로 남겨주세요.',
    'pledge',
    null,
    null,
    '짧은 약속도 반복하면 안전한 습관이 됩니다.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    4,
    '이 장면에서 위험한 행동을 찾아보세요.',
    'hotspot',
    '"phone"'::jsonb,
    null,
    '운전 중 시선은 휴대전화가 아니라 도로를 향해야 합니다.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    5,
    '안전운전 문장을 완성해 주세요.',
    'text',
    '"안전거리"'::jsonb,
    '["안전거리", "안전 거리"]'::jsonb,
    '안전거리는 사고를 피할 수 있는 시간입니다.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    6,
    '운전 중 메시지를 확인해야 한다면?',
    'sequence',
    '["정차", "확인", "출발"]'::jsonb,
    null,
    '메시지는 안전하게 정차한 뒤 확인하세요.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    7,
    '어느 쪽이 더 안전한 운전일까요?',
    'compare',
    '"오른쪽"'::jsonb,
    null,
    '충분한 안전거리는 돌발상황에 대응할 여유를 만듭니다.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    8,
    '위험한 행동을 안전한 행동으로 바꿔주세요.',
    'text',
    '"휴식"'::jsonb,
    '["휴식", "쉬기", "쉼", "정차"]'::jsonb,
    '졸음이 오면 참지 말고 안전한 곳에서 쉬어야 합니다.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    9,
    '오늘 회식이 있다면 귀가 방법은?',
    'stamp',
    null,
    '["대중교통", "대리운전", "택시"]'::jsonb,
    '술을 마신 날에는 차량을 두고 안전하게 귀가하세요.',
    now() - interval '1 day',
    now() + interval '30 days'
  ),
  (
    10,
    '나의 최종 안전운전 실천 약속',
    'finalPledge',
    null,
    null,
    '오늘의 약속을 일상 속 안전운전으로 이어가 주세요.',
    now() - interval '1 day',
    now() + interval '30 days'
  );

commit;

-- =========================================================
-- 완료 후 확인할 항목
-- 1. Table Editor에서 테이블 7개 확인
-- 2. participants에 샘플 직원 5명 확인
-- 3. missions에 DAY 1~10 확인
-- 4. Authentication에서 Anonymous Sign-Ins 활성화
-- 5. 관리자 계정은 관리자 기능 연결 단계에서 별도 등록
-- =========================================================
