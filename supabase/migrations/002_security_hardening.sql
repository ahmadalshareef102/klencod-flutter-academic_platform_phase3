-- ============================================================================
-- 002_security_hardening.sql
-- تحصين سياسات RLS للمنصة الأكاديمية.
-- شروط التنفيذ: نفّذ schema.sql ثم schema_patch.sql أولًا (إن لم تكن نفّذتهما).
-- الملف قابل للتنفيذ أكثر من مرة بأمان، ولا يحذف أي جدول أو بيانات.
-- نفّذه أولًا على مشروع Supabase تجريبي، ثم على المشروع الحقيقي بعد المراجعة.
-- تنبيه: لا تعِد تنفيذ schema.sql أو schema_patch.sql بعد هذا الملف، لأنهما يعيدان السياسات القديمة.
-- الاختبار: bash supabase/tests/run_local.sh (على PostgreSQL محلي، 47 فحصًا لصلاحيات الأدوار).
-- ============================================================================

begin;

-- ───────────────────────── 1) دوال مساعدة (security definer مع search_path ثابت) ─────────────────────────

-- دور المستخدم الحالي إن كان حسابه نشطًا، وإلا null.
create or replace function public.app_current_role()
returns text language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() and is_active = true limit 1 $$;

-- هل المستخدم الحالي نشط؟
create or replace function public.app_is_active()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles where id = auth.uid() and is_active = true) $$;

-- هل المستخدم الحالي مدرّس هذا المقرر؟
create or replace function public.app_teaches(p_course uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.courses c
  join public.profiles p on p.id = auth.uid() and p.is_active = true and p.role = 'teacher'
  where c.id = p_course and c.teacher_id = auth.uid()) $$;

-- هل المستخدم الحالي طالب مسجل في هذا المقرر؟
create or replace function public.app_enrolled(p_course uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.course_enrollments e
  join public.profiles p on p.id = auth.uid() and p.is_active = true
  where e.course_id = p_course and e.student_id = auth.uid()) $$;

-- هل هذا الطالب مسجل في أحد مقررات المدرّس الحالي؟
create or replace function public.app_teacher_has_student(p_student uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.course_enrollments e
  join public.courses c on c.id = e.course_id
  where e.student_id = p_student and c.teacher_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active = true and p.role = 'teacher')) $$;

-- مقرر التكليف (لتجنب تكرار الربط في السياسات).
create or replace function public.app_assignment_course(p_assignment uuid)
returns uuid language sql stable security definer set search_path = public
as $$ select course_id from public.assignments where id = p_assignment $$;

revoke all on function public.app_current_role(), public.app_is_active(), public.app_teaches(uuid),
  public.app_enrolled(uuid), public.app_teacher_has_student(uuid), public.app_assignment_course(uuid) from public, anon;
grant execute on function public.app_current_role(), public.app_is_active(), public.app_teaches(uuid),
  public.app_enrolled(uuid), public.app_teacher_has_student(uuid), public.app_assignment_course(uuid) to authenticated;

-- ───────────────────────── 2) إسقاط السياسات القديمة (بما فيها سياسات schema_patch) ─────────────────────────

do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles','courses','course_enrollments','lectures','assignments',
                        'submissions','attendance','announcements','complaints','course_progress')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- ───────────────────────── 3) السياسات الجديدة ─────────────────────────

-- profiles ------------------------------------------------------------------
-- القراءة: الشخص نفسه (حتى لو موقوف ليظهر له سبب الرفض)، الإدارة ورئيس القسم للجميع،
-- المدرس لطلاب مقرراته، والجميع يرون أسماء المدرسين ورؤساء الأقسام النشطين.
create policy profiles_select on public.profiles for select to authenticated using (
  id = auth.uid()
  or public.app_current_role() in ('admin','head')
  or (public.app_current_role() = 'teacher' and public.app_teacher_has_student(id))
  or (role in ('teacher','head') and is_active = true and public.app_is_active())
);
-- التعديل والإضافة والحذف للإدارة فقط (يمنع أي مستخدم من تغيير دوره أو تفعيل نفسه).
create policy profiles_admin_manage on public.profiles for all to authenticated
using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');

-- courses -------------------------------------------------------------------
create policy courses_select on public.courses for select to authenticated using (
  public.app_current_role() in ('admin','head')
  or public.app_teaches(id)
  or public.app_enrolled(id)
  or (is_published = true and public.app_is_active())
);
create policy courses_manage on public.courses for all to authenticated
using (public.app_current_role() in ('admin','head')) with check (public.app_current_role() in ('admin','head'));

-- course_enrollments --------------------------------------------------------
create policy enrollments_select on public.course_enrollments for select to authenticated using (
  public.app_current_role() in ('admin','head')
  or public.app_teaches(course_id)
  or (student_id = auth.uid() and public.app_is_active())
);
create policy enrollments_manage on public.course_enrollments for all to authenticated
using (public.app_current_role() in ('admin','head')) with check (public.app_current_role() in ('admin','head'));

-- lectures ------------------------------------------------------------------
-- الطالب يرى المحاضرات المنشورة فقط (published_at موجود وليس في المستقبل).
create policy lectures_select on public.lectures for select to authenticated using (
  public.app_current_role() in ('admin','head')
  or public.app_teaches(course_id)
  or (public.app_enrolled(course_id) and published_at is not null and published_at <= now())
);
-- المدرس يضيف ويعدل محاضرات مقرراته هو فقط.
create policy lectures_manage on public.lectures for all to authenticated
using (public.app_current_role() in ('admin','head') or public.app_teaches(course_id))
with check (public.app_current_role() in ('admin','head') or (public.app_teaches(course_id) and created_by = auth.uid()));

-- assignments ---------------------------------------------------------------
create policy assignments_select on public.assignments for select to authenticated using (
  public.app_current_role() in ('admin','head')
  or public.app_teaches(course_id)
  or public.app_enrolled(course_id)
);
create policy assignments_manage on public.assignments for all to authenticated
using (public.app_current_role() in ('admin','head') or public.app_teaches(course_id))
with check (public.app_current_role() in ('admin','head') or (public.app_teaches(course_id) and created_by = auth.uid()));

-- submissions ---------------------------------------------------------------
create policy submissions_select on public.submissions for select to authenticated using (
  public.app_current_role() in ('admin','head')
  or public.app_teaches(public.app_assignment_course(assignment_id))
  or (student_id = auth.uid() and public.app_is_active())
);
-- الطالب يسلّم لنفسه ولتكليف في مقرر مسجل به، دون درجة أو ملاحظات.
create policy submissions_student_insert on public.submissions for insert to authenticated with check (
  public.app_current_role() = 'student'
  and student_id = auth.uid()
  and public.app_enrolled(public.app_assignment_course(assignment_id))
  and score is null and feedback is null and graded_by is null
);
-- الطالب يعدّل تسليمه قبل رصد الدرجة وقبل موعد الاستحقاق فقط.
create policy submissions_student_update on public.submissions for update to authenticated
using (
  public.app_current_role() = 'student' and student_id = auth.uid() and score is null
  and exists (select 1 from public.assignments a where a.id = assignment_id and (a.due_at is null or now() <= a.due_at))
)
with check (
  public.app_current_role() = 'student' and student_id = auth.uid()
  and score is null and feedback is null and graded_by is null
);
-- التصحيح: الإدارة ورئيس القسم أو مدرس المقرر نفسه.
create policy submissions_staff_update on public.submissions for update to authenticated
using (public.app_current_role() in ('admin','head') or public.app_teaches(public.app_assignment_course(assignment_id)))
with check (public.app_current_role() in ('admin','head') or public.app_teaches(public.app_assignment_course(assignment_id)));

-- مشغّل حماية: يمنع تجاوز الدرجة العظمى، ويثبت الحقول التي لا يجوز للطالب تغييرها،
-- ويسجل المصحّح تلقائيًا.
create or replace function public.submissions_guard()
returns trigger language plpgsql security definer set search_path = public
as $$
declare v_max numeric;
begin
  if public.app_current_role() = 'student' then
    if new.score is not null or new.feedback is not null or new.graded_by is not null then
      raise exception 'لا يمكن للطالب رصد الدرجة أو الملاحظات.';
    end if;
    if tg_op = 'UPDATE' and (new.assignment_id <> old.assignment_id or new.student_id <> old.student_id) then
      raise exception 'لا يمكن تغيير التكليف أو صاحب التسليم.';
    end if;
  end if;
  if new.score is not null then
    select max_score into v_max from public.assignments where id = new.assignment_id;
    if new.score < 0 or new.score > coalesce(v_max, 0) then
      raise exception 'الدرجة يجب أن تكون بين 0 و %.', coalesce(v_max, 0);
    end if;
    if public.app_current_role() in ('admin','head','teacher') then
      new.graded_by := auth.uid();
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_submissions_guard on public.submissions;
create trigger trg_submissions_guard before insert or update on public.submissions
for each row execute function public.submissions_guard();

-- attendance ----------------------------------------------------------------
create policy attendance_select on public.attendance for select to authenticated using (
  public.app_current_role() in ('admin','head')
  or public.app_teaches(course_id)
  or (student_id = auth.uid() and public.app_is_active())
);
create policy attendance_manage on public.attendance for all to authenticated
using (public.app_current_role() in ('admin','head') or public.app_teaches(course_id))
with check (public.app_current_role() in ('admin','head') or public.app_teaches(course_id));

-- announcements -------------------------------------------------------------
-- الاستهداف: all للجميع، students للطلاب، teachers للمدرسين، department للموظفين.
-- إعلان مرتبط بمقرر لا يراه إلا المسجلون فيه أو مدرسه أو الإدارة.
create policy announcements_select on public.announcements for select to authenticated using (
  public.app_is_active() and (
    created_by = auth.uid()
    or public.app_current_role() in ('admin','head')
    or (
      (course_id is null or public.app_teaches(course_id) or public.app_enrolled(course_id))
      and (
        audience = 'all'
        or (audience = 'students' and public.app_current_role() = 'student')
        or (audience in ('teachers','department') and public.app_current_role() = 'teacher')
      )
    )
  )
);
create policy announcements_manage on public.announcements for all to authenticated
using (
  public.app_current_role() in ('admin','head')
  or (public.app_current_role() = 'teacher' and created_by = auth.uid())
)
with check (
  public.app_current_role() in ('admin','head')
  or (public.app_current_role() = 'teacher' and created_by = auth.uid()
      and (course_id is null or public.app_teaches(course_id)))
);

-- complaints ----------------------------------------------------------------
create policy complaints_select on public.complaints for select to authenticated using (
  public.app_current_role() in ('admin','head')
  or (submitted_by = auth.uid() and public.app_is_active())
);
create policy complaints_insert on public.complaints for insert to authenticated with check (
  submitted_by = auth.uid() and public.app_is_active()
  and status = 'new' and response is null and handled_by is null
);
create policy complaints_staff_update on public.complaints for update to authenticated
using (public.app_current_role() in ('admin','head')) with check (public.app_current_role() in ('admin','head'));

-- course_progress -----------------------------------------------------------
create policy progress_select on public.course_progress for select to authenticated using (
  public.app_current_role() in ('admin','head')
  or public.app_teaches(course_id)
  or public.app_enrolled(course_id)
);
create policy progress_manage on public.course_progress for all to authenticated
using (public.app_current_role() in ('admin','head') or (public.app_teaches(course_id) and teacher_id = auth.uid()))
with check (public.app_current_role() in ('admin','head') or (public.app_teaches(course_id) and teacher_id = auth.uid()));

-- ───────────────────────── 4) قيود إضافية ─────────────────────────

-- تفرّد رقم الطالب (فقط إن لم توجد تكرارات حاليًا؛ وإلا يُطبع تنبيه لتصحيحها يدويًا ثم أعد التنفيذ).
do $$
begin
  create unique index if not exists profiles_student_number_uniq
    on public.profiles (student_number) where student_number is not null and student_number <> '';
exception when unique_violation then
  raise notice 'يوجد student_number مكرر في profiles. صحّح التكرارات ثم أعد تنفيذ هذا الملف.';
end $$;

-- ───────────────────────── 5) حذف الدالة القديمة (لم تعد مستخدمة) ─────────────────────────
drop function if exists public.current_role();

commit;
