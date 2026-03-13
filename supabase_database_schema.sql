-- =======================================================
-- ARlens B2B 데이터 플랫폼 확장을 위한 SQL 스키마 가이드
-- Supabase SQL Editor에서 실행하세요.
-- =======================================================

-- 1. 사용자 인구통계 및 B2B 소속 정보를 관리하는 프로필 테이블 신설
-- Supabase의 기본 auth.users 테이블과 1:1 매핑됩니다.
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  brand_id text,          -- B2B 고객사 관리자일 경우 소속 브랜드 ID
  age_group text,         -- '10s', '20s', '30s', '40s+'
  gender text,            -- 'male', 'female', 'other'
  created_at timestamptz default now()
);

-- 2. 딥 트래킹(Deep Tracking)을 위한 행동 로그 테이블 신설
-- 사용자의 모든 주요 상호작용을 초 단위로 기록합니다.
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete set null, -- 로그인한 사용자의 경우 기록
  lens_id text,                                          -- 상호작용한 렌즈 ID
  brand_id text,                                         -- 해당 시점의 활성화된 브랜드 테마
  action_type text not null,                             -- 'try_on', 'capture', 'share', 'view_detail'
  created_at timestamptz default now()
);

-- 3. (선택) 보안 강화를 위한 RLS (Row Level Security) 설정
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- 프로필: 누구나 읽을 수 있지만, 본인 프로필만 수정 가능
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- 로그: 인서트(Insert)는 누구나 가능, 조회는 관리자나 시스템만 가능하도록 설정 가능
CREATE POLICY "Anyone can insert logs." ON public.activity_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Logs viewable by authenticated users only" ON public.activity_logs FOR SELECT USING (auth.role() = 'authenticated');
