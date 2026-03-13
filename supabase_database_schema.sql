-- =======================================================
-- ARlens B2B 데이터 플랫폼 확장을 위한 SQL 스키마 가이드 v5 (보안 강화)
-- Supabase SQL Editor에서 실행하세요.
-- =======================================================

-- 1. B2B 고객사(브랜드) 정보를 관리하는 브랜드 테이블
CREATE TABLE IF NOT EXISTS public.brands (
  id text primary key,            
  name text not null,             
  logoUrl text,                   
  primaryColor text,              
  tagline text,                   
  created_at timestamptz default now()
);

-- 2. 사용자 인구통계 및 B2B 소속 정보를 관리하는 프로필 테이블
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  brand_id text references public.brands(id) on delete set null, 
  associated_brand_id text, 
  age_group text,         
  gender text,            
  preferred_style text,   
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

-- 4. O2O 매장 관리 테이블
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

-- 5. Row Level Security(RLS) 보안 설정 마감
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

-- [브랜드] 누구나 읽기 가능
CREATE POLICY "Anyone can view brands." ON public.brands FOR SELECT USING (true);

-- [프로필] 누구나 읽기 가능, 본인만 수정 가능
CREATE POLICY "Anyone can view profiles." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- [로그] 누구나 등록 가능, 관리자만 조회 가능
CREATE POLICY "Anyone can insert logs." ON public.activity_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Authenticated admins can view logs." ON public.activity_logs FOR SELECT USING (auth.role() = 'authenticated');

-- [매장] 누구나 매장 위치 조회 가능 (SELECT)
CREATE POLICY "Public stores are viewable by everyone." ON public.stores 
FOR SELECT USING (true);

-- [매장] 브랜드 관리자 전용 관리 권한 (INSERT/UPDATE/DELETE)
-- 본인의 프로필에 등록된 brand_id와 매장의 brand_id가 일치하거나, 슈퍼관리자(admin)인 경우 허용
CREATE POLICY "Admins can manage stores of their own brand." ON public.stores
FOR ALL 
TO authenticated
USING (
  brand_id = (SELECT brand_id FROM public.profiles WHERE id = auth.uid()) 
  OR 
  (SELECT brand_id FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  brand_id = (SELECT brand_id FROM public.profiles WHERE id = auth.uid()) 
  OR 
  (SELECT brand_id FROM public.profiles WHERE id = auth.uid()) = 'admin'
);
