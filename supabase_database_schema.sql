-- =======================================================
-- ARlens B2B 데이터 플랫폼 확장을 위한 SQL 스키마 가이드 v4
-- Supabase SQL Editor에서 실행하세요.
-- =======================================================

-- 1. B2B 고객사(브랜드) 정보를 관리하는 브랜드 테이블
CREATE TABLE IF NOT EXISTS public.brands (
  id text primary key,            -- 'O-Lens', 'HapaKristin' 등 고유 ID
  name text not null,             -- 브랜드 이름
  logoUrl text,                   -- 로고 이미지 URL
  primaryColor text,              -- 메인 컬러 (Hex Code, 예: '#FF0000')
  tagline text,                   -- 슬로건
  created_at timestamptz default now()
);

-- 2. 사용자 인구통계 및 B2B 소속 정보를 관리하는 프로필 테이블
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  brand_id text references public.brands(id) on delete set null, -- B2B 고객사 관리자일 경우 소속 브랜드 ID
  associated_brand_id text, -- 일반 유저의 선호/연관 브랜드
  age_group text,         -- '10s', '20s', '30s', '40s+'
  gender text,            -- 'male', 'female', 'other'
  preferred_style text,   -- 'natural', 'color', 'y2k' 등
  created_at timestamptz default now()
);

-- 3. 행동 로그 테이블
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete set null,
  anonymous_id text,                                     
  lens_id text,                                          
  brand_id text references public.brands(id) on delete set null,
  action_type text not null,                             
  duration_ms int8 default 0,                            
  created_at timestamptz default now()
);

-- 4. [신규] O2O 매장 관리 테이블
CREATE TABLE IF NOT EXISTS public.stores (
  id uuid default gen_random_uuid() primary key,
  brand_id text references public.brands(id) on delete cascade not null,
  name text not null,
  address text not null,
  phone text,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz default now()
);

-- 5. 보안 강화를 위한 RLS (Row Level Security) 설정
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

-- 브랜드: 누구나 읽을 수 있음
CREATE POLICY "Public brands are viewable by everyone." ON public.brands FOR SELECT USING (true);

-- 프로필: 누구나 읽을 수 있지만, 본인 프로필만 수정 가능
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- 로그: 인서트(Insert)는 누구나 가능
CREATE POLICY "Anyone can insert logs." ON public.activity_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Logs viewable by authenticated users only" ON public.activity_logs FOR SELECT USING (auth.role() = 'authenticated');

-- [신규] 매장: 누구나 조회 가능, 브랜드 관리자만 자기 매장 관리
CREATE POLICY "Public stores are viewable by everyone." ON public.stores FOR SELECT USING (true);
CREATE POLICY "Admins can manage own brand stores" ON public.stores
FOR ALL USING (
  brand_id = (SELECT brand_id FROM public.profiles WHERE id = auth.uid()) 
  OR 
  (SELECT brand_id FROM public.profiles WHERE id = auth.uid()) = 'admin'
);
