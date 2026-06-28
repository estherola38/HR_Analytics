Drop Table IF Exists Employees;
CREATE TABLE Employees (
id VARCHAR(20),
first_name VARCHAR(50),
last_name VARCHAR(50),
birthdate VARCHAR(20),
gender VARCHAR(20),
race VARCHAR(60),
department VARCHAR(60),
jobtitle VARCHAR(100),
location VARCHAR(30),
hire_date VARCHAR(20),
termdate VARCHAR(40),
location_city VARCHAR(60),
location_state VARCHAR(60)
);


--Drop table if it already exists
IF OBJECT_ID('dbo.employees', 'U') IS NOT NULL
	DROP TABLE dbo.Employees;
GO
CREATE TABLE Employees (
id VARCHAR(20),
first_name VARCHAR(50),
last_name VARCHAR(50),
birthdate VARCHAR(20),
gender VARCHAR(20),
race VARCHAR(60),
department VARCHAR(60),
jobtitle VARCHAR(100),
location VARCHAR(30),
hire_date VARCHAR(20),
termdate VARCHAR(40),
location_city VARCHAR(60),
location_state VARCHAR(60)
);


--Add Cleaned date columns
ALTER TABLE employees ADD birthdate_clean DATE;
ALTER TABLE employees ADD hire_date_clean DATE;
ALTER TABLE employees ADD termdate_clean DATE;
ALTER TABLE employees ADD is_active		BIT;


--Parse birthdate
--Raw formats: 'MM-DD-YY' (e.g. 06-09-91) and 'M/D/YYYY' (e.g. 6/28/1999)
UPDATE Employees
SET birthdate = CASE
	--Format: MM-DD-YY  Convert dashes to slashes then parse
	WHEN birthdate LIKE '_-_-_'
		THEN TRY_CONVERT(DATE,
			SUBSTRING(birthdate,7,2) + '/' +
			SUBSTRING(birthdate,1,2) + '/' +
			SUBSTRING(birthdate,4,2),
			1)
--Format: M/D/YYYY or MM/DD/YYYY
WHEN birthdate LIKE '%/%/%'
	THEN TRY_CONVERT(DATE, birthdate, 1)
ELSE NULL
END;

--Parse termdate
--Raw format: 'YYYY-MM-DD HH:MM:SS UTC'   grap only the part before the first space
UPDATE Employees
SET termdate = CASE
	WHEN termdate IS NOT NULL AND termdate <> ''
		THEN TRY_CONVERT(DATE, LEFT(termdate, 10), 23) -- style 23 = YYYY-MM-DD
	ELSE NULL
	END;


--Set active status
-- is_active = 1  still employed
-- is_active = 0  terminated
UPDATE Employees