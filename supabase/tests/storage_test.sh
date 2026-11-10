# اختبارات صلاحيات Storage (تُشغَّل من run_local.sh بعد rls_test.sh ونفس بياناته).
P="psql -X -At -v ON_ERROR_STOP=0 -d ${TEST_DB:-rls_test}"
T1=00000000-0000-0000-0000-0000000000c1; T2=00000000-0000-0000-0000-0000000000c2
S1=00000000-0000-0000-0000-0000000000d1; S2=00000000-0000-0000-0000-0000000000d2
ADM=00000000-0000-0000-0000-0000000000a1
C1=10000000-0000-0000-0000-000000000001; C2=10000000-0000-0000-0000-000000000002
A1=20000000-0000-0000-0000-000000000001; A2=20000000-0000-0000-0000-000000000002
# إعادة تهيئة حالة بسيطة (rls_test.sh ترك بياناتها؛ نضمن حالة معروفة)
$P -q <<SQL
delete from storage.objects;
delete from public.submissions;
update public.profiles set is_active=true;
delete from public.lectures;
insert into public.lectures(course_id,title,file_path,published_at,created_by) values
 ('$C1','pub','$C1/pub.pdf', now()-interval '1h','$T1'),
 ('$C1','draft','$C1/draft.pdf', null,'$T1');
insert into storage.objects(bucket_id,name) values
 ('lectures','$C1/pub.pdf'),('lectures','$C1/draft.pdf'),('lectures','$C2/other.pdf'),
 ('submissions','$A1/$S1/hw.pdf'),('submissions','$A2/$S2/hw.pdf');
SQL
pass=0; fail=0
chk(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1 (expected [$2] got [$3])"; fi; }
as(){ uid=$1; shift; $P -c "begin; set local role authenticated; set local request.jwt.claim.sub = '$uid'; $* ; rollback;" 2>&1 | grep -v -E '^(BEGIN|ROLLBACK|SET|$)' | tr '\n' ' ' | sed 's/ *$//'; }
ls_(){ as "$1" "select string_agg(name, ',' order by name) from storage.objects where bucket_id='$2'"; }

chk "S1 sees only the published lecture file of own course" "$C1/pub.pdf" "$(ls_ $S1 lectures)"
chk "S2 (not enrolled in C1) sees only own-course files: none published" "" "$(ls_ $S2 lectures)"
chk "T1 sees its course files (pub+draft), not C2" "$C1/draft.pdf,$C1/pub.pdf" "$(ls_ $T1 lectures)"
chk "admin sees all lecture files (3)" "3" "$(as $ADM "select count(*) from storage.objects where bucket_id='lectures'")"
chk "S1 sees only own submission file" "$A1/$S1/hw.pdf" "$(ls_ $S1 submissions)"
chk "T1 sees submissions of own course only" "$A1/$S1/hw.pdf" "$(ls_ $T1 submissions)"
chk "T2 sees submissions of own course only" "$A2/$S2/hw.pdf" "$(ls_ $T2 submissions)"

r=$(as $T1 "insert into storage.objects(bucket_id,name) values ('lectures','$C1/new.pdf') returning 1")
chk "T1 uploads lecture file to own course OK" 1 "$(echo "$r" | grep -c '^1')"
r=$(as $T1 "insert into storage.objects(bucket_id,name) values ('lectures','$C2/x.pdf')")
chk "T1 uploads to other course BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $S1 "insert into storage.objects(bucket_id,name) values ('lectures','$C1/s.pdf')")
chk "student uploads lecture file BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $S1 "insert into storage.objects(bucket_id,name) values ('lectures','not-a-uuid/x.pdf')")
chk "garbage path BLOCKED without error leak" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $S1 "delete from storage.objects where bucket_id='lectures' returning 1")
chk "student deletes lecture files BLOCKED (0 rows)" 0 "$(echo "$r" | grep -c '^1')"

r=$(as $S1 "insert into storage.objects(bucket_id,name) values ('submissions','$A1/$S1/new.pdf') returning 1")
chk "S1 uploads own submission file OK" 1 "$(echo "$r" | grep -c '^1')"
r=$(as $S1 "insert into storage.objects(bucket_id,name) values ('submissions','$A1/$S2/new.pdf')")
chk "S1 uploads into someone else's folder BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $S1 "insert into storage.objects(bucket_id,name) values ('submissions','$A2/$S1/new.pdf')")
chk "S1 uploads to assignment of non-enrolled course BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $T1 "insert into storage.objects(bucket_id,name) values ('submissions','$A1/$S1/t.pdf')")
chk "teacher uploads into submissions BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $S1 "delete from storage.objects where bucket_id='submissions' and name='$A1/$S1/hw.pdf' returning 1")
chk "S1 replaces/deletes own file before grading OK" 1 "$(echo "$r" | grep -c '^1')"
# بعد رصد الدرجة: الطالب لا يستطيع التعديل
$P -q -c "insert into public.submissions(assignment_id,student_id,answer_text,score,graded_by) values ('$A1','$S1','x',10,'$T1')"
r=$(as $S1 "delete from storage.objects where bucket_id='submissions' and name='$A1/$S1/hw.pdf' returning 1")
chk "S1 deletes file after grading BLOCKED (0 rows)" 0 "$(echo "$r" | grep -c '^1')"
r=$(as $S1 "insert into storage.objects(bucket_id,name) values ('submissions','$A1/$S1/after.pdf')")
chk "S1 uploads after grading BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
# موقوف
$P -q -c "update public.profiles set is_active=false where id='$S1'"
chk "inactive S1 sees no lecture files" "" "$(ls_ $S1 lectures)"
chk "inactive S1 sees no submission files" "" "$(ls_ $S1 submissions)"
chk "buckets are private and limited to 20MB" "false|20971520|false|20971520" "$($P -c "select string_agg(public::text||'|'||file_size_limit, '|' order by id) from storage.buckets")"
echo "STORAGE pass=$pass fail=$fail"
