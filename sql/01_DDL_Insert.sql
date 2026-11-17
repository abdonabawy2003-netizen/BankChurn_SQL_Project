/* =====================================================================
   BankChurnDB - Full Script
   Prerequisite: staging table stg.Churn_Bank_Customers_AK already
   imported (10000 rows) via Import Flat File.
   Safe to re-run: drops and recreates the bank.* tables each time.
   ===================================================================== */

USE BankChurnDB;
GO

/* ===== 1) Schemas ===== */
IF SCHEMA_ID('bank') IS NULL EXEC('CREATE SCHEMA bank');
IF SCHEMA_ID('stg')  IS NULL EXEC('CREATE SCHEMA stg');
GO

/* Move staging table to stg if it is still in dbo */
IF OBJECT_ID('dbo.Churn_Bank_Customers_AK') IS NOT NULL
   AND OBJECT_ID('stg.Churn_Bank_Customers_AK') IS NULL
    ALTER SCHEMA stg TRANSFER dbo.Churn_Bank_Customers_AK;
GO

/* ===== 2) Drop (FK order) ===== */
DROP TABLE IF EXISTS bank.CustomerStatus;
DROP TABLE IF EXISTS bank.CustomerProducts;
DROP TABLE IF EXISTS bank.CustomerFinancials;
DROP TABLE IF EXISTS bank.Customers;
DROP TABLE IF EXISTS bank.Gender;
DROP TABLE IF EXISTS bank.Geography;
GO

/* ===== 3) DDL ===== */
CREATE TABLE bank.Geography (
    GeographyId   INT IDENTITY(1,1) CONSTRAINT PK_Geography PRIMARY KEY,
    GeographyName NVARCHAR(50) NOT NULL CONSTRAINT UQ_Geography_Name UNIQUE
);

CREATE TABLE bank.Gender (
    GenderId   INT IDENTITY(1,1) CONSTRAINT PK_Gender PRIMARY KEY,
    GenderName NVARCHAR(10) NOT NULL CONSTRAINT UQ_Gender_Name UNIQUE
);

CREATE TABLE bank.Customers (
    CustomerId  INT NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    Surname     NVARCHAR(50) NOT NULL,
    Age         TINYINT NOT NULL,
    GeographyId INT NOT NULL
        CONSTRAINT FK_Customers_Geography REFERENCES bank.Geography(GeographyId),
    GenderId    INT NOT NULL
        CONSTRAINT FK_Customers_Gender REFERENCES bank.Gender(GenderId)
);

CREATE TABLE bank.CustomerFinancials (
    FinancialId     INT IDENTITY(1,1) CONSTRAINT PK_CustomerFinancials PRIMARY KEY,
    CustomerId      INT NOT NULL CONSTRAINT UQ_Financials_Customer UNIQUE
        CONSTRAINT FK_Financials_Customers REFERENCES bank.Customers(CustomerId),
    CreditScore     SMALLINT NOT NULL,
    Balance         DECIMAL(18,2) NOT NULL,
    EstimatedSalary DECIMAL(18,2) NOT NULL,
    Tenure          TINYINT NOT NULL
);

CREATE TABLE bank.CustomerProducts (
    ProductRecordId INT IDENTITY(1,1) CONSTRAINT PK_CustomerProducts PRIMARY KEY,
    CustomerId      INT NOT NULL CONSTRAINT UQ_Products_Customer UNIQUE
        CONSTRAINT FK_Products_Customers REFERENCES bank.Customers(CustomerId),
    NumOfProducts   TINYINT NOT NULL,
    HasCrCard       BIT NOT NULL
);

CREATE TABLE bank.CustomerStatus (
    StatusId       INT IDENTITY(1,1) CONSTRAINT PK_CustomerStatus PRIMARY KEY,
    CustomerId     INT NOT NULL CONSTRAINT UQ_Status_Customer UNIQUE
        CONSTRAINT FK_Status_Customers REFERENCES bank.Customers(CustomerId),
    IsActiveMember BIT NOT NULL,
    Exited         BIT NOT NULL
);
GO

/* ===== 4) Insert data (lookups first, then Customers, then the rest) ===== */
INSERT INTO bank.Geography (GeographyName)
SELECT DISTINCT Geography FROM stg.Churn_Bank_Customers_AK;

INSERT INTO bank.Gender (GenderName)
SELECT DISTINCT Gender FROM stg.Churn_Bank_Customers_AK;

INSERT INTO bank.Customers (CustomerId, Surname, Age, GeographyId, GenderId)
SELECT s.CustomerId, s.Surname, s.Age, g.GeographyId, gd.GenderId
FROM stg.Churn_Bank_Customers_AK s
JOIN bank.Geography g ON g.GeographyName = s.Geography
JOIN bank.Gender gd   ON gd.GenderName   = s.Gender;

INSERT INTO bank.CustomerFinancials (CustomerId, CreditScore, Balance, EstimatedSalary, Tenure)
SELECT CustomerId, CreditScore,
       CAST(Balance AS DECIMAL(18,2)),
       CAST(EstimatedSalary AS DECIMAL(18,2)),
       Tenure
FROM stg.Churn_Bank_Customers_AK;

INSERT INTO bank.CustomerProducts (CustomerId, NumOfProducts, HasCrCard)
SELECT CustomerId, NumOfProducts, HasCrCard
FROM stg.Churn_Bank_Customers_AK;

INSERT INTO bank.CustomerStatus (CustomerId, IsActiveMember, Exited)
SELECT CustomerId, IsActiveMember, Exited
FROM stg.Churn_Bank_Customers_AK;
GO

/* ===== 5) Verification ===== */

-- 5.1 Row counts (expected: 3, 2, 10000, 10000, 10000, 10000)
SELECT 'Geography' AS TableName, COUNT(*) AS Rows FROM bank.Geography
UNION ALL SELECT 'Gender',             COUNT(*) FROM bank.Gender
UNION ALL SELECT 'Customers',          COUNT(*) FROM bank.Customers
UNION ALL SELECT 'CustomerFinancials', COUNT(*) FROM bank.CustomerFinancials
UNION ALL SELECT 'CustomerProducts',   COUNT(*) FROM bank.CustomerProducts
UNION ALL SELECT 'CustomerStatus',     COUNT(*) FROM bank.CustomerStatus;

-- 5.2 Customers missing from target (expected: 0)
SELECT COUNT(*) AS MissingCustomers
FROM stg.Churn_Bank_Customers_AK s
LEFT JOIN bank.Customers c ON c.CustomerId = s.CustomerId
WHERE c.CustomerId IS NULL;

-- 5.3 Balance totals should be (almost) identical
SELECT
  (SELECT ROUND(SUM(Balance),2) FROM stg.Churn_Bank_Customers_AK) AS StagingBalance,
  (SELECT SUM(Balance) FROM bank.CustomerFinancials)              AS NewBalance;

-- 5.4 Sample joined across all tables
SELECT TOP 10 c.CustomerId, c.Surname, c.Age, g.GeographyName, gd.GenderName,
       f.CreditScore, f.Balance, p.NumOfProducts, st.Exited
FROM bank.Customers c
JOIN bank.Geography g          ON g.GeographyId = c.GeographyId
JOIN bank.Gender gd            ON gd.GenderId   = c.GenderId
JOIN bank.CustomerFinancials f ON f.CustomerId  = c.CustomerId
JOIN bank.CustomerProducts p   ON p.CustomerId  = c.CustomerId
JOIN bank.CustomerStatus st    ON st.CustomerId = c.CustomerId
ORDER BY c.CustomerId;
GO