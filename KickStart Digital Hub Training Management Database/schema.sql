-- KickStart Digital Hub Training Management Database
-- schema.sql: tables, indexes and views that make up the database.
-- Sample data lives in project.db; example queries live in queries.sql.

-- SQLite only enforces foreign keys when this is switched on (per connection)
PRAGMA foreign_keys = ON;


-- ============================================================
-- TABLES
-- ============================================================

-- Categories (created first because Courses references it)
CREATE TABLE Categories (
    "category_id" INTEGER,
    "name" TEXT NOT NULL UNIQUE,
    "description" TEXT,
    PRIMARY KEY ("category_id")
);


-- Trainees: people enrolled in the training programmes
CREATE TABLE Trainees (
    "trainee_id" INTEGER,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "email" TEXT NOT NULL UNIQUE,
    "date_of_birth" DATE NOT NULL,
    "gender" TEXT CHECK("gender" IN ('male', 'female')),
    "phone_number" VARCHAR(15),
    "registration_date" DATE NOT NULL,
    PRIMARY KEY ("trainee_id")
);


-- Trainers: facilitators who deliver training sessions
CREATE TABLE Trainers (
    "trainer_id" INTEGER,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "phone_number" VARCHAR(15),
    "email" TEXT NOT NULL UNIQUE,
    "specialization" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active' CHECK("status" IN ('active', 'inactive')),
    PRIMARY KEY ("trainer_id")
);


-- Courses: every course offered, grouped by category
CREATE TABLE Courses (
    "course_id" INTEGER,
    "category_id" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "duration" TEXT,
    "level" TEXT CHECK("level" IN ('beginner', 'intermediate', 'advanced')),
    "status" TEXT NOT NULL DEFAULT 'active' CHECK("status" IN ('active', 'inactive')),
    PRIMARY KEY ("course_id"),
    FOREIGN KEY ("category_id") REFERENCES Categories("category_id")
);


-- Sessions: a scheduled run of a course, taught by one trainer
CREATE TABLE Sessions (
    "session_id" INTEGER,
    "course_id" INTEGER NOT NULL,
    "trainer_id" INTEGER NOT NULL,
    "start_date" DATE,
    "end_date" DATE,
    "location" TEXT,
    "mode" TEXT CHECK("mode" IN ('online', 'offline', 'hybrid')),
    "session_title" TEXT,
    PRIMARY KEY ("session_id"),
    FOREIGN KEY ("course_id") REFERENCES Courses("course_id"),
    FOREIGN KEY ("trainer_id") REFERENCES Trainers("trainer_id"),
    CHECK ("end_date" IS NULL OR "end_date" >= "start_date")
);


-- Enrollments: links trainees to the courses they registered for.
-- A trainee can enrol in a given course only once.
-- Whether a certificate was issued is not stored here; it is derived
-- from the Certificates table so the two can never disagree.
CREATE TABLE Enrollments (
    "enrollment_id" INTEGER,
    "trainee_id" INTEGER NOT NULL,
    "course_id" INTEGER NOT NULL,
    "enroll_date" DATE NOT NULL,
    "progress_status" TEXT NOT NULL DEFAULT 'enrolled'
        CHECK("progress_status" IN ('enrolled', 'ongoing', 'completed', 'dropped')),
    "final_score" REAL CHECK("final_score" IS NULL OR "final_score" BETWEEN 0 AND 100),
    "payment_status" TEXT NOT NULL DEFAULT 'unpaid'
        CHECK("payment_status" IN ('paid', 'unpaid', 'partial', 'refunded')),
    PRIMARY KEY ("enrollment_id"),
    FOREIGN KEY ("trainee_id") REFERENCES Trainees("trainee_id"),
    FOREIGN KEY ("course_id") REFERENCES Courses("course_id"),
    UNIQUE ("trainee_id", "course_id")
);


-- Assessments: tests and projects attached to a course
CREATE TABLE Assessments (
    "assessment_id" INTEGER,
    "course_id" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "type" TEXT CHECK("type" IN ('test', 'project')),
    "total_score" INTEGER CHECK("total_score" > 0),
    "due_date" DATE,
    PRIMARY KEY ("assessment_id"),
    FOREIGN KEY ("course_id") REFERENCES Courses("course_id")
);


-- Assessment_Results: one score per trainee per assessment
CREATE TABLE Assessment_Results (
    "result_id" INTEGER,
    "assessment_id" INTEGER NOT NULL,
    "trainee_id" INTEGER NOT NULL,
    "score" REAL CHECK("score" >= 0),
    "submitted_on" DATE,
    "remarks" TEXT,
    PRIMARY KEY ("result_id"),
    FOREIGN KEY ("assessment_id") REFERENCES Assessments("assessment_id"),
    FOREIGN KEY ("trainee_id") REFERENCES Trainees("trainee_id"),
    UNIQUE ("assessment_id", "trainee_id")
);


-- Attendance: whether a trainee was present, late or absent at a session
CREATE TABLE Attendance (
    "attendance_id" INTEGER,
    "trainee_id" INTEGER NOT NULL,
    "session_id" INTEGER NOT NULL,
    "date" DATE NOT NULL,
    "status" TEXT NOT NULL CHECK("status" IN ('present', 'absent', 'late')),
    PRIMARY KEY ("attendance_id"),
    FOREIGN KEY ("trainee_id") REFERENCES Trainees("trainee_id"),
    FOREIGN KEY ("session_id") REFERENCES Sessions("session_id")
);


-- Certificates: issued when an enrollment is completed.
-- The trainee and course come from the linked enrollment, so they are
-- not repeated here (repeating them let the two tables contradict each other).
CREATE TABLE Certificates (
    "certificate_id" INTEGER,
    "enrollment_id" INTEGER NOT NULL UNIQUE,
    "issue_date" DATE NOT NULL,
    "certificate_url" TEXT,
    PRIMARY KEY ("certificate_id"),
    FOREIGN KEY ("enrollment_id") REFERENCES Enrollments("enrollment_id")
);


-- Feedbacks: trainee ratings and comments on a course and its trainer
CREATE TABLE Feedbacks (
    "feedback_id" INTEGER,
    "trainee_id" INTEGER NOT NULL,
    "course_id" INTEGER NOT NULL,
    "trainer_id" INTEGER NOT NULL,
    "rating" INTEGER NOT NULL CHECK("rating" BETWEEN 1 AND 5),
    "comments" TEXT,
    "date_given" DATE NOT NULL,
    PRIMARY KEY ("feedback_id"),
    FOREIGN KEY ("trainee_id") REFERENCES Trainees("trainee_id"),
    FOREIGN KEY ("course_id") REFERENCES Courses("course_id"),
    FOREIGN KEY ("trainer_id") REFERENCES Trainers("trainer_id")
);


-- ============================================================
-- INDEXES
-- UNIQUE columns (trainee email, enrollment pairs, etc.) are indexed
-- automatically, so only foreign-key lookups used by reports are added.
-- ============================================================

-- Enrollment counts and rosters per course
CREATE INDEX "idx_enrollments_course" ON Enrollments("course_id");

-- Sessions per course, and joins from sessions to courses
CREATE INDEX "idx_sessions_course" ON Sessions("course_id");

-- Attendance summary per session
CREATE INDEX "idx_attendance_session" ON Attendance("session_id");

-- Attendance history per trainee
CREATE INDEX "idx_attendance_trainee" ON Attendance("trainee_id");

-- Assessments per course
CREATE INDEX "idx_assessments_course" ON Assessments("course_id");

-- Results per trainee (performance reports)
CREATE INDEX "idx_results_trainee" ON Assessment_Results("trainee_id");

-- Feedback per course and per trainer
CREATE INDEX "idx_feedbacks_course" ON Feedbacks("course_id");
CREATE INDEX "idx_feedbacks_trainer" ON Feedbacks("trainer_id");


-- ============================================================
-- VIEWS
-- ============================================================

-- Active courses with every trainer who teaches them
CREATE VIEW "active_courses" AS
SELECT
    Courses.course_id,
    Courses.title,
    Courses.duration,
    GROUP_CONCAT(DISTINCT Trainers.first_name || ' ' || Trainers.last_name) AS trainers
FROM Courses
JOIN Sessions ON Sessions.course_id = Courses.course_id
JOIN Trainers ON Trainers.trainer_id = Sessions.trainer_id
WHERE Courses.status = 'active'
GROUP BY Courses.course_id, Courses.title, Courses.duration;


-- Present / late / absent counts and attendance rate per session
CREATE VIEW "attendance_summary" AS
SELECT
    Sessions.session_id,
    Courses.title AS course,
    COUNT(CASE WHEN Attendance.status = 'present' THEN 1 END) AS present_count,
    COUNT(CASE WHEN Attendance.status = 'late' THEN 1 END) AS late_count,
    COUNT(CASE WHEN Attendance.status = 'absent' THEN 1 END) AS absent_count,
    ROUND(100.0 * COUNT(CASE WHEN Attendance.status IN ('present', 'late') THEN 1 END)
          / COUNT(*), 1) AS attendance_rate_pct
FROM Attendance
JOIN Sessions ON Attendance.session_id = Sessions.session_id
JOIN Courses ON Sessions.course_id = Courses.course_id
GROUP BY Sessions.session_id, Courses.title;


-- Enrollment, completion, average score and certificates per course
CREATE VIEW "course_summary" AS
SELECT
    Courses.course_id,
    Courses.title,
    Categories.name AS category,
    COUNT(Enrollments.enrollment_id) AS enrollments,
    COUNT(CASE WHEN Enrollments.progress_status = 'completed' THEN 1 END) AS completed,
    COUNT(CASE WHEN Enrollments.progress_status = 'dropped' THEN 1 END) AS dropped,
    ROUND(AVG(Enrollments.final_score), 1) AS avg_final_score,
    COUNT(Certificates.certificate_id) AS certificates_issued
FROM Courses
JOIN Categories ON Categories.category_id = Courses.category_id
LEFT JOIN Enrollments ON Enrollments.course_id = Courses.course_id
LEFT JOIN Certificates ON Certificates.enrollment_id = Enrollments.enrollment_id
GROUP BY Courses.course_id, Courses.title, Categories.name;
