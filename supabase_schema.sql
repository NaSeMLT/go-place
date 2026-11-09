-- GO PLACE 1.0: базовая схема Supabase/PostgreSQL
-- Выполняйте только после создания проекта Supabase.
create extension if not exists pgcrypto;

create table if not exists public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  region text,
  country text not null default 'Россия',
  slug text unique not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text unique not null,
  icon text
);

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id) on delete restrict,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  description text,
  address text,
  latitude double precision,
  longitude double precision,
  price_level smallint check (price_level between 1 and 3),
  website_url text,
  phone text,
  is_active boolean not null default true,
  is_sponsored boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.place_rating_snapshots (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  source_name text not null,
  source_url text,
  rating numeric(2,1) check (rating between 0 and 5),
  review_count integer check (review_count >= 0),
  checked_at timestamptz not null default now(),
  unique(place_id, source_name, checked_at)
);

create table if not exists public.place_photos (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  image_url text not null,
  attribution text,
  usage_rights_note text,
  sort_order integer not null default 0
);

create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, place_id)
);

create index if not exists places_city_idx on public.places(city_id);
create index if not exists places_category_idx on public.places(category_id);
create index if not exists rating_place_checked_idx on public.place_rating_snapshots(place_id, checked_at desc);

-- Включайте RLS до подключения реальных пользователей.
alter table public.cities enable row level security;
alter table public.categories enable row level security;
alter table public.places enable row level security;
alter table public.place_rating_snapshots enable row level security;
alter table public.place_photos enable row level security;
alter table public.favorites enable row level security;

-- Публичное чтение активного каталога.
create policy "Anyone can read active cities" on public.cities for select using (is_active = true);
create policy "Anyone can read categories" on public.categories for select using (true);
create policy "Anyone can read active places" on public.places for select using (is_active = true);
create policy "Anyone can read rating snapshots" on public.place_rating_snapshots for select using (true);
create policy "Anyone can read place photos" on public.place_photos for select using (true);

-- Избранное доступно только владельцу аккаунта.
create policy "Users manage own favorites" on public.favorites
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Не добавляйте публичные INSERT/UPDATE/DELETE политики для каталога.
-- Администрирование каталога выполняйте через защищённый серверный ключ,
-- который нельзя помещать в браузерный JavaScript.
