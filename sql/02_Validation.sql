USE BankChurnDB;
GO

-- 1.1 Row count per table
SELECT 'stg.Churn_Bank_Customers_AK' AS TableName, COUNT(*) AS Rows FROM stg.Churn_Bank_Customers_AK
UNION ALL SELECT 'bank.Geography',          COUNT(*) FROM bank.Geography
UNION ALL SELECT 'bank.Gender',             COUNT(*) FROM bank.Gender
UNION ALL SELECT 'bank.Customers',          COUNT(*) FROM bank.Customers
UNION ALL SELECT 'bank.CustomerFinancials', COUNT(*) FROM bank.CustomerFinancials
UNION ALL SELECT 'bank.CustomerProducts',   COUNT(*) FROM bank.CustomerProducts
UNION ALL SELECT 'bank.CustomerStatus',     COUNT(*) FROM bank.CustomerStatus;

-- 2.1 Top 100
SELECT TOP 100 * FROM stg.Churn_Bank_Customers_AK;
SELECT TOP 100 * FROM bank.Geography;
SELECT TOP 100 * FROM bank.Gender;
SELECT TOP 100 * FROM bank.Customers;
SELECT TOP 100 * FROM bank.CustomerFinancials;
SELECT TOP 100 * FROM bank.CustomerProducts;
SELECT TOP 100 * FROM bank.CustomerStatus;


-- 2.2 Top 1000 (joined across all tables)
SELECT TOP 1000
       c.CustomerId, c.Surname, c.Age,
       g.GeographyName, gd.GenderName,
       f.CreditScore, f.Balance, f.EstimatedSalary, f.Tenure,
       p.NumOfProducts, p.HasCrCard,
       st.IsActiveMember, st.Exited
FROM bank.Customers c
JOIN bank.Geography g          ON g.GeographyId = c.GeographyId
JOIN bank.Gender gd            ON gd.GenderId   = c.GenderId
JOIN bank.CustomerFinancials f ON f.CustomerId  = c.CustomerId
JOIN bank.CustomerProducts p   ON p.CustomerId  = c.CustomerId
JOIN bank.CustomerStatus st    ON st.CustomerId = c.CustomerId
ORDER BY c.CustomerId;