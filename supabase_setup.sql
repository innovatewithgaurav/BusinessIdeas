-- LaunchDesk database setup for a NEW Supabase project.
-- Paste into Supabase Dashboard > SQL Editor, then run once.
-- Policies limit all records to authenticated workspace members.
-- WARNING: SQL is designed for a fresh project, not for overwriting existing production tables.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.workspaces (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(name) between 1 and 80),
 owner_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.workspace_members (
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check(role in ('owner','editor','viewer')),
 created_at timestamptz not null default now(),
 primary key(workspace_id,user_id)
);
create table if not exists public.entries (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 section text not null check(section in ('tasks','ideas','competitors','scores','costs','documents','vendors','decisions')),
 payload jsonb not null default '{}'::jsonb,
 created_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint payload_is_object check (jsonb_typeof(payload)='object')
);
create index if not exists entries_workspace_idx on public.entries(workspace_id,section,created_at);

-- Invite secrets are stored only as cryptographic hashes, not in plaintext.
create table if not exists public.share_tokens (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 token_hash text not null unique,
 role text not null check(role in ('viewer','editor')),
 created_by uuid not null references auth.users(id),
 expires_at timestamptz not null,
 max_uses int not null default 10 check(max_uses between 1 and 100),
 uses_count int not null default 0 check(uses_count >= 0),
 revoked_at timestamptz,
 created_at timestamptz not null default now()
);

create or replace function public.my_workspace_role(p_workspace_id uuid)
returns text language sql stable security definer set search_path = '' as $$
 select m.role from public.workspace_members m
 where m.workspace_id = p_workspace_id and m.user_id = (select auth.uid()) limit 1;
$$;

-- Trigger ensures creator becomes an owner without permitting arbitrary member inserts.
create or replace function public.make_workspace_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.workspace_members(workspace_id,user_id,role)
 values(new.id,new.owner_id,'owner');
 return new;
end;$$;
drop trigger if exists on_workspace_created on public.workspaces;
create trigger on_workspace_created after insert on public.workspaces
for each row execute procedure public.make_workspace_owner();

create or replace function public.touch_entry_time()
returns trigger language plpgsql set search_path = '' as $$
begin
 new.updated_at = now();
 return new;
end;$$;
drop trigger if exists on_entry_updated on public.entries;
create trigger on_entry_updated before update on public.entries
for each row execute procedure public.touch_entry_time();

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.entries enable row level security;
alter table public.share_tokens enable row level security;

-- Workspace and membership visibility: signed-in members only.
drop policy if exists ws_read on public.workspaces;
create policy ws_read on public.workspaces for select to authenticated
using (public.my_workspace_role(id) is not null);
drop policy if exists ws_create on public.workspaces;
create policy ws_create on public.workspaces for insert to authenticated
with check (owner_id = (select auth.uid()));
drop policy if exists ws_update on public.workspaces;
create policy ws_update on public.workspaces for update to authenticated
using (public.my_workspace_role(id)='owner') with check(public.my_workspace_role(id)='owner');

drop policy if exists members_read on public.workspace_members;
create policy members_read on public.workspace_members for select to authenticated
using(public.my_workspace_role(workspace_id) is not null);
-- No direct insert/update/delete policies on workspace_members or share_tokens.
-- Membership changes are handled only by verified SECURITY DEFINER functions.

drop policy if exists entries_read on public.entries;
create policy entries_read on public.entries for select to authenticated
using(public.my_workspace_role(workspace_id) in ('owner','editor','viewer'));
drop policy if exists entries_create on public.entries;
create policy entries_create on public.entries for insert to authenticated
with check (created_by = (select auth.uid()) and public.my_workspace_role(workspace_id) in ('owner','editor'));
drop policy if exists entries_update on public.entries;
create policy entries_update on public.entries for update to authenticated
using(public.my_workspace_role(workspace_id) in ('owner','editor'))
with check(public.my_workspace_role(workspace_id) in ('owner','editor'));
drop policy if exists entries_delete on public.entries;
create policy entries_delete on public.entries for delete to authenticated
using(public.my_workspace_role(workspace_id) in ('owner','editor'));

-- Only owner can create short-lived invitation. Function returns secret once.
create or replace function public.create_share_link(p_workspace_id uuid,p_role text default 'viewer',p_hours integer default 24)
returns text language plpgsql security definer set search_path = '' as $$
declare
 secret text;
begin
 if (select auth.uid()) is null then raise exception 'Login required'; end if;
 if public.my_workspace_role(p_workspace_id) <> 'owner' then raise exception 'Owner access required'; end if;
 if p_role not in ('viewer','editor') then raise exception 'Invalid share role'; end if;
 if p_hours < 1 or p_hours > 168 then raise exception 'Expiry out of range'; end if;
 secret := encode(extensions.gen_random_bytes(32),'hex');
 insert into public.share_tokens(workspace_id,token_hash,role,created_by,expires_at,max_uses)
 values (p_workspace_id,encode(extensions.digest(secret,'sha256'),'hex'),p_role,(select auth.uid()),now()+make_interval(hours=>p_hours),10);
 return secret;
end;$$;

-- Any signed-in holder of a VALID unexpired secret can join a workspace.
-- Existing users do not get their role elevated by a different invitation.
create or replace function public.join_workspace(p_token text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
 invite public.share_tokens%rowtype;
 existing_role text;
begin
 if (select auth.uid()) is null then raise exception 'Login required'; end if;
 if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'Invalid invitation'; end if;
 select * into invite from public.share_tokens t
 where t.token_hash=encode(extensions.digest(p_token,'sha256'),'hex')
 and t.revoked_at is null and t.expires_at>now() and t.uses_count<t.max_uses
 for update;
 if not found then raise exception 'Invitation expired, invalid or already used'; end if;
 select role into existing_role from public.workspace_members
 where workspace_id=invite.workspace_id and user_id=(select auth.uid());
 if existing_role is null then
  insert into public.workspace_members(workspace_id,user_id,role)
  values(invite.workspace_id,(select auth.uid()),invite.role);
  update public.share_tokens set uses_count=uses_count+1 where id=invite.id;
 end if;
 return invite.workspace_id;
end;$$;

revoke all on function public.create_share_link(uuid,text,integer) from public;
revoke all on function public.join_workspace(text) from public;
revoke all on function public.my_workspace_role(uuid) from public;
grant execute on function public.create_share_link(uuid,text,integer) to authenticated;
grant execute on function public.join_workspace(text) to authenticated;
grant execute on function public.my_workspace_role(uuid) to authenticated;

-- Supabase PostgREST needs grants in addition to RLS.
grant usage on schema public to authenticated;
grant select,insert,update,delete on public.workspaces to authenticated;
grant select on public.workspace_members to authenticated;
grant select,insert,update,delete on public.entries to authenticated;
-- Intentionally NO direct client table privileges for share_tokens.
revoke all on public.share_tokens from anon,authenticated;
