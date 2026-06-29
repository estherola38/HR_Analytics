-- SECTION 1: TABLE CREATION

-- Create and switch to the database
USE hr_analytics;
GO
 
-- Drop table if it already exists
IF OBJECT_ID('dbo.employees', 'U') IS NOT NULL
    DROP TABLE dbo.employees;
GO
 
CREATE TABLE employees (
    id              VARCHAR(20)   PRIMARY KEY,
    first_name      VARCHAR(50),
    last_name       VARCHAR(50),
    birthdate       VARCHAR(20),    -- raw text; cleaned in Section 2
    gender          VARCHAR(20),
    race            VARCHAR(60),
    department      VARCHAR(60),
    jobtitle        VARCHAR(100),
    location        VARCHAR(30),
    hire_date       VARCHAR(20),    -- raw text; cleaned in Section 2
    termdate        VARCHAR(40),    -- raw timestamp string; cleaned in Section 2
    location_city   VARCHAR(60),
    location_state  VARCHAR(60)
);
GO
 

 
 
-- SECTION 2: DATA CLEANING

-- 2a. Add cleaned date columns
ALTER TABLE employees ADD birthdate_clean  DATE;
ALTER TABLE employees ADD hire_date_clean  DATE;
ALTER TABLE employees ADD termdate_clean   DATE;
ALTER TABLE employees ADD active_status        BIT;   -- BIT = 1 (active) or 0 (terminated)
GO
 
-- 2b. Parse birthdate
--     Raw formats: 'MM-DD-YY' (e.g. 06-04-91) and 'M/D/YYYY' (e.g. 6/29/1984)
UPDATE employees
SET birthdate = CASE
    -- Format: MM-DD-YY → convert dashes to slashes then parse
    WHEN birthdate LIKE '__-__-__'
        THEN TRY_CONVERT(DATE,
                SUBSTRING(birthdate,7,2) + '/' +
                SUBSTRING(birthdate,1,2) + '/' +
                SUBSTRING(birthdate,4,2),
             1)
    -- Format: M/D/YYYY or MM/DD/YYYY
    WHEN birthdate LIKE '%/%/%'
        THEN TRY_CONVERT(DATE, birthdate, 1)
    ELSE NULL
END;
GO
 
-- 2c. Parse hire_date (same formats as birthdate)
UPDATE employees
SET hire_date_clean = CASE
    WHEN hire_date LIKE '__-__-__'
        THEN TRY_CONVERT(DATE,
                SUBSTRING(hire_date,7,2) + '/' +
                SUBSTRING(hire_date,1,2) + '/' +
                SUBSTRING(hire_date,4,2),
             1)
    WHEN hire_date LIKE '%/%/%'
        THEN TRY_CONVERT(DATE, hire_date, 1)
    ELSE NULL
END;
GO

-- 2d. Parse termdate
--     Raw format: 'YYYY-MM-DD HH:MM:SS UTC'  →  grab only the date part before the first space
UPDATE employees
SET termdate_clean = CASE
    WHEN termdate IS NOT NULL AND termdate <> ''
        THEN TRY_CONVERT(DATE, LEFT(termdate, 10), 23)  -- style 23 = YYYY-MM-DD
    ELSE NULL
END;
GO
 
-- 2e. Set active status
--     active_status = 1  →  still employed
--     active_status = 0  →  terminated
UPDATE employees
SET active_status = CAST(
    CASE
        WHEN termdate_clean IS NULL          THEN 1
        WHEN termdate_clean > GETDATE()      THEN 1
        ELSE 0
    END
AS BIT);
GO
 
-- 2f. Quick data-quality check — run this to confirm cleaning worked
SELECT
    COUNT(*)                                                  AS total_records,
    SUM(CASE WHEN birthdate_clean  IS NULL THEN 1 ELSE 0 END) AS bad_birthdates,
    SUM(CASE WHEN hire_date_clean  IS NULL THEN 1 ELSE 0 END) AS bad_hire_dates,
    SUM(CASE WHEN active_status = 1            THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN active_status = 0            THEN 1 ELSE 0 END) AS terminated_employees
FROM employees;
GO
 
 

-- SECTION 3: EMPLOYEE PERFORMANCE ANALYSIS
 
-- 3a. Headcount by Department
SELECT
    department,
    COUNT(*)                                                   AS total_employees,
    SUM(CASE WHEN active_status = 1 THEN 1 ELSE 0 END)            AS active,
    SUM(CASE WHEN active_status = 0 THEN 1 ELSE 0 END)            AS terminated,
    ROUND(
        100.0 * SUM(CASE WHEN active_status = 1 THEN 1 ELSE 0 END) / COUNT(*), 1
    )                                                          AS retention_rate_pct
FROM employees
GROUP BY department
ORDER BY total_employees DESC;
GO
 
 
-- 3b. Top 10 Most Common Job Titles (active employees only)
SELECT TOP 10
    jobtitle,
    COUNT(*) AS headcount
FROM employees
WHERE active_status = 1
GROUP BY jobtitle
ORDER BY headcount DESC;
GO
 
 
-- 3c. Workforce Distribution by Location (HQ vs Remote)
SELECT
    location,
    COUNT(*)                                        AS total,
    SUM(CASE WHEN active_status = 1 THEN 1 ELSE 0 END) AS active,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1
    )                                               AS pct_of_workforce
FROM employees
GROUP BY location
ORDER BY total DESC;
GO

-- 3b. Top 10 Most Common Job Titles (active employees only)
SELECT TOP 10
    jobtitle,
    COUNT(*) AS headcount
FROM employees
WHERE active_status = 1
GROUP BY jobtitle
ORDER BY headcount DESC;
GO
 
 
-- 3c. Workforce Distribution by Location (HQ vs Remote)
SELECT
    location,
    COUNT(*)                                        AS total,
    SUM(CASE WHEN active_status = 1 THEN 1 ELSE 0 END) AS active,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1
    )                                               AS pct_of_workforce
FROM employees
GROUP BY location
ORDER BY total DESC;
GO
 
 
-- 3d. Gender Breakdown Across Departments
SELECT
    department,
    gender,
    COUNT(*) AS headcount,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY department), 1
    )        AS pct_in_dept
FROM employees
WHERE active_status = 1
GROUP BY department, gender
ORDER BY department, headcount DESC;
GO
 
 
-- 3e. Racial Diversity Breakdown (active employees)
SELECT
    race,
    COUNT(*)                                               AS headcount,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_total
FROM employees
WHERE active_status = 1
GROUP BY race
ORDER BY headcount DESC;
GO
 
 

-- SECTION 4: RETENTION ANALYSIS
 
-- 4a. Retention Rate by Year of Hire  (uses a CTE)
WITH cohort AS (
    SELECT
        YEAR(hire_date_clean)                                  AS hire_year,
        COUNT(*)                                               AS hired,
        SUM(CASE WHEN active_status = 1 THEN 1 ELSE 0 END)        AS still_active
    FROM employees
    WHERE hire_date_clean IS NOT NULL
    GROUP BY YEAR(hire_date_clean)
)
SELECT
    hire_year,
    hired,
    still_active,
    hired - still_active                            AS left_company,
    ROUND(100.0 * still_active / hired, 1)          AS retention_pct
FROM cohort
ORDER BY hire_year;
GO
 
 
-- 4b. Average Tenure by Department  (uses a CTE)
--     Tenure = years from hire_date to termdate (or today if still active)
WITH tenure_calc AS (
    SELECT
        department,
        id,
        hire_date_clean,
        termdate_clean,
        active_status,
        ROUND(
            DATEDIFF(DAY,
                hire_date_clean,
                COALESCE(termdate_clean, CAST(GETDATE() AS DATE))
            ) / 365.25, 1
        ) AS tenure_years
    FROM employees
    WHERE hire_date_clean IS NOT NULL
)
SELECT
    department,
    COUNT(*)                        AS employees,
    ROUND(AVG(tenure_years), 1)     AS avg_tenure_years,
    ROUND(MIN(tenure_years), 1)     AS min_tenure_years,
    ROUND(MAX(tenure_years), 1)     AS max_tenure_years
FROM tenure_calc
GROUP BY department
ORDER BY avg_tenure_years DESC;
GO
 
 -- 4c. Monthly Termination Trend (last 5 years)
SELECT
    DATEFROMPARTS(YEAR(termdate_clean), MONTH(termdate_clean), 1) AS termination_month,
    COUNT(*) AS terminations
FROM employees
WHERE termdate_clean IS NOT NULL
  AND termdate_clean <= GETDATE()
  AND termdate_clean >= DATEADD(YEAR, -5, GETDATE())
GROUP BY DATEFROMPARTS(YEAR(termdate_clean), MONTH(termdate_clean), 1)
ORDER BY termination_month;
GO
 
 
-- 4d. Turnover Rate by Department
SELECT
    department,
    COUNT(*)                                                    AS total_employees,
    SUM(CASE WHEN active_status = 0 THEN 1 ELSE 0 END)             AS terminated,
    ROUND(
        100.0 * SUM(CASE WHEN active_status = 0 THEN 1 ELSE 0 END) / COUNT(*), 1
    )                                                           AS turnover_rate_pct
FROM employees
GROUP BY department
ORDER BY turnover_rate_pct DESC;
GO
 
 

-- SECTION 5: SALARY / SENIORITY ANALYSIS
-- Note: No salary column in this dataset.
-- Tenure is used as a seniority proxy.
-- Bands: Junior (<3 yrs) | Mid (3-7 yrs) | Senior (7+ yrs)

-- 5a. Seniority Band Distribution per Department  (uses 2 CTEs)
WITH seniority AS (
    SELECT
        id,
        department,
        jobtitle,
        gender,
        location,
        ROUND(
            DATEDIFF(DAY, hire_date_clean, CAST(GETDATE() AS DATE)) / 365.25, 1
        ) AS tenure_years
    FROM employees
    WHERE hire_date_clean IS NOT NULL
      AND active_status = 1
),
banded AS (
    SELECT
        *,
        CASE
            WHEN tenure_years < 3  THEN '1 - Junior (<3 yrs)'
            WHEN tenure_years < 7  THEN '2 - Mid (3-7 yrs)'
            ELSE                        '3 - Senior (7+ yrs)'
        END AS seniority_band
    FROM seniority
)
SELECT
    department,
    seniority_band,
    COUNT(*) AS headcount
FROM banded
GROUP BY department, seniority_band
ORDER BY department, seniority_band;
GO
 
 
-- 5b. Top 5 Longest-Tenured Active Employees per Department
--     Uses WINDOW FUNCTION: RANK() OVER (PARTITION BY department)
WITH tenure_ranked AS (
    SELECT
        id,
        first_name + ' ' + last_name    AS full_name,
        department,
        jobtitle,
        hire_date_clean,
        ROUND(
            DATEDIFF(DAY, hire_date_clean, CAST(GETDATE() AS DATE)) / 365.25, 1
        )                               AS tenure_years,
        RANK() OVER (
            PARTITION BY department
            ORDER BY hire_date_clean ASC
        )                               AS dept_tenure_rank
    FROM employees
    WHERE hire_date_clean IS NOT NULL
      AND active_status = 1
)
SELECT
    department,
    dept_tenure_rank    AS rank_in_dept,
    full_name,
    jobtitle,
    hire_date_clean,
    tenure_years
FROM tenure_ranked
WHERE dept_tenure_rank <= 5
ORDER BY department, dept_tenure_rank;
GO
 
 
-- 5c. Average Tenure by Gender (pay equity check proxy)
SELECT
    gender,
    COUNT(*)    AS headcount,
    ROUND(
        AVG(DATEDIFF(DAY, hire_date_clean, CAST(GETDATE() AS DATE)) / 365.25), 1
    )           AS avg_tenure_years
FROM employees
WHERE hire_date_clean IS NOT NULL
GROUP BY gender
ORDER BY avg_tenure_years DESC;
GO
 
 

-- SECTION 6: FINAL SUMMARY REPORT
--   Uses: 4 CTEs + JOINs + WINDOW FUNCTION

WITH
 
-- CTE 1: Base metrics per department
dept_metrics AS (
    SELECT
        department,
        COUNT(*)                                               AS total_employees,
        SUM(CASE WHEN active_status = 1 THEN 1 ELSE 0 END)        AS active_count,
        SUM(CASE WHEN active_status = 0 THEN 1 ELSE 0 END)        AS terminated_count,
        ROUND(
            AVG(DATEDIFF(DAY,
                hire_date_clean,
                COALESCE(termdate_clean, CAST(GETDATE() AS DATE))
            ) / 365.25), 1
        )                                                      AS avg_tenure_years
    FROM employees
    WHERE hire_date_clean IS NOT NULL
    GROUP BY department
),
 
-- CTE 2: Most common job title per department  (uses ROW_NUMBER window function)
top_jobtitle AS (
    SELECT department, jobtitle AS most_common_jobtitle
    FROM (
        SELECT
            department,
            jobtitle,
            ROW_NUMBER() OVER (
                PARTITION BY department
                ORDER BY COUNT(*) DESC
            ) AS rn
        FROM employees
        WHERE active_status = 1
        GROUP BY department, jobtitle
    ) ranked
    WHERE rn = 1
),
 
-- CTE 3: Gender diversity score (% non-male active employees)
gender_diversity AS (
    SELECT
        department,
        ROUND(
            100.0 * SUM(CASE WHEN gender <> 'Male' THEN 1 ELSE 0 END) / COUNT(*), 1
        ) AS diversity_pct
    FROM employees
    WHERE active_status = 1
    GROUP BY department
),
 
-- CTE 4: Retention rate + company-wide rank  (uses RANK window function)
ranked_depts AS (
    SELECT
        department,
        ROUND(
            100.0 * SUM(CASE WHEN active_status = 1 THEN 1 ELSE 0 END) / COUNT(*), 1
        ) AS retention_rate_pct,
        RANK() OVER (
            ORDER BY
                1.0 * SUM(CASE WHEN active_status = 1 THEN 1 ELSE 0 END) / COUNT(*) DESC
        ) AS retention_rank
    FROM employees
    GROUP BY department
)
 
-- FINAL JOIN: pull all 4 CTEs together into one summary table
SELECT
    d.department,
    d.total_employees,
    d.active_count,
    d.terminated_count,
    d.avg_tenure_years,
    t.most_common_jobtitle,
    g.diversity_pct                 AS non_male_pct,
    r.retention_rate_pct,
    r.retention_rank                AS retention_rank_company_wide
FROM dept_metrics       d
JOIN top_jobtitle       t ON d.department = t.department
JOIN gender_diversity   g ON d.department = g.department
JOIN ranked_depts       r ON d.department = r.department
ORDER BY r.retention_rank;
GO
 