-- KickStart Digital Hub Training Management Database
-- queries.sql: typical queries staff would run on the database.
-- Every statement runs against project.db. The INSERT, UPDATE and DELETE
-- examples add a sample trainee and then remove her again at the end,
-- so the file can be run repeatedly without changing the data.

PRAGMA foreign_keys = ON;


-- ============================================================
-- LOOKUPS
-- ============================================================

-- All trainees, newest registrations first
SELECT "trainee_id", "first_name", "last_name", "email", "registration_date"
FROM Trainees
ORDER BY "registration_date" DESC;

-- Active courses and who teaches them (uses the active_courses view)
SELECT * FROM active_courses;

-- Session timetable with course and trainer names
SELECT
    Sessions."session_id",
    Courses."title" AS course,
    Trainers."first_name" || ' ' || Trainers."last_name" AS trainer,
    Sessions."start_date",
    Sessions."end_date",
    Sessions."location",
    Sessions."mode"
FROM Sessions
JOIN Courses ON Sessions."course_id" = Courses."course_id"
JOIN Trainers ON Sessions."trainer_id" = Trainers."trainer_id"
ORDER BY Sessions."start_date";

-- Progress report for every trainee, including whether a certificate was issued
SELECT
    Trainees."trainee_id",
    Trainees."first_name" || ' ' || Trainees."last_name" AS trainee,
    Courses."title" AS course,
    Enrollments."progress_status",
    Enrollments."final_score",
    CASE WHEN Certificates."certificate_id" IS NOT NULL THEN 'yes' ELSE 'no' END AS certificate_issued
FROM Enrollments
JOIN Trainees ON Enrollments."trainee_id" = Trainees."trainee_id"
JOIN Courses ON Enrollments."course_id" = Courses."course_id"
LEFT JOIN Certificates ON Certificates."enrollment_id" = Enrollments."enrollment_id"
ORDER BY Trainees."trainee_id";


-- ============================================================
-- REPORTS
-- ============================================================

-- Enrollments, completions, average score and certificates per course
SELECT * FROM course_summary
ORDER BY "enrollments" DESC;

-- Top 10 trainees by final score among completed enrollments
SELECT
    Trainees."first_name" || ' ' || Trainees."last_name" AS trainee,
    Courses."title" AS course,
    Enrollments."final_score"
FROM Enrollments
JOIN Trainees ON Enrollments."trainee_id" = Trainees."trainee_id"
JOIN Courses ON Enrollments."course_id" = Courses."course_id"
WHERE Enrollments."progress_status" = 'completed'
ORDER BY Enrollments."final_score" DESC
LIMIT 10;

-- Attendance rate per session (uses the attendance_summary view)
SELECT * FROM attendance_summary
ORDER BY "attendance_rate_pct";

-- Payment summary: how many enrollments are in each payment state
SELECT "payment_status", COUNT(*) AS enrollments
FROM Enrollments
GROUP BY "payment_status"
ORDER BY enrollments DESC;

-- Trainees who still owe fees on an active enrollment
SELECT
    Trainees."first_name" || ' ' || Trainees."last_name" AS trainee,
    Trainees."phone_number",
    Courses."title" AS course,
    Enrollments."payment_status"
FROM Enrollments
JOIN Trainees ON Enrollments."trainee_id" = Trainees."trainee_id"
JOIN Courses ON Enrollments."course_id" = Courses."course_id"
WHERE Enrollments."payment_status" IN ('unpaid', 'partial')
  AND Enrollments."progress_status" IN ('enrolled', 'ongoing');

-- Completed enrollments still waiting for a certificate
SELECT Enrollments."enrollment_id", Trainees."first_name" || ' ' || Trainees."last_name" AS trainee,
       Courses."title" AS course
FROM Enrollments
JOIN Trainees ON Enrollments."trainee_id" = Trainees."trainee_id"
JOIN Courses ON Enrollments."course_id" = Courses."course_id"
WHERE Enrollments."progress_status" = 'completed'
  AND NOT EXISTS (
      SELECT 1 FROM Certificates
      WHERE Certificates."enrollment_id" = Enrollments."enrollment_id"
  );

-- Average feedback rating per trainer
SELECT
    Trainers."first_name" || ' ' || Trainers."last_name" AS trainer,
    COUNT(*) AS reviews,
    ROUND(AVG(Feedbacks."rating"), 2) AS average_rating
FROM Feedbacks
JOIN Trainers ON Feedbacks."trainer_id" = Trainers."trainer_id"
GROUP BY Trainers."trainer_id"
ORDER BY average_rating DESC;


-- ============================================================
-- INSERT
-- ============================================================

-- Register a new trainee
INSERT INTO Trainees ("first_name", "last_name", "email", "phone_number", "gender", "date_of_birth", "registration_date")
VALUES ('Chiamaka', 'Eze', 'chiamaka.eze@example.com', '08031234567', 'female', '2000-02-14', '2025-01-10');

-- Enrol her in Cybersecurity Fundamentals (course 1), looking her up by email
INSERT INTO Enrollments ("trainee_id", "course_id", "enroll_date", "progress_status", "payment_status")
VALUES (
    (SELECT "trainee_id" FROM Trainees WHERE "email" = 'chiamaka.eze@example.com'),
    1, '2025-01-10', 'ongoing', 'partial'
);

-- Record her result on the Security Fundamentals Test (assessment 1)
INSERT INTO Assessment_Results ("assessment_id", "trainee_id", "score", "submitted_on", "remarks")
VALUES (
    1,
    (SELECT "trainee_id" FROM Trainees WHERE "email" = 'chiamaka.eze@example.com'),
    44.5, '2025-01-24', 'Strong grasp of core concepts'
);


-- ============================================================
-- UPDATE
-- ============================================================

-- Mark her enrollment completed with a final score and full payment
UPDATE Enrollments
SET "progress_status" = 'completed', "final_score" = 88.0, "payment_status" = 'paid'
WHERE "trainee_id" = (SELECT "trainee_id" FROM Trainees WHERE "email" = 'chiamaka.eze@example.com')
  AND "course_id" = 1;

-- Issue her certificate now that the enrollment is completed
INSERT INTO Certificates ("enrollment_id", "issue_date", "certificate_url")
SELECT "enrollment_id", '2025-02-01',
       'https://certs.traininghub.org/cybersecurity-fundamentals/' || "enrollment_id" || '-20250201.pdf'
FROM Enrollments
WHERE "trainee_id" = (SELECT "trainee_id" FROM Trainees WHERE "email" = 'chiamaka.eze@example.com')
  AND "course_id" = 1
  AND "progress_status" = 'completed';


-- ============================================================
-- DELETE
-- ============================================================

-- Remove the sample trainee. Foreign keys block deleting a trainee who
-- still has linked records, so the dependent rows go first, in order.
DELETE FROM Certificates
WHERE "enrollment_id" IN (
    SELECT "enrollment_id" FROM Enrollments
    WHERE "trainee_id" = (SELECT "trainee_id" FROM Trainees WHERE "email" = 'chiamaka.eze@example.com')
);

DELETE FROM Assessment_Results
WHERE "trainee_id" = (SELECT "trainee_id" FROM Trainees WHERE "email" = 'chiamaka.eze@example.com');

DELETE FROM Enrollments
WHERE "trainee_id" = (SELECT "trainee_id" FROM Trainees WHERE "email" = 'chiamaka.eze@example.com');

DELETE FROM Trainees
WHERE "email" = 'chiamaka.eze@example.com';
