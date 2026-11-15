-- APNA JOB HUB DATABASE SETUP
-- Supabase Dashboard > SQL Editor > New query > paste all > Run

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text default '',
  phone text default '',
  city text default '',
  skills text default '',
  role text not null default 'candidate' check (role in ('candidate','recruiter','admin')),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
declare safe_role text;
begin
  safe_role := case when new.raw_user_meta_data->>'role' = 'recruiter' then 'recruiter' else 'candidate' end;
  insert into public.profiles(id, full_name, phone, role)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''),
         coalesce(new.raw_user_meta_data->>'phone',''), safe_role)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- A logged-in user cannot promote themselves to admin or change their role.
create or replace function public.prevent_profile_role_change()
returns trigger language plpgsql
as $$
begin
  if auth.uid() is not null and new.role <> old.role then
    raise exception 'Changing account role is not allowed';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role before update on public.profiles
for each row execute function public.prevent_profile_role_change();

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  recruiter_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  company text not null,
  city text not null,
  salary text default '',
  contact_phone text default '',
  job_type text default 'Full Time',
  vacancies integer not null default 1 check (vacancies > 0),
  description text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

alter table public.jobs add column if not exists contact_phone text default '';

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  candidate_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'applied' check (status in ('applied','shortlisted','rejected','hired')),
  created_at timestamptz not null default now(),
  unique(job_id, candidate_id)
);

alter table public.profiles enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;


-- Only admins may change a job's moderation status.
create or replace function public.guard_job_moderation()
returns trigger language plpgsql
as $$
begin
  if auth.uid() is not null and new.status is distinct from old.status
     and not exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin') then
    raise exception 'Only admins can change job approval status';
  end if;
  return new;
end;
$$;
drop trigger if exists jobs_moderation_guard on public.jobs;
create trigger jobs_moderation_guard before update on public.jobs
for each row execute function public.guard_job_moderation();

-- Profiles: users can see/update their own profile; recruiters/admins can see candidate profiles for applications.
drop policy if exists "profile_select" on public.profiles;
create policy "profile_select" on public.profiles for select to authenticated
using (id = auth.uid() or exists (
  select 1 from public.applications a
  join public.jobs j on j.id = a.job_id
  where a.candidate_id = profiles.id and j.recruiter_id = auth.uid()
) or exists (select 1 from public.profiles me where me.id=auth.uid() and me.role='admin'));

drop policy if exists "profile_update_own" on public.profiles;
create policy "profile_update_own" on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

-- Jobs: public can see approved jobs; recruiters see their own; admin sees all.
drop policy if exists "jobs_read" on public.jobs;
create policy "jobs_read" on public.jobs for select
using (status='approved' or recruiter_id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

drop policy if exists "jobs_insert_recruiter" on public.jobs;
create policy "jobs_insert_recruiter" on public.jobs for insert to authenticated
with check (recruiter_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('recruiter','admin')));

drop policy if exists "jobs_update_owner_admin" on public.jobs;
create policy "jobs_update_owner_admin" on public.jobs for update to authenticated
using (recruiter_id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'))
with check (recruiter_id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

-- Applications: candidates create/read their own; recruiters read applications for their jobs; admin can read all.
drop policy if exists "applications_read" on public.applications;
create policy "applications_read" on public.applications for select to authenticated
using (candidate_id=auth.uid()
  or exists(select 1 from public.jobs j where j.id=job_id and j.recruiter_id=auth.uid())
  or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

drop policy if exists "applications_insert_candidate" on public.applications;
create policy "applications_insert_candidate" on public.applications for insert to authenticated
with check (candidate_id=auth.uid()
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='candidate')
  and exists(select 1 from public.jobs j where j.id=job_id and j.status='approved'));

-- Recruiters/admin can update application status for their jobs.
drop policy if exists "applications_update_recruiter_admin" on public.applications;
create policy "applications_update_recruiter_admin" on public.applications for update to authenticated
using (exists(select 1 from public.jobs j where j.id=job_id and j.recruiter_id=auth.uid())
  or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'))
with check (exists(select 1 from public.jobs j where j.id=job_id and j.recruiter_id=auth.uid())
  or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

-- IMPORTANT: After registering your own account, promote it to admin manually.
-- Replace the email below with the email used for your account, then run this separately:
-- update public.profiles
-- set role = 'admin'
-- where id = (select id from auth.users where email = 'YOUR_EMAIL_HERE');
