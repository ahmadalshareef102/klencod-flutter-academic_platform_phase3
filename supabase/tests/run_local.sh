#!/usr/bin/env bash
# يختبر سياسات RLS على PostgreSQL محلي (وليس على مشروع Supabase الحقيقي).
# المتطلبات: PostgreSQL مثبت وشغال محليًا، و psql متاح. عدّل متغيرات PGHOST وPGPORT وPGUSER إن لزم.
# الاستخدام:  bash supabase/tests/run_local.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
export TEST_DB="${TEST_DB:-rls_test}"
psql -X -q -d postgres -c "drop database if exists $TEST_DB" -c "create database $TEST_DB"
P="psql -X -q -v ON_ERROR_STOP=1 -d $TEST_DB"
# محاكاة الأجزاء التي توفرها Supabase عادة: الأدوار ومخطط auth ودالة auth.uid()
$P -c "do \$\$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
end \$\$;" \
   -c "create schema auth" \
   -c "create table auth.users(id uuid primary key)" \
   -c "create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid \$\$" \
   -c "grant usage on schema auth to authenticated, anon" \
   -c "grant execute on function auth.uid() to authenticated, anon"
$P -f supabase/schema.sql >/dev/null 2>&1
$P -f supabase/schema_patch.sql >/dev/null 2>&1
$P -c "grant usage on schema public to authenticated" -c "grant all on all tables in schema public to authenticated"
$P -f supabase/migrations/002_security_hardening.sql >/dev/null 2>&1
# محاكاة مخطط storage الذي توفره Supabase (مبسّطة)
$P <<'SQL' >/dev/null
create schema storage;
create table storage.buckets(id text primary key, name text, public boolean default false, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id), name text, owner uuid, created_at timestamptz default now());
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language plpgsql as $$
declare p text[]; begin p := string_to_array(name,'/'); return p[1:array_length(p,1)-1]; end $$;
grant usage on schema storage to authenticated;
grant select, insert, update, delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
SQL
$P -f supabase/migrations/003_storage_buckets.sql >/dev/null 2>&1
bash supabase/tests/rls_test.sh 2>&1 | grep -v -E "^(NOTICE|psql:)"
bash supabase/tests/storage_test.sh 2>&1 | grep -v -E "^(NOTICE|psql:)"
