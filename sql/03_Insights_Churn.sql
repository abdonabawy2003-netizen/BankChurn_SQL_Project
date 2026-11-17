/* =====================================================================
   BankChurnDB - Insights 1: Churn Analysis
   Goal: understand WHO is leaving the bank and WHERE.
   Run each query separately (select it, then press F5).
   ===================================================================== */
USE BankChurnDB;
GO

/* ---------------------------------------------------------------------
   Q1. What is the overall churn rate?
   Why: the headline KPI. Every other number is compared against it.
   Uses: Aggregations (COUNT, SUM), CAST, Functions
   --------------------------------------------------------------------- */
SELECT COUNT(*)                               AS TotalCustomers,
       SUM(CAST(Exited AS INT))               AS ChurnedCustomers,
       CAST(100.0 * SUM(CAST(Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.CustomerStatus;


/* ---------------------------------------------------------------------
   Q2. Which country loses the most customers?
   Why: tells management where to focus retention budget / local teams.
   Uses: JOIN (3 tables), GROUP BY, Aggregations
   --------------------------------------------------------------------- */
SELECT g.GeographyName                        AS Country,
       COUNT(*)                               AS Customers,
       SUM(CAST(st.Exited AS INT))            AS Churned,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.Customers c
JOIN bank.Geography g       ON g.GeographyId = c.GeographyId
JOIN bank.CustomerStatus st ON st.CustomerId = c.CustomerId
GROUP BY g.GeographyName
ORDER BY ChurnRate_Pct DESC;


/* ---------------------------------------------------------------------
   Q3. Do men or women churn more?
   Why: helps design targeted offers / communication per segment.
   Uses: JOIN, GROUP BY, Aggregations
   --------------------------------------------------------------------- */
SELECT gd.GenderName                          AS Gender,
       COUNT(*)                               AS Customers,
       SUM(CAST(st.Exited AS INT))            AS Churned,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.Customers c
JOIN bank.Gender gd         ON gd.GenderId   = c.GenderId
JOIN bank.CustomerStatus st ON st.CustomerId = c.CustomerId
GROUP BY gd.GenderName
ORDER BY ChurnRate_Pct DESC;


/* ---------------------------------------------------------------------
   Q4. Which age group is leaving the most?
   Why: shows the life stage where the bank loses customers, so products
        and campaigns can target that group.
   Uses: CASE (function), CROSS APPLY, JOIN, GROUP BY
   --------------------------------------------------------------------- */
SELECT x.AgeGroup,
       COUNT(*)                               AS Customers,
       SUM(CAST(st.Exited AS INT))            AS Churned,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.Customers c
JOIN bank.CustomerStatus st ON st.CustomerId = c.CustomerId
CROSS APPLY (SELECT CASE WHEN c.Age < 30 THEN '1) Under 30'
                         WHEN c.Age < 40 THEN '2) 30-39'
                         WHEN c.Age < 50 THEN '3) 40-49'
                         WHEN c.Age < 60 THEN '4) 50-59'
                         ELSE                 '5) 60+' END AS AgeGroup) x
GROUP BY x.AgeGroup
ORDER BY x.AgeGroup;


/* ---------------------------------------------------------------------
   Q5. How does the number of products affect churn?
   Why: reveals if cross-selling keeps customers (or if too many products
        is a warning sign).
   Uses: JOIN, GROUP BY, HAVING (ignore tiny groups), Aggregations
   --------------------------------------------------------------------- */
SELECT p.NumOfProducts,
       COUNT(*)                               AS Customers,
       SUM(CAST(st.Exited AS INT))            AS Churned,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.CustomerProducts p
JOIN bank.CustomerStatus st ON st.CustomerId = p.CustomerId
GROUP BY p.NumOfProducts
HAVING COUNT(*) >= 50
ORDER BY p.NumOfProducts;


/* ---------------------------------------------------------------------
   Q6. Are inactive members really more likely to leave?
   Why: decides whether "engagement" campaigns for inactive customers
        are worth the cost.
   Uses: JOIN, GROUP BY, CASE
   --------------------------------------------------------------------- */
SELECT CASE WHEN st.IsActiveMember = 1 THEN 'Active' ELSE 'Inactive' END AS MemberType,
       COUNT(*)                               AS Customers,
       SUM(CAST(st.Exited AS INT))            AS Churned,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.CustomerStatus st
GROUP BY st.IsActiveMember
ORDER BY ChurnRate_Pct DESC;
GO