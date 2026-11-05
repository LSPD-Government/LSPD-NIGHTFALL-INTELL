-- LSPD NIGHTFALL INTELL - initial database schema
-- Run this in Supabase SQL Editor after creating the project.
-- Do not disable RLS. Do not place a service_role key in the website.

create extension if not exists pgcrypto;

create table if not exists public.nightfall_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'detective' check (role in ('detective','command','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.nightfall_cases (
  id uuid primary key default gen_random_uuid(),
  case_number text not null unique,
  title text not null,
  status text not null default 'Open',
  priority text not null default 'Normal',
  lead_detective text,
  summary text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nightfall_warrants (
  id uuid primary key default gen_random_uuid(),
  warrant_number text not null unique,
  subject_name text not null,
  warrant_type text not null,
  status text not null default 'Draft',
  case_number text,
  details text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.nightfall_suspects (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  known_aliases text,
  status text not null default 'Under Investigation',
  case_number text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.nightfall_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  action text not null,
  record_type text,
  record_id uuid,
  details text,
  created_at timestamptz not null default now()
);

-- Create a least-privilege profile row for each new authenticated account.
create or replace function public.nightfall_handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.nightfall_profiles (id, display_name, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)), 'detective')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists nightfall_on_auth_user_created on auth.users;
create trigger nightfall_on_auth_user_created
after insert on auth.users
for each row execute procedure public.nightfall_handle_new_user();

create or replace function public.nightfall_user_role()
returns text language sql stable security definer set search_path = ''
as $$
  select role from public.nightfall_profiles where id = (select auth.uid())
$$;

alter table public.nightfall_profiles enable row level security;
alter table public.nightfall_cases enable row level security;
alter table public.nightfall_warrants enable row level security;
alter table public.nightfall_suspects enable row level security;
alter table public.nightfall_activity enable row level security;

-- Profiles: users can read their own profile; admins/command can read all.
drop policy if exists "profile read own or command" on public.nightfall_profiles;
create policy "profile read own or command" on public.nightfall_profiles for select to authenticated
using (id = (select auth.uid()) or public.nightfall_user_role() in ('command','admin'));
-- No client-side role updates. Promote staff manually in the SQL editor.

-- Department records: authenticated staff can read. Detectives can add records.
do $$
declare t text;
begin
  foreach t in array array['nightfall_cases','nightfall_warrants','nightfall_suspects'] loop
    execute format('drop policy if exists "staff read %1$s" on public.%1$I', t);
    execute format('create policy "staff read %1$s" on public.%1$I for select to authenticated using (true)', t);
    execute format('drop policy if exists "staff insert %1$s" on public.%1$I', t);
    execute format('create policy "staff insert %1$s" on public.%1$I for insert to authenticated with check (created_by = (select auth.uid()))', t);
    execute format('drop policy if exists "command update %1$s" on public.%1$I', t);
    execute format('create policy "command update %1$s" on public.%1$I for update to authenticated using (public.nightfall_user_role() in (''command'',''admin'')) with check (public.nightfall_user_role() in (''command'',''admin''))', t);
    execute format('drop policy if exists "admin delete %1$s" on public.%1$I', t);
    execute format('create policy "admin delete %1$s" on public.%1$I for delete to authenticated using (public.nightfall_user_role() = ''admin'')', t);
  end loop;
end $$;

drop policy if exists "staff read activity" on public.nightfall_activity;
create policy "staff read activity" on public.nightfall_activity for select to authenticated using (true);
drop policy if exists "staff add activity" on public.nightfall_activity;
create policy "staff add activity" on public.nightfall_activity for insert to authenticated with check (user_id = (select auth.uid()));

grant usage on schema public to authenticated;
grant select on public.nightfall_profiles to authenticated;
grant select, insert, update, delete on public.nightfall_cases, public.nightfall_warrants, public.nightfall_suspects to authenticated;
grant select, insert on public.nightfall_activity to authenticated;

-- IMPORTANT: after your own account signs up, promote it from detective to admin
-- using the SQL Editor (replace the email with your actual login email):
-- update public.nightfall_profiles p set role = 'admin'
-- from auth.users u where p.id = u.id and u.email = 'YOUR-EMAIL-HERE';

-- This starter schema is intentionally conservative. Review department access rules
-- before adding real or sensitive information. Use fictional RP records only.
