-- KickStart Digital Hub Training Management Database
-- data_cleaning.sql: the audit and fixes applied to the original sample data.
--
-- Part 1 contains checks that find data problems. Run them any time; each
-- should return 0 (or no rows) on the cleaned project.db.
-- Part 2 contains the fixes that were run once against the original data,
-- kept here as a record of what was changed and why.


-- ============================================================
-- PART 1: DATA QUALITY CHECKS
-- ============================================================

-- 1. Trainees sharing an email address
SELECT LOWER("email") AS email, COUNT(*) AS copies
FROM Trainees
GROUP BY LOWER("email")
HAVING COUNT(*) > 1;

-- 2. Trainees enrolled in the same course more than once
SELECT "trainee_id", "course_id", COUNT(*) AS copies
FROM Enrollments
GROUP BY "trainee_id", "course_id"
HAVING COUNT(*) > 1;

-- 3. More than one result for the same trainee and assessment
SELECT "assessment_id", "trainee_id", COUNT(*) AS copies
FROM Assessment_Results
GROUP BY "assessment_id", "trainee_id"
HAVING COUNT(*) > 1;

-- 4. Dates that are not real calendar dates (e.g. 31 June, month 13)
SELECT 'Trainees.registration_date' AS field, "registration_date" AS value
FROM Trainees WHERE DATE("registration_date") IS NOT "registration_date"
UNION ALL
SELECT 'Assessment_Results.submitted_on', "submitted_on"
FROM Assessment_Results WHERE DATE("submitted_on") IS NOT "submitted_on";

-- 5. Certificates attached to enrollments that were never completed
SELECT Certificates."certificate_id", Enrollments."enrollment_id", Enrollments."progress_status"
FROM Certificates
JOIN Enrollments ON Enrollments."enrollment_id" = Certificates."enrollment_id"
WHERE Enrollments."progress_status" != 'completed';

-- 6. Scores stored as text instead of numbers
SELECT "enrollment_id", "final_score"
FROM Enrollments
WHERE TYPEOF("final_score") NOT IN ('integer', 'real', 'null');

-- 7. Rows that point to a trainee, course or enrollment that does not exist
PRAGMA foreign_key_check;


-- Checks below flag records worth reviewing against the source records.
-- They are reported, not deleted, because the correct value is unknown.

-- 8. Attendance for a session of a course the trainee is not enrolled in
SELECT COUNT(*) AS attendance_without_enrollment
FROM Attendance
WHERE NOT EXISTS (
    SELECT 1 FROM Sessions
    JOIN Enrollments ON Enrollments."course_id" = Sessions."course_id"
    WHERE Sessions."session_id" = Attendance."session_id"
      AND Enrollments."trainee_id" = Attendance."trainee_id"
);

-- 9. Assessment results for a course the trainee is not enrolled in
SELECT COUNT(*) AS results_without_enrollment
FROM Assessment_Results
WHERE NOT EXISTS (
    SELECT 1 FROM Assessments
    JOIN Enrollments ON Enrollments."course_id" = Assessments."course_id"
    WHERE Assessments."assessment_id" = Assessment_Results."assessment_id"
      AND Enrollments."trainee_id" = Assessment_Results."trainee_id"
);

-- 10. Session titles beside the course each session is linked to, for a
-- manual review. Sessions 14, 15 and 16 look shifted by one course
-- (e.g. "Office Suite Mastery" is linked to Full-Stack Development).
SELECT Sessions."session_id", Sessions."session_title", Courses."title" AS linked_course
FROM Sessions
JOIN Courses ON Courses."course_id" = Sessions."course_id"
ORDER BY Sessions."session_id";

-- 11. Sessions lasting more than six months (sessions 4 and 5 end in
-- December 2025, which may be a typo for December 2024)
SELECT "session_id", "session_title", "start_date", "end_date"
FROM Sessions
WHERE JULIANDAY("end_date") - JULIANDAY("start_date") > 183;


-- ============================================================
-- PART 2: FIXES APPLIED TO THE ORIGINAL DATA (already run)
-- ============================================================

BEGIN TRANSACTION;

-- Fix 1: Duplicate trainees.
-- Trainees 370 and 371 were exact copies of trainee 1, and 372 an exact copy
-- of 369, created by running the sample INSERTs more than once. None had
-- linked records, so they were removed.
DELETE FROM Trainees WHERE "trainee_id" IN (370, 371, 372);

-- Trainee 369's email had a typo ("gamil") and inconsistent capitalisation.
UPDATE Trainees SET "email" = 'adeze.damilola@gmail.com' WHERE "trainee_id" = 369;

-- Trainees 195 and 245 are different people (different birth dates and phone
-- numbers) who shared one email. Trainee 245 was given a distinct email so
-- the UNIQUE rule can be enforced.
UPDATE Trainees SET "email" = 'umar.quadri2@gmail.com' WHERE "trainee_id" = 245;

-- Fix 2: Duplicate enrollments.
-- Enrollments 370-375 repeated 365-367 exactly. Enrollment 369 repeated
-- trainee 369's enrollment in course 19 (368). The earliest copy was kept.
DELETE FROM Enrollments WHERE "enrollment_id" IN (369, 370, 371, 372, 373, 374, 375);

-- Session 20 was an exact copy of session 19 (the sample "schedule new
-- session" INSERT run twice) with no attendance linked to it. Session 19's
-- title was also missing its final "s".
DELETE FROM Sessions WHERE "session_id" = 20;
UPDATE Sessions SET "session_title" = 'Cybersecurity Fundamentals' WHERE "session_id" = 19;

-- Fix 3: Duplicate assessment results.
-- 27 pairs were exact copies. 3 pairs (trainee 98 on assessment 8, 111 on 11,
-- 217 on 17) had two different scores on the same day; the first recorded
-- result was kept and these three should be checked against source records.
DELETE FROM Assessment_Results
WHERE "result_id" NOT IN (
    SELECT MIN("result_id") FROM Assessment_Results
    GROUP BY "assessment_id", "trainee_id"
);

-- Fix 4: Invalid dates.
-- 42 trainees were registered on 2024-06-31, which does not exist.
UPDATE Trainees SET "registration_date" = '2024-06-30'
WHERE "registration_date" = '2024-06-31';

-- One result was submitted on 2024-13-01. The assessment was due 2024-12-01,
-- so that date was used.
UPDATE Assessment_Results SET "submitted_on" = '2024-12-01'
WHERE "submitted_on" = '2024-13-01';

-- Fix 5: Certificates that break the "issued on completion" rule.
-- 16 certificates belonged to enrollments that were dropped, ongoing or only
-- enrolled. 22 more named a trainee and course that did not match their
-- enrollment, and those trainees had no enrollment in the named course at all.
-- Both groups were removed (38 in total).
DELETE FROM Certificates
WHERE "enrollment_id" IN (
    SELECT "enrollment_id" FROM Enrollments WHERE "progress_status" != 'completed'
)
OR "certificate_id" IN (
    SELECT Certificates."certificate_id"
    FROM Certificates
    JOIN Enrollments ON Enrollments."enrollment_id" = Certificates."enrollment_id"
    WHERE Certificates."trainee_id" != Enrollments."trainee_id"
       OR Certificates."course_id" != Enrollments."course_id"
);

-- Fix 6: A stray double quote used as an apostrophe in feedback text.
UPDATE Feedbacks SET "comments" = REPLACE("comments", 'Similoluwa"s', 'Similoluwa''s')
WHERE "feedback_id" = 3;

-- Fix 7: A missing score stored as the text 'NULL' instead of a real NULL.
-- Text in a number column breaks averages and the 0-100 CHECK rule.
UPDATE Enrollments SET "final_score" = NULL
WHERE TYPEOF("final_score") = 'text' AND UPPER("final_score") = 'NULL';

COMMIT;

-- Fix 8: Redundant columns removed.
-- Enrollments.certificate_issued and Certificates.trainee_id / course_id
-- repeated facts already held elsewhere, which is how the mismatches in
-- Fix 5 arose. project.db was then rebuilt from schema.sql (which drops
-- those columns and adds the UNIQUE and CHECK rules) and the cleaned rows
-- were copied in.
