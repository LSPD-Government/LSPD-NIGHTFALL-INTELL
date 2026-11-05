-- LSPD NIGHTFALL INTELL — fresh database schema
-- Run once in the NEW Nightfall Supabase project SQL Editor.
-- This creates empty tables only; it does not import Nightwatch records.
-- Keep Row Level Security enabled. Never put a service_role key in browser code.

create extension if not exists pgcrypto;

create table if not exists public.nightfall_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'detective' check (role in ('detective','command','admin')),
  created_at timestamptz not null default now()
);
create table if not exists public.nightfall_cases (
  id uuid primary key default gen_random_uuid(), case_number text not null unique, title text not null,
  status text not null default 'Open', priority text not null default 'Normal', lead_detective text,
  summary text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.nightfall_warrants (
  id uuid primary key default gen_random_uuid(), warrant_number text not null unique, subject_name text not null,
  warrant_type text not null, status text not null default 'Draft', case_number text, details text,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.nightfall_rico (
  id uuid primary key default gen_random_uuid(), case_number text not null unique, organization_name text not null,
  status text not null default 'Intake', threat_level text not null default 'Moderate', lead_detective text, overview text,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.nightfall_corruption (
  id uuid primary key default gen_random_uuid(), case_number text not null unique, subject_name text not null,
  allegation text not null, status text not null default 'Intake', assigned_to text, summary text,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.nightfall_suspects (
  id uuid primary key default gen_random_uuid(), full_name text not null, known_aliases text, status text not null default 'Under Investigation',
  associated_group text, case_number text, notes text, created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.nightfall_gangs (
  id uuid primary key default gen_random_uuid(), group_name text not null, known_area text, status text not null default 'Monitoring',
  threat_level text not null default 'Unconfirmed', known_associates text, intelligence_summary text,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.nightfall_reports (
  id uuid primary key default gen_random_uuid(), report_number text not null unique, subject text not null,
  category text not null, confidence text not null default 'Unverified', location text, report_body text not null,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.nightfall_directory (
  id uuid primary key default gen_random_uuid(), full_name text not null, callsign text, rank text, division text,
  status text not null default 'Active', contact text, created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.nightfall_activity (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete set null,
  action text not null, record_type text, record_id uuid, details text, created_at timestamptz not null default now()
);

create or replace function public.nightfall_handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.nightfall_profiles(id,display_name,role)
  values(new.id,coalesce(new.raw_user_meta_data ->> 'full_name',split_part(new.email,'@',1)),'detective')
  on conflict(id) do nothing;
  return new;
end;
$$;
drop trigger if exists nightfall_on_auth_user_created on auth.users;
create trigger nightfall_on_auth_user_created after insert on auth.users
for each row execute procedure public.nightfall_handle_new_user();

create or replace function public.nightfall_user_role()
returns text language sql stable security definer set search_path = ''
as $$ select role from public.nightfall_profiles where id=(select auth.uid()) $$;

alter table public.nightfall_profiles enable row level security;
alter table public.nightfall_activity enable row level security;
do $$
declare t text;
begin
  foreach t in array array['nightfall_cases','nightfall_warrants','nightfall_rico','nightfall_corruption','nightfall_suspects','nightfall_gangs','nightfall_reports','nightfall_directory'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists "staff read %1$s" on public.%1$I',t);
    execute format('create policy "staff read %1$s" on public.%1$I for select to authenticated using (true)',t);
    execute format('drop policy if exists "staff insert %1$s" on public.%1$I',t);
    execute format('create policy "staff insert %1$s" on public.%1$I for insert to authenticated with check (created_by=(select auth.uid()))',t);
    execute format('drop policy if exists "command update %1$s" on public.%1$I',t);
    execute format('create policy "command update %1$s" on public.%1$I for update to authenticated using (public.nightfall_user_role() in (''command'',''admin'')) with check (public.nightfall_user_role() in (''command'',''admin''))',t);
    execute format('drop policy if exists "admin delete %1$s" on public.%1$I',t);
    execute format('create policy "admin delete %1$s" on public.%1$I for delete to authenticated using (public.nightfall_user_role()=''admin'')',t);
    execute format('grant select,insert,update,delete on public.%I to authenticated',t);
  end loop;
end $$;

drop policy if exists "profile read own or command" on public.nightfall_profiles;
create policy "profile read own or command" on public.nightfall_profiles for select to authenticated
using(id=(select auth.uid()) or public.nightfall_user_role() in ('command','admin'));
drop policy if exists "staff read activity" on public.nightfall_activity;
create policy "staff read activity" on public.nightfall_activity for select to authenticated using(true);
drop policy if exists "staff add activity" on public.nightfall_activity;
create policy "staff add activity" on public.nightfall_activity for insert to authenticated with check(user_id=(select auth.uid()));

grant usage on schema public to authenticated;
grant select on public.nightfall_profiles to authenticated;
grant select,insert on public.nightfall_activity to authenticated;

-- After creating your account and signing in once, promote your account:
-- update public.nightfall_profiles p set role='admin'
-- from auth.users u where p.id=u.id and u.email='YOUR-LOGIN-EMAIL';
-- Only run that statement after replacing the email with your own.


-- NIGHTFALL ACCOUNT REGISTRATION + COMMAND APPROVAL MIGRATION
-- Run this section once in the NEW Nightfall project's Supabase SQL Editor.
alter table public.nightfall_profiles add column if not exists username text;
alter table public.nightfall_profiles add column if not exists username_normalized text;
alter table public.nightfall_profiles add column if not exists status text not null default 'pending' check (status in ('pending','approved','rejected'));
update public.nightfall_profiles set username=coalesce(username,display_name), username_normalized=coalesce(username_normalized,lower(trim(coalesce(username,display_name,''))));
create unique index if not exists nightfall_profiles_username_normalized_key on public.nightfall_profiles(username_normalized) where username_normalized is not null and username_normalized<>'';
create or replace function public.nightfall_handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_name text; v_username text;
begin
  v_name := coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email,'@',1));
  v_username := lower(trim(coalesce(new.raw_user_meta_data ->> 'username',v_name)));
  insert into public.nightfall_profiles(id,display_name,username,username_normalized,role,status)
  values(new.id,v_name,v_name,v_username,'detective','pending')
  on conflict(id) do update set display_name=excluded.display_name,username=excluded.username,username_normalized=excluded.username_normalized;
  return new;
end;
$$;
drop policy if exists "profile update by command" on public.nightfall_profiles;
create policy "profile update by command" on public.nightfall_profiles for update to authenticated
using (public.nightfall_user_role() in ('command','admin'))
with check (public.nightfall_user_role() in ('command','admin'));
-- Limit browser-side profile changes to approval status only. Roles are changed in SQL by an administrator.
revoke update on public.nightfall_profiles from authenticated;
grant update(status) on public.nightfall_profiles to authenticated;
create or replace function public.nightfall_is_approved()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.nightfall_profiles where id=(select auth.uid()) and status='approved') $$;
do $$
declare t text;
begin
  foreach t in array array['nightfall_cases','nightfall_warrants','nightfall_rico','nightfall_corruption','nightfall_suspects','nightfall_gangs','nightfall_reports','nightfall_directory'] loop
    execute format('drop policy if exists "staff read %1$s" on public.%1$I',t);
    execute format('create policy "staff read %1$s" on public.%1$I for select to authenticated using (public.nightfall_is_approved())',t);
    execute format('drop policy if exists "staff insert %1$s" on public.%1$I',t);
    execute format('create policy "staff insert %1$s" on public.%1$I for insert to authenticated with check (public.nightfall_is_approved() and created_by=(select auth.uid()))',t);
    execute format('drop policy if exists "command update %1$s" on public.%1$I',t);
    execute format('create policy "command update %1$s" on public.%1$I for update to authenticated using (public.nightfall_is_approved() and public.nightfall_user_role() in (''command'',''admin'')) with check (public.nightfall_is_approved() and public.nightfall_user_role() in (''command'',''admin''))',t);
    execute format('drop policy if exists "admin delete %1$s" on public.%1$I',t);
    execute format('create policy "admin delete %1$s" on public.%1$I for delete to authenticated using (public.nightfall_is_approved() and public.nightfall_user_role()=''admin'')',t);
  end loop;
end $$;
drop policy if exists "staff read activity" on public.nightfall_activity;
create policy "staff read activity" on public.nightfall_activity for select to authenticated using (public.nightfall_is_approved());
drop policy if exists "staff add activity" on public.nightfall_activity;
create policy "staff add activity" on public.nightfall_activity for insert to authenticated with check (public.nightfall_is_approved() and user_id=(select auth.uid()));
-- First-time setup only: after you register, replace the email and run this once to activate your own Command/Admin account.
-- update public.nightfall_profiles p set role='admin', status='approved' from auth.users u where p.id=u.id and u.email='YOUR-EMAIL-HERE';


-- NIGHTFALL RECORD OWNERSHIP PERMISSIONS
-- Everyone with approved Nightfall access can view records.
-- Only the account that created a record can edit or delete that record.
do $$
declare t text;
begin
  foreach t in array array['nightfall_cases','nightfall_warrants','nightfall_rico','nightfall_corruption','nightfall_suspects','nightfall_gangs','nightfall_reports','nightfall_directory'] loop
    execute format('drop policy if exists "command update %1$s" on public.%1$I',t);
    execute format('drop policy if exists "admin delete %1$s" on public.%1$I',t);
    execute format('drop policy if exists "creator update %1$s" on public.%1$I',t);
    execute format('create policy "creator update %1$s" on public.%1$I for update to authenticated using (public.nightfall_is_approved() and created_by=(select auth.uid())) with check (public.nightfall_is_approved() and created_by=(select auth.uid()))',t);
    execute format('drop policy if exists "creator delete %1$s" on public.%1$I',t);
    execute format('create policy "creator delete %1$s" on public.%1$I for delete to authenticated using (public.nightfall_is_approved() and created_by=(select auth.uid()))',t);
  end loop;
end $$;
