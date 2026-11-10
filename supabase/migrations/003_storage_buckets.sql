-- ============================================================================
-- 003_storage_buckets.sql
-- حاويات الملفات (Storage) الخاصة للمحاضرات والتسليمات مع سياسات صلاحيات.
-- يتطلب تنفيذ 002_security_hardening.sql أولًا. قابل للتنفيذ أكثر من مرة.
--
-- مسارات الملفات (مهمة: التطبيق يجب أن يلتزم بها):
--   lectures    : <course_id>/<اسم_الملف>
--   submissions : <assignment_id>/<student_id>/<اسم_الملف>
-- المحاضرة تخزّن المسار نفسه في الحقل lectures.file_path (أو رابطًا خارجيًا http/https).
-- العرض يتم عبر روابط موقّعة قصيرة المدة (createSignedUrl) وليس روابط عامة.
-- ============================================================================

begin;

-- تحويل نص إلى uuid بأمان (يعيد null بدل رفع خطأ).
create or replace function public.app_try_uuid(p text)
returns uuid language plpgsql immutable set search_path = public
as $$ begin return p::uuid; exception when others then return null; end $$;

-- هل يحق للطالب الحالي قراءة ملف المحاضرة؟ (مسجل في المقرر والمحاضرة منشورة ومسارها هذا الملف)
create or replace function public.app_lecture_file_readable(p_course uuid, p_name text)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.lectures l
  where l.course_id = p_course and l.file_path = p_name
    and l.published_at is not null and l.published_at <= now()
    and public.app_enrolled(l.course_id)) $$;

-- هل ما زال تسليم الطالب بلا درجة (فيجوز له استبدال ملفه)؟
create or replace function public.app_submission_open(p_assignment uuid, p_student uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select not exists (
  select 1 from public.submissions s
  where s.assignment_id = p_assignment and s.student_id = p_student and s.score is not null) $$;

revoke all on function public.app_try_uuid(text), public.app_lecture_file_readable(uuid, text),
  public.app_submission_open(uuid, uuid) from public, anon;
grant execute on function public.app_try_uuid(text), public.app_lecture_file_readable(uuid, text),
  public.app_submission_open(uuid, uuid) to authenticated;

-- الحاويات: خاصة، حد 20 ميغابايت، أنواع محددة.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
 ('lectures',    'lectures',    false, 20971520, array[
   'application/pdf','application/zip','image/png','image/jpeg',
   'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
   'application/vnd.openxmlformats-officedocument.presentationml.presentation',
   'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
 ('submissions', 'submissions', false, 20971520, array[
   'application/pdf','application/zip','image/png','image/jpeg',
   'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
   'application/vnd.openxmlformats-officedocument.presentationml.presentation',
   'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- إسقاط سياساتنا القديمة (إن وُجدت) ثم إنشاؤها.
drop policy if exists app_lectures_select on storage.objects;
drop policy if exists app_lectures_write on storage.objects;
drop policy if exists app_lectures_update on storage.objects;
drop policy if exists app_lectures_delete on storage.objects;
drop policy if exists app_submissions_select on storage.objects;
drop policy if exists app_submissions_insert on storage.objects;
drop policy if exists app_submissions_update on storage.objects;
drop policy if exists app_submissions_delete on storage.objects;

-- ── lectures ────────────────────────────────────────────────────────────────
create policy app_lectures_select on storage.objects for select to authenticated using (
  bucket_id = 'lectures' and (
    public.app_current_role() in ('admin','head')
    or public.app_teaches(public.app_try_uuid((storage.foldername(name))[1]))
    or public.app_lecture_file_readable(public.app_try_uuid((storage.foldername(name))[1]), name)
  )
);
create policy app_lectures_write on storage.objects for insert to authenticated with check (
  bucket_id = 'lectures' and (
    public.app_current_role() in ('admin','head')
    or public.app_teaches(public.app_try_uuid((storage.foldername(name))[1]))
  )
);
create policy app_lectures_update on storage.objects for update to authenticated
using (bucket_id = 'lectures' and (
    public.app_current_role() in ('admin','head')
    or public.app_teaches(public.app_try_uuid((storage.foldername(name))[1]))))
with check (bucket_id = 'lectures' and (
    public.app_current_role() in ('admin','head')
    or public.app_teaches(public.app_try_uuid((storage.foldername(name))[1]))));
create policy app_lectures_delete on storage.objects for delete to authenticated using (
  bucket_id = 'lectures' and (
    public.app_current_role() in ('admin','head')
    or public.app_teaches(public.app_try_uuid((storage.foldername(name))[1]))
  )
);

-- ── submissions ─────────────────────────────────────────────────────────────
create policy app_submissions_select on storage.objects for select to authenticated using (
  bucket_id = 'submissions' and (
    public.app_current_role() in ('admin','head')
    or public.app_teaches(public.app_assignment_course(public.app_try_uuid((storage.foldername(name))[1])))
    or (public.app_try_uuid((storage.foldername(name))[2]) = auth.uid() and public.app_is_active())
  )
);
create policy app_submissions_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'submissions'
  and public.app_current_role() = 'student'
  and public.app_try_uuid((storage.foldername(name))[2]) = auth.uid()
  and public.app_enrolled(public.app_assignment_course(public.app_try_uuid((storage.foldername(name))[1])))
  and public.app_submission_open(public.app_try_uuid((storage.foldername(name))[1]), auth.uid())
);
create policy app_submissions_update on storage.objects for update to authenticated
using (bucket_id = 'submissions' and public.app_current_role() = 'student'
  and public.app_try_uuid((storage.foldername(name))[2]) = auth.uid()
  and public.app_submission_open(public.app_try_uuid((storage.foldername(name))[1]), auth.uid()))
with check (bucket_id = 'submissions' and public.app_current_role() = 'student'
  and public.app_try_uuid((storage.foldername(name))[2]) = auth.uid()
  and public.app_submission_open(public.app_try_uuid((storage.foldername(name))[1]), auth.uid()));
create policy app_submissions_delete on storage.objects for delete to authenticated using (
  bucket_id = 'submissions' and public.app_current_role() = 'student'
  and public.app_try_uuid((storage.foldername(name))[2]) = auth.uid()
  and public.app_submission_open(public.app_try_uuid((storage.foldername(name))[1]), auth.uid())
);

commit;
