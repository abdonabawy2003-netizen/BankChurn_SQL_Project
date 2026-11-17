/* =====================================================================
   BankChurnDB - Insights 2: Customer Value & Financials
   Goal: understand how much money is at stake and who the valuable
         customers are.
   Run each query separately (select it, then press F5).
   ===================================================================== */
USE BankChurnDB;
GO

/* ---------------------------------------------------------------------
   Q1. What does the average customer look like in each country?
   Why: a financial profile per market (deposits, income, credit quality).
   Uses: JOIN, GROUP BY, AVG / MIN / MAX, ROUND, CAST
   --------------------------------------------------------------------- */
SELECT g.GeographyName                              AS Country,
       COUNT(*)                                     AS Customers,
       CAST(AVG(f.Balance) AS DECIMAL(18,2))        AS AvgBalance,
       CAST(AVG(f.EstimatedSalary) AS DECIMAL(18,2)) AS AvgSalary,
       ROUND(AVG(CAST(f.CreditScore AS FLOAT)), 1)  AS AvgCreditScore,
       MAX(f.Balance)                               AS MaxBalance
FROM bank.Customers c
JOIN bank.Geography g          ON g.GeographyId = c.GeographyId
JOIN bank.CustomerFinancials f ON f.CustomerId  = c.CustomerId
GROUP BY g.GeographyName
ORDER BY AvgBalance DESC;


/* ---------------------------------------------------------------------
   Q2. How much money did the bank lose to churn, per country?
   Why: turns churn from "number of customers" into "money", which is what
        management cares about.
   Uses: JOIN (4 tables), conditional aggregation (SUM + CASE), GROUP BY
   --------------------------------------------------------------------- */
SELECT g.GeographyName                                         AS Country,
       SUM(f.Balance)                                          AS TotalBalance,
       SUM(CASE WHEN st.Exited = 1 THEN f.Balance ELSE 0 END)  AS BalanceLostToChurn,
       CAST(100.0 * SUM(CASE WHEN st.Exited = 1 THEN f.Balance ELSE 0 END)
            / SUM(f.Balance) AS DECIMAL(5,2))                  AS PctOfBalanceLost
FROM bank.Customers c
JOIN bank.Geography g          ON g.GeographyId = c.GeographyId
JOIN bank.CustomerFinancials f ON f.CustomerId  = c.CustomerId
JOIN bank.CustomerStatus st    ON st.CustomerId = c.CustomerId
GROUP BY g.GeographyName
ORDER BY BalanceLostToChurn DESC;


/* ---------------------------------------------------------------------
   Q3. Does credit quality relate to churn?
   Why: shows whether the bank is losing its best (or worst) credit
        customers, which changes the risk picture.
   Uses: CASE bands, CROSS APPLY, JOIN, GROUP BY
   --------------------------------------------------------------------- */
SELECT x.CreditBand,
       COUNT(*)                               AS Customers,
       CAST(AVG(f.Balance) AS DECIMAL(18,2))  AS AvgBalance,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.CustomerFinancials f
JOIN bank.CustomerStatus st ON st.CustomerId = f.CustomerId
CROSS APPLY (SELECT CASE WHEN f.CreditScore < 580 THEN '1) Poor (<580)'
                         WHEN f.CreditScore < 670 THEN '2) Fair (580-669)'
                         WHEN f.CreditScore < 740 THEN '3) Good (670-739)'
                         WHEN f.CreditScore < 800 THEN '4) Very Good (740-799)'
                         ELSE                          '5) Excellent (800+)' END AS CreditBand) x
GROUP BY x.CreditBand
ORDER BY x.CreditBand;


/* ---------------------------------------------------------------------
   Q4. How many customers keep a zero balance, per country?
   Why: zero-balance customers bring no deposits; they are candidates for
        activation campaigns.
   Uses: JOIN, conditional aggregation, GROUP BY, HAVING
   --------------------------------------------------------------------- */
SELECT g.GeographyName                                        AS Country,
       COUNT(*)                                               AS Customers,
       SUM(CASE WHEN f.Balance = 0 THEN 1 ELSE 0 END)         AS ZeroBalanceCustomers,
       CAST(100.0 * SUM(CASE WHEN f.Balance = 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS ZeroBalance_Pct
FROM bank.Customers c
JOIN bank.Geography g          ON g.GeographyId = c.GeographyId
JOIN bank.CustomerFinancials f ON f.CustomerId  = c.CustomerId
GROUP BY g.GeographyName
HAVING SUM(CASE WHEN f.Balance = 0 THEN 1 ELSE 0 END) > 0
ORDER BY ZeroBalance_Pct DESC;


/* ---------------------------------------------------------------------
   Q5. Are long-time customers more loyal?
   Why: shows whether churn is mainly a "new customer" problem (onboarding)
        or a "long-term customer" problem (loyalty).
   Uses: JOIN, GROUP BY, HAVING, Aggregations
   --------------------------------------------------------------------- */
SELECT f.Tenure                                AS YearsWithBank,
       COUNT(*)                                AS Customers,
       SUM(CAST(st.Exited AS INT))             AS Churned,
       CAST(100.0 * SUM(CAST(st.Exited AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS ChurnRate_Pct
FROM bank.CustomerFinancials f
JOIN bank.CustomerStatus st ON st.CustomerId = f.CustomerId
GROUP BY f.Tenure
HAVING COUNT(*) >= 100
ORDER BY f.Tenure;


/* ---------------------------------------------------------------------
   Q6. Which 10 churned customers took the most money with them?
   Why: high-value losses deserve a personal win-back call.
   Uses: JOIN (4 tables), WHERE, TOP, ORDER BY
   --------------------------------------------------------------------- */
SELECT TOP 10
       c.CustomerId, c.Surname, c.Age,
       g.GeographyName AS Country,
       f.Balance, f.EstimatedSalary, f.Tenure
FROM bank.Customers c
JOIN bank.Geography g          ON g.GeographyId = c.GeographyId
JOIN bank.CustomerFinancials f ON f.CustomerId  = c.CustomerId
JOIN bank.CustomerStatus st    ON st.CustomerId = c.CustomerId
WHERE st.Exited = 1
ORDER BY f.Balance DESC;
GO