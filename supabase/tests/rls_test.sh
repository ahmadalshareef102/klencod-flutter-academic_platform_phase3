P="psql -X -At -v ON_ERROR_STOP=0 -d ${TEST_DB:-rls_test}"
ADM=00000000-0000-0000-0000-0000000000a1; HEAD=00000000-0000-0000-0000-0000000000b1
T1=00000000-0000-0000-0000-0000000000c1; T2=00000000-0000-0000-0000-0000000000c2
S1=00000000-0000-0000-0000-0000000000d1; S2=00000000-0000-0000-0000-0000000000d2; SX=00000000-0000-0000-0000-0000000000d3
C1=10000000-0000-0000-0000-000000000001; C2=10000000-0000-0000-0000-000000000002
A1=20000000-0000-0000-0000-000000000001; A2=20000000-0000-0000-0000-000000000002
$P -q <<SQL
truncate public.profiles cascade; truncate auth.users cascade;
insert into auth.users select id::uuid from (values ('$ADM'),('$HEAD'),('$T1'),('$T2'),('$S1'),('$S2'),('$SX')) v(id);
insert into public.profiles(id,full_name,email,role,student_number,is_active) values
('$ADM','admin','a@x','admin',null,true),('$HEAD','head','h@x','head',null,true),
('$T1','t1','t1@x','teacher',null,true),('$T2','t2','t2@x','teacher',null,true),
('$S1','s1','s1@x','student','1001',true),('$S2','s2','s2@x','student','1002',true),('$SX','sx','sx@x','student','1003',false);
insert into public.courses(id,code,name,teacher_id,is_published) values ('$C1','C1','c1','$T1',true),('$C2','C2','c2','$T2',true);
insert into public.course_enrollments values ('$C1','$S1',now()),('$C2','$S2',now()),('$C1','$SX',now());
insert into public.lectures(course_id,title,published_at,created_by) values ('$C1','pub',now()-interval '1h','$T1'),('$C1','draft',null,'$T1'),('$C1','future',now()+interval '1 day','$T1');
insert into public.assignments(id,course_id,title,due_at,max_score,created_by) values ('$A1','$C1','a1',now()+interval '1 day',20,'$T1'),('$A2','$C2','a2',now()+interval '1 day',10,'$T2');
insert into public.submissions(assignment_id,student_id,answer_text) values ('$A2','$S2','x');
insert into public.announcements(title,body,audience,created_by) values ('all','b','all','$ADM'),('stu','b','students','$ADM'),('tea','b','teachers','$ADM'),('dep','b','department','$ADM');
insert into public.announcements(title,body,audience,course_id,created_by) values ('c2only','b','all','$C2','$T2');
insert into public.complaints(submitted_by,subject,body) values ('$S1','s','b'),('$S2','s','b');
SQL
pass=0; fail=0
chk(){ # name expected actual
  if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1 (expected [$2] got [$3])"; fi; }
as(){ uid=$1; shift; $P -c "begin; set local role authenticated; select set_config('request.jwt.claim.sub','$uid',true) where false; set local request.jwt.claim.sub = '$uid'; $* ; rollback;" 2>&1 | grep -v -E '^(BEGIN|ROLLBACK|SET|$)' | tr '\n' ' ' | sed 's/ *$//'; }
cnt(){ as "$1" "select count(*) from $2"; }

chk "student sees only unpublished-free lectures (1)" 1 "$(cnt $S1 public.lectures)"
chk "student S1 sees only own submissions (0, S2's hidden)" 0 "$(cnt $S1 public.submissions)"
chk "student S2 sees own submission" 1 "$(cnt $S2 public.submissions)"
chk "student S1 sees own complaint only" 1 "$(cnt $S1 public.complaints)"
chk "student S1 courses (C1 + C2 published)" 2 "$(cnt $S1 public.courses)"
chk "student S1 assignments only enrolled (1)" 1 "$(cnt $S1 public.assignments)"
chk "student S1 announcements: all+stu (2)" 2 "$(cnt $S1 public.announcements)"
chk "teacher T1 announcements: all+tea+dep (3)" 3 "$(cnt $T1 public.announcements)"
chk "teacher T2 sees c2only too (4)" 4 "$(cnt $T2 public.announcements)"
chk "admin sees all announcements (5)" 5 "$(cnt $ADM public.announcements)"
chk "teacher T1 sees only own course lectures (3)" 3 "$(cnt $T1 public.lectures)"
chk "teacher T2 sees no C1 lectures (0)" 0 "$(cnt $T2 public.lectures)"
chk "teacher T1 sees only own-course enrollments (2)" 2 "$(cnt $T1 public.course_enrollments)"
chk "teacher T1 profiles: self+s1+sx+t1,t2,head visible (teachers/head public)" 5 "$(cnt $T1 public.profiles)"
chk "student S1 profiles: self + teachers/head (4)" 4 "$(cnt $S1 public.profiles)"
chk "inactive SX sees no lectures (0)" 0 "$(cnt $SX public.lectures)"
chk "inactive SX sees no courses (0)" 0 "$(cnt $SX public.courses)"
chk "inactive SX sees no announcements (0)" 0 "$(cnt $SX public.announcements)"
chk "inactive SX can still read own profile (1 row among visible: self only)" 1 "$(as $SX "select count(*) from public.profiles where id='$SX'")"
chk "admin sees all profiles (7)" 7 "$(cnt $ADM public.profiles)"

r=$(as $S1 "insert into public.submissions(assignment_id,student_id,answer_text,score) values ('$A1','$S1','x',20)")
chk "student self-grade on insert BLOCKED" 1 "$(echo "$r" | grep -c -E 'row-level security|لا يمكن للطالب')"
r=$(as $S1 "insert into public.submissions(assignment_id,student_id,answer_text) values ('$A1','$S1','ok') returning id")
chk "student legit submit OK" 1 "$(echo "$r" | grep -c -E '[0-9a-f-]{36}')"
r=$(as $S1 "insert into public.submissions(assignment_id,student_id,answer_text) values ('$A2','$S1','x')")
chk "student submit to non-enrolled course BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $S1 "insert into public.submissions(assignment_id,student_id,answer_text) values ('$A1','$S2','x')")
chk "student submit as someone else BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"

# preload S1 submission as superuser for update tests
$P -q -c "insert into public.submissions(assignment_id,student_id,answer_text) values ('$A1','$S1','first')"
r=$(as $S1 "update public.submissions set answer_text='second' where assignment_id='$A1' and student_id='$S1' returning answer_text")
chk "student resubmit before due OK" 1 "$(echo "$r" | grep -c second)"
r=$(as $S1 "update public.submissions set score=20 where assignment_id='$A1' and student_id='$S1'")
chk "student self-grade on update BLOCKED" 1 "$(echo "$r" | grep -c -E 'row-level security|لا يمكن للطالب')"
r=$(as $S1 "update public.submissions set assignment_id='$A2' where assignment_id='$A1' and student_id='$S1'")
chk "student move submission to other assignment BLOCKED" 1 "$(echo "$r" | grep -c -E 'row-level security|لا يمكن')"
$P -q -c "update public.assignments set due_at = now()-interval '1h' where id='$A1'"
r=$(as $S1 "update public.submissions set answer_text='late' where assignment_id='$A1' and student_id='$S1' returning 1")
chk "student edit after due BLOCKED (0 rows)" 0 "$(echo "$r" | grep -c '^1')"
$P -q -c "update public.assignments set due_at = now()+interval '1 day' where id='$A1'"

r=$(as $T1 "update public.submissions set score=15 where assignment_id='$A1' and student_id='$S1' returning score, graded_by")
chk "teacher T1 grades own course OK (graded_by auto)" 1 "$(echo "$r" | grep -c "^15.00|$T1")"
r=$(as $T1 "update public.submissions set score=25 where assignment_id='$A1' and student_id='$S1'")
chk "score above max BLOCKED" 1 "$(echo "$r" | grep -c 'الدرجة يجب')"
r=$(as $T1 "update public.submissions set score=-1 where assignment_id='$A1' and student_id='$S1'")
chk "negative score BLOCKED" 1 "$(echo "$r" | grep -c 'الدرجة يجب')"
r=$(as $T1 "update public.submissions set score=5 where assignment_id='$A2' and student_id='$S2' returning 1")
chk "teacher T1 grading other teacher's course BLOCKED (0 rows)" 0 "$(echo "$r" | grep -c '^1')"
r=$(as $T1 "insert into public.lectures(course_id,title,created_by) values ('$C2','x','$T1')")
chk "teacher adds lecture to other course BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $T1 "insert into public.lectures(course_id,title,created_by,published_at) values ('$C1','mine','$T1',now()) returning 1")
chk "teacher adds lecture to own course OK" 1 "$(echo "$r" | grep -c '^1')"
r=$(as $T1 "insert into public.attendance(course_id,student_id,session_date,status,recorded_by) values ('$C2','$S2',current_date,'present','$T1')")
chk "teacher takes attendance on other course BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $T1 "insert into public.attendance(course_id,student_id,session_date,status,recorded_by) values ('$C1','$S1',current_date,'present','$T1') returning 1")
chk "teacher takes attendance own course OK" 1 "$(echo "$r" | grep -c '^1')"
r=$(as $T1 "insert into public.announcements(title,body,audience,course_id,created_by) values ('x','y','all','$C2','$T1')")
chk "teacher announces on other course BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"

r=$(as $S1 "update public.profiles set role='admin' where id='$S1' returning 1")
chk "student escalates role BLOCKED (0 rows)" 0 "$(echo "$r" | grep -c '^1')"
r=$(as $T1 "update public.profiles set is_active=true where id='$SX' returning 1")
chk "teacher reactivates other BLOCKED (0 rows)" 0 "$(echo "$r" | grep -c '^1')"
r=$(as $ADM "update public.profiles set is_active=false where id='$S2' returning 1")
chk "admin can deactivate OK" 1 "$(echo "$r" | grep -c '^1')"
r=$(as $S1 "insert into public.complaints(submitted_by,subject,body,status) values ('$S1','s','b','resolved')")
chk "student inserts complaint as resolved BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $S1 "insert into public.complaints(submitted_by,subject,body) values ('$S1','s','b') returning 1")
chk "student files complaint OK" 1 "$(echo "$r" | grep -c '^1')"
r=$(as $S1 "update public.complaints set response='x' returning 1")
chk "student updates complaints BLOCKED (0 rows)" 0 "$(echo "$r" | grep -c '^1')"
r=$(as $HEAD "update public.complaints set status='resolved', response='ok', handled_by='$HEAD' returning 1" | head -c 200)
chk "head handles complaints OK" 1 "$(echo "$r" | grep -c '^1')"
r=$(as $S1 "insert into public.courses(code,name) values ('Z','z')")
chk "student creates course BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$(as $S1 "insert into public.course_enrollments values ('$C2','$S1',now())")
chk "student self-enrolls BLOCKED" 1 "$(echo "$r" | grep -c 'row-level security')"
r=$($P -c "insert into public.profiles(id,full_name,email,role,student_number) select gen_random_uuid(),'dup','dup@x','student','1001'" 2>&1)
chk "duplicate student_number rejected" 1 "$(echo "$r" | grep -c 'violates unique')"
echo "TOTAL pass=$pass fail=$fail"
