-- Project: IBM HR Employee Attrition Analysis
-- Tools Used: MySQL
-- Concepts Covered: Data Cleaning, Aggregations, CASE, Window Functions (RANK, NTILE)
-- Author: Ashay Pallav
-- Date: 2nd March 2026


-- Create and use database
create database IBM_HR_Database;
use IBM_HR_Database;

-- Preview data
select * from hr_employee_attrition;

-- Created a Staging table to avoid modifying original data
create table staging_1 like hr_employee_attrition;
insert into staging_1 select * from hr_employee_attrition;
select * from staging_1;

-- CHECKING FOR DUPLICATES
select count(*) as total_rows from staging_1;
select count(distinct EmployeeNumber) as unique_employees from staging_1;
-- since both returned 1470, there are no duplicate records

-- CHECKING FOR NULL VALUES
select * from staging_1 where EmployeeNumber is null;
select * from staging_1 where Attrition is null;
select * from staging_1 where MonthlyIncome is null;
select * from staging_1 where PerformanceRating is null;
select * from staging_1 where Department is null;
select * from staging_1 where JobRole is null;
select * from staging_1 where OverTime is null;
select * from staging_1 where Gender is null;
select * from staging_1 where MaritalStatus is null;

-- NOW CHECK FOR BLANK VALUES
select * from staging_1 where Attrition = ' ';
SELECT 
    *
FROM
    staging_1
WHERE
    TRIM(JobRole) = ' '
        OR TRIM(Department) = ' '
        OR TRIM(OverTime) = ' '
        OR TRIM(Gender) = ' '
        OR TRIM(MaritalStatus) = ' ';

-- DATA CLEANING & VALIDATION COMPLETE
-- No duplicate records found
-- No Null values found
-- No blank values found
-- ========================================

-- CHECKING FOR DATA CONSISTENCY IN CATEGORIAL COLUMNS

select distinct Department from staging_1;
select distinct JobRole from staging_1;
select distinct OverTime from staging_1;
select distinct Gender from staging_1;
select distinct MaritalStatus from staging_1;

-- All categorical columns contain consistent and valid values
-- No spelling inconsistencies found

-- =================================================================================

-- Exploratory Data Analysis (EDA)

-- KPIs
select avg(ï»¿Age) as Average_Employee_Age, count(*) as total_employees from staging_1;

select avg(MonthlyIncome) as Average_Salary, count(*) as total_employees from staging_1;

select avg(TotalWorkingYears) as Average_Experience, count(*) as total_employees from staging_1;

-- Attrition Rate
select count(case when Attrition = 'Yes' then 1 end) as employees_left,
count(*) as total_employees, round(count(case when Attrition = 'Yes' then 1 end) * 100.0/count(*), 2) as attrition_rate from staging_1;


-- BUSINESS ANALYSIS

-- Attrititon rate by JobRole
select JobRole, round(count(case when Attrition = 'Yes' then 1 end) * 100.0/count(*), 2) as attrition_rate, count(*) as total_employees,
count(case when Attrition='Yes' then 1 end) as attrition_count
from staging_1
group by JobRole
order by attrition_rate desc;
-- Insight:
-- Sales Representatives are leaving the most
-- Senior roles like Research Director are the most stable
-- Entry and sales type of roles seem more unstable overall

-- Attrititon rate by JobLevel
select JobLevel, JobRole, round(count(case when Attrition = 'Yes' then 1 end) * 100.0/count(*), 2) as attrition_rate, count(*) as total_employees,
count(case when Attrition='Yes' then 1 end) as attrition_count
from staging_1
group by JobLevel, JobRole
order by 1 asc;
-- Insight:
-- Attrition is clearly higher at JobLevel 1, especially for Sales Representatives (42.11%)
-- As job level increases, attrition generally drops, and senior roles show much more stability

-- Attrititon rate by OverTime
select OverTime, round(count(case when Attrition = 'Yes' then 1 end) * 100.0/count(*), 2) as attrition_rate,
count(case when Attrition='Yes' then 1 end) as attrition_count
from staging_1
group by OverTime;
-- Insight:
-- Employees working overtime have a much higher attrition rate (30.53%) compared to those who do not (10.44%)
-- Overtime appears to be strongly liked with employee exits


-- ADVANCED ANALYSIS

-- Attrititon rate by department
with dept_attrition as (
select Department, round(count(case when Attrition = 'Yes' then 1 end) * 100.0/count(*), 2) as attrition_rate, count(*) as total_employees,
count(case when Attrition='Yes' then 1 end) as attrition_count
from staging_1
group by Department
)
select *,
	rank() over (order by attrition_rate desc) as risk_rank from dept_attrition;
-- Insight:
-- Sales shows the highest turnover among departments
-- R&D appears more stable even though it has the most employees
-- Attrition risk is clearly higher in Sales compared to other departments
    
-- Attrititon rate by MonthlyIncome group
with categorised_income as(
select max(MonthlyIncome) as highest, 
min(MonthlyIncome) as least, 
avg(MonthlyIncome) as average, 
(max(MonthlyIncome)+avg(MonthlyIncome))/2 as high, 
(min(MonthlyIncome)+avg(MonthlyIncome))/2 as low from staging_1
)
select round(count(case when Attrition = 'Yes' then 1 end) * 100.0/count(*), 2) as attrition_rate, count(*) as total_employees,
count(case when Attrition='Yes' then 1 end) as attrition_count,
case 
	when MonthlyIncome between least and low then 'Low Income'
    when MonthlyIncome between low and average then 'Medium Income'
    when MonthlyIncome between average and high  then 'High Income'
    when MonthlyIncome between high and highest then 'Very High Income'
end as SalaryGroup
from staging_1, categorised_income
group by SalaryGroup
order by attrition_rate desc;
-- Insight:
-- Lower income employees are leaving more frequently
-- Attrition drops significantly in higher salary groups
-- suggesting compensation may influence retention

-- ================================================================================================================
-- Attempted segmentation using standard deviation
-- This approach was explored to understand distribution-based grouping
-- However, standard deviation is more suitable for outlier detection
-- than equal employee segmentation, so NTILE method was used instead
with categorised_years as ( 
 select min(YearsAtCompany) as zeroth_point,
  stddev(YearsAtCompany)+stddev(YearsAtCompany) as first_point,
 (stddev(YearsAtCompany)+stddev(YearsAtCompany)) * 2 as second_point,
 (stddev(YearsAtCompany)+stddev(YearsAtCompany)) * 3 as third_point,
 (stddev(YearsAtCompany)+stddev(YearsAtCompany)) * 4 as fourth_point,
 max(YearsAtCompany) as fifth_point
 from staging_1)
 -- Attrititon rate by YearsAtCompany
select round(count(case when Attrition = 'Yes' then 1 end) * 100.0/count(*), 2) as attrition_rate,
case 
	when YearsAtCompany <= first_point then 'New Employees'
    when YearsAtCompany <= second_point then 'Junior Employees'
    when YearsAtCompany <= third_point then 'Mid-level Employees'
    when YearsAtCompany <= fourth_point then 'Senior Employees'
    else 'Vereran Employees'
end as ExperienceLevel
from staging_1, categorised_years
group by ExperienceLevel;
-- ============================================================================================================================

-- NTILE SEGMENTATION
with experience_groups as (
select YearsAtCompany, Attrition, ntile(5) over (order by YearsAtCompany) as experience_group_number
	from staging_1
)
select
	case
		when experience_group_number = 1 then 'New Employees'
        when experience_group_number = 2 then 'Junior Employees'
        when experience_group_number = 3 then 'Mid-level Employees'
        when experience_group_number = 4 then 'Senior Employees'
        when experience_group_number = 5 then 'Vereran Employees'
	end as ExperienceLevel, 
    count(*) as total_employees,
    round(count(case when Attrition = 'Yes' then 1 end) * 100.0/ count(*), 2) as attrition_rate, 
    count(case when Attrition='Yes' then 1 end) as attrition_count
from experience_groups
group by experience_group_number
order by experience_group_number;
-- Insight: Attrition is highest among new employees,
-- suggesting onboarding or early retention issues

-- HARDCODED 3-GROUP SEGMENTATION
select
	case
		when YearsAtCompany <=2 then 'Freshers'
        when YearsAtCompany <=7 then 'Experienced'
        else 'Veterans'
	end as ExperienceLevel, count(*) as total_employees, round(count(case when Attrition = 'Yes' then 1 end) * 100.0/ count(*), 2) as attrition_rate,
    count(case when Attrition='Yes' then 1 end) as attrition_count
from staging_1
group by ExperienceLevel
order by attrition_rate desc;
-- Insight:
-- Attrition rate is higher among the Freshers and it gradually decreases with experience
-- This suggests newer employees are more likely to leave compared to long-tenured staff

-- Final step: Renaming cleaned staging table for reporting/export
rename table staging_1 to
hr_employee_cleaned;

-- ================================================ FINAL INSIGHTS ======================================================================================
-- Overall attrition appears higher among:
-- 1) Employees working overtime
-- 2) Lower income groups
-- 3) Lower job levels
-- 4) Sales department
-- 5) Freshers / early-tenure employees
--
-- Senior roles, higher salary groups, and experienced employees 
-- show significantly lower attrition rates, department type
-- appear to be major factors influencing employee turnover
-- ======================================================================================================================================================
