/* =====================================================================
   BankChurnDB - Insights 3: Retention Targets & Risk Segments
   Goal: find which customers to act on NOW and which segments are risky.
   Run each query separately (select it, then press F5).
   ===================================================================== */
USE BankChurnDB;
GO

/* ---------------------------------------------------------------------
   Q1. Which valuable customers are still with us but inactive?
   Why: they have not left yet, but inactivity + high balance is the
        classic pre-churn profile. This is the retention call list.
   Uses: JOIN (4 tables), WHERE, GROUP BY, HAVING, Aggregations
   --------------------------------------------------------------------- */
SELECT g.GeographyName                        AS Country,
       COUNT(*)                               AS AtRiskCustomers,
       SUM(f.Balance)                         AS BalanceAtRisk,
       CAST(AVG(f.Balance) AS DECIMAL(18,2))  AS AvgBalance
FROM bank.Customers c
JOIN bank.Geography g          ON g.GeographyId = c.GeographyId
JOIN bank.CustomerFinancials f ON f.CustomerId  = c.CustomerId
JOIN bank.CustomerStatus st    ON st.CustomerId = c.CustomerId
WHERE st.Exited = 0
  AND st.IsActiveMember = 0
  AND f.Balance > 100000
GROUP BY g.GeographyName
HAVING COUNT(*) >= 1
ORDER BY BalanceAtRisk DESC;


/* ---------------------------------------------------------------------
   Q2. Which country + gender segments churn MORE than the bank average?
   Why: pinpoints the riskiest segments instead of looking at one
        dimension at a time.
   Uses: JOIN, GROUP BY (2 columns), HAVING with a subquery
   --------------------------------------------------------------------- */
SELECT g.GeographyName                        AS Country,
       gd.GenderName                          AS Gender,
       COUNT(*)                               AS Customers,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.Customers c
JOIN bank.Geography g       ON g.GeographyId = c.GeographyId
JOIN bank.Gender gd         ON gd.GenderId   = c.GenderId
JOIN bank.CustomerStatus st ON st.CustomerId = c.CustomerId
GROUP BY g.GeographyName, gd.GenderName
HAVING AVG(CAST(st.Exited AS FLOAT)) > (SELECT AVG(CAST(Exited AS FLOAT)) FROM bank.CustomerStatus)
ORDER BY ChurnRate_Pct DESC;


/* ---------------------------------------------------------------------
   Q3. Does owning a credit card, or being active, change churn?
   Why: checks whether the card product actually retains customers, and
        whether activity matters more than the card.
   Uses: JOIN, GROUP BY (2 columns), CASE
   --------------------------------------------------------------------- */
SELECT CASE WHEN p.HasCrCard = 1 THEN 'Has card' ELSE 'No card' END         AS CreditCard,
       CASE WHEN st.IsActiveMember = 1 THEN 'Active' ELSE 'Inactive' END    AS Activity,
       COUNT(*)                                                             AS Customers,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.CustomerProducts p
JOIN bank.CustomerStatus st ON st.CustomerId = p.CustomerId
GROUP BY p.HasCrCard, st.IsActiveMember
ORDER BY p.HasCrCard DESC, st.IsActiveMember DESC;


/* ---------------------------------------------------------------------
   Q4. Who are the 3 richest customers in each country?
   Why: VIP list per market for relationship managers.
   Uses: CTE, window function ROW_NUMBER() with PARTITION BY, JOIN
   --------------------------------------------------------------------- */
WITH Ranked AS (
    SELECT g.GeographyName AS Country,
           c.CustomerId, c.Surname, f.Balance, st.Exited,
           ROW_NUMBER() OVER (PARTITION BY g.GeographyName ORDER BY f.Balance DESC) AS RankInCountry
    FROM bank.Customers c
    JOIN bank.Geography g          ON g.GeographyId = c.GeographyId
    JOIN bank.CustomerFinancials f ON f.CustomerId  = c.CustomerId
    JOIN bank.CustomerStatus st    ON st.CustomerId = c.CustomerId
)
SELECT Country, RankInCountry, CustomerId, Surname, Balance,
       CASE WHEN Exited = 1 THEN 'Churned' ELSE 'Still with us' END AS Status
FROM Ranked
WHERE RankInCountry <= 3
ORDER BY Country, RankInCountry;


/* ---------------------------------------------------------------------
   Q5. Is the balance-to-salary ratio different for churned customers?
   Why: a high ratio means the customer keeps a lot of money with us
        relative to income; losing them is costlier.
   Uses: JOIN, GROUP BY, NULLIF (avoid divide by zero), ROUND, AVG
   --------------------------------------------------------------------- */
SELECT CASE WHEN st.Exited = 1 THEN 'Churned' ELSE 'Retained' END AS CustomerStatus,
       COUNT(*)                                                    AS Customers,
       ROUND(AVG(f.Balance / NULLIF(f.EstimatedSalary, 0)), 3)     AS AvgBalanceToSalary,
       CAST(AVG(f.Balance) AS DECIMAL(18,2))                       AS AvgBalance,
       CAST(AVG(f.EstimatedSalary) AS DECIMAL(18,2))               AS AvgSalary
FROM bank.CustomerFinancials f
JOIN bank.CustomerStatus st ON st.CustomerId = f.CustomerId
GROUP BY st.Exited
ORDER BY st.Exited DESC;
GO