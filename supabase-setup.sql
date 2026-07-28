-- ============================================================
-- 안운찬 수의사 홈페이지 — 문의 접수 테이블
-- Supabase 대시보드 → SQL Editor 에 붙여넣고 한 번 실행하세요.
-- ============================================================

create table if not exists public.inquiries (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),

  -- guardian = 보호자 문의, vet = 수의사 전원 의뢰
  kind        text not null check (kind in ('guardian','vet')),

  name        text not null check (char_length(name)    between 1 and 50),
  contact     text not null check (char_length(contact) between 1 and 100),
  patient     text          check (char_length(patient) <= 200),
  message     text not null check (char_length(message) between 1 and 2000),

  -- 개인정보 수집·이용 동의. false면 INSERT 자체가 거부됩니다(아래 정책).
  consent     boolean not null default false,

  -- 처리 상태: 접수 → 연락함 → 종료
  status      text not null default 'new' check (status in ('new','contacted','closed'))
);

create index if not exists inquiries_created_at_idx on public.inquiries (created_at desc);
create index if not exists inquiries_status_idx     on public.inquiries (status);

-- ------------------------------------------------------------
-- RLS: 익명 사용자는 "쓰기"만 가능, 읽기·수정·삭제는 전면 차단
-- ------------------------------------------------------------
alter table public.inquiries enable row level security;

revoke all on public.inquiries from anon;
grant insert on public.inquiries to anon;

drop policy if exists "anon_can_insert_inquiry" on public.inquiries;
create policy "anon_can_insert_inquiry"
  on public.inquiries
  for insert
  to anon
  with check (consent = true and status = 'new');

-- SELECT / UPDATE / DELETE 정책을 만들지 않았으므로
-- 공개 키(sb_publishable_...)로는 접수된 문의를 절대 읽을 수 없습니다.
-- 접수 내역은 Supabase 대시보드 → Table Editor → inquiries 에서 확인하세요.

-- ------------------------------------------------------------
-- (선택) 접수된 문의를 보기 좋게 조회하는 뷰 — 대시보드/SQL Editor 전용
-- ------------------------------------------------------------
create or replace view public.inquiries_inbox as
  select
    to_char(created_at at time zone 'Asia/Seoul', 'MM-DD HH24:MI') as 접수시각,
    case kind when 'guardian' then '보호자' else '수의사' end       as 구분,
    name     as 성함,
    contact  as 연락처,
    patient  as 환자,
    message  as 내용,
    status   as 상태,
    id
  from public.inquiries
  order by created_at desc;

revoke all on public.inquiries_inbox from anon;
