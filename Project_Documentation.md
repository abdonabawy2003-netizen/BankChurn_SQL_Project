# Bank Customer Churn Analysis Using SQL Server

## 1. Overview

This project analyzes the Churn Bank Customers AK dataset using Microsoft SQL Server. The source CSV contains 10,000 bank customer records and 14 columns covering demographics, financial information, product usage, and whether the customer left the bank.

The data was imported into a staging table, validated, and organized into six relational tables: `Geography`, `Gender`, `Customers`, `CustomerFinancials`, `CustomerProducts`, and `CustomerStatus`. Business-focused SQL analyses were then used to examine who leaves the bank, how much money is involved, and which customers deserve attention.

## 2. Business Problem

A bank loses customers every year (churn), and keeping an existing customer is usually cheaper than winning a new one. The business needs to know which customer groups leave the most, how churn relates to country, gender, age, number of products and activity, and how much balance leaves with churned customers. The analysis is meant to help management decide where to focus retention efforts.

## 3. Dataset

- **Dataset:** [Churn Bank Customers AK on Kaggle](https://www.kaggle.com/datasets/akelsayed/churn-bank-customers-ak)
- **Author:** Akram ELsayed
- **License:** Apache 2.0
- **File:** `Churn_Bank_Customers_AK.csv`
- **Rows:** 10,000
- **Columns:** 14
- **Target column:** `Exited` (1 = customer left, 0 = customer stayed)

## 4. Database Design

The source CSV was first imported into `stg.Churn_Bank_Customers_AK`. The staging table preserves the source values before they are converted and loaded into the final schema (`bank`).

The final schema contains:

- **Geography** — lookup table of countries.
- **Gender** — lookup table of gender values.
- **Customers** — customer ID, surname, age, and foreign keys to geography and gender.
- **CustomerFinancials** — credit score, balance, estimated salary, and tenure.
- **CustomerProducts** — number of products and credit card ownership.
- **CustomerStatus** — active member flag and the churn flag (`Exited`).

`Geography` and `Gender` each have a one-to-many relationship with `Customers`. `Customers` has a one-to-one relationship with each of the three detail tables, enforced by a `UNIQUE` foreign key on `CustomerId`.

Data type decisions: `Balance` and `EstimatedSalary` were converted from `float` to `DECIMAL(18,2)` because money needs fixed precision. Small integers use `TINYINT` and `SMALLINT`, flags use `BIT`, and text columns use `NVARCHAR`.

The ERD is included as `docs/ERD.png` and the source-to-target mapping as `docs/Mapping.png`.

## 5. Data Import and Validation

The CSV was imported into SQL Server using **Import Flat File** in SSMS. The data was first loaded into `stg.Churn_Bank_Customers_AK`, then inserted into the normalized tables with `01_DDL_Insert.sql`.

| Validation check | Rows |
|---|---:|
| Staging table | 10,000 |
| Geography | 3 |
| Gender | 2 |
| Customers | 10,000 |
| CustomerFinancials | 10,000 |
| CustomerProducts | 10,000 |
| CustomerStatus | 10,000 |

The row counts of the final tables match the staging table. The total balance in the staging table (764,858,892.81) and in `CustomerFinancials` (764,858,893.48) differ by 0.67. This is expected: the source stores `Balance` as `float`, and each value was rounded to two decimals when converted to `DECIMAL(18,2)`.

The validation queries are in `sql/02_Validation.sql`.

## 6. SQL Analysis

The analysis is split into three files, with a business question above each query:

- `03_Insights_Churn.sql` — who is leaving the bank.
- `04_Insights_Customer_Value.sql` — money and customer value.
- `05_Insights_Retention_Risk.sql` — which customers and segments need attention.

The queries use:

- `JOIN` (up to four tables) to combine related tables.
- Aggregate functions such as `SUM`, `AVG`, `COUNT`, `MIN`, and `MAX`.
- `GROUP BY` and `HAVING` to summarize and filter grouped results.
- `CASE` expressions to build age and credit score groups.
- `CAST`, `ROUND`, and `NULLIF` for calculations.
- A common table expression (CTE) with the `ROW_NUMBER` window function to rank customers within each country.

The query results are saved in the `docs/screenshots` folder.

## 7. Key Findings

1. **Overall churn:** 2,037 of 10,000 customers left the bank, a churn rate of 20.37%, or about one customer in five.
2. **Country:** Germany had the highest churn rate (32.44%), compared with Spain (16.67%) and France (16.15%). Germany holds about 25% of customers but about 40% of all churned customers (814 of 2,037).
3. **Gender:** Female customers churned at 25.07%, compared with 16.46% for male customers.
4. **Age:** Churn rises sharply with age: under 30 (7.56%), 30–39 (10.88%), 40–49 (30.79%), 50–59 (56.04%), and 60+ (27.95%). The 50–59 group has the highest rate.
5. **Number of products:** Customers with one product churned at 27.71% and make up about 69% of all churned customers. Customers with two products had the lowest rate (7.58%). Customers with three products churned at 82.71%, and all 60 customers with four products churned. The four-product group is small and should be investigated before drawing conclusions.
6. **Activity:** Inactive members (4,849 customers) churned at 26.85%.
7. **High-value customers:** Among the three richest customers in each country (nine customers), three had already left the bank, including the largest balance in the dataset (250,898.09, in Spain). This shows the bank is also losing high-balance customers.
8. **Customer profile:** Germany's average balance is 119,730.12, about twice France (62,092.64) and Spain (61,818.15), while average salary (about 99,000 to 101,000) and credit score (about 650) are similar in all three countries.
9. **Credit score:** Churn varies little across credit bands, from 18.62% (Good) to 22.02% (Poor), so credit score is not a strong churn driver here.
10. **Zero balances:** 48.41% of Spanish customers and 48.22% of French customers hold a zero balance. Germany has none, which helps explain its higher average balance.
11. **Retention targets:** 1,584 customers who are still with the bank, inactive, and hold more than 100,000 have a combined balance of about 210.6 million (France 729, Germany 545, Spain 310).
12. **Risky segments:** Only three country and gender segments churn above the bank average: Germany female (37.55%), Germany male (27.81%), and Spain female (21.21%).
13. **Card and activity:** Active members churn at 13.36% to 16.39% and inactive members at 25.70% to 27.32%, whether or not they own a credit card, so activity matters more than the card.

## 8. Business Recommendations

- Prioritize retention work in Germany, where churn is much higher than in the other two countries.
- Target customers aged 40 to 59 with retention offers, since these groups have the highest churn rates.
- Encourage customers with one product to adopt a second product, because two-product customers showed the lowest churn.
- Investigate why customers with three or four products churn so often before changing any product strategy.
- Run engagement campaigns for inactive members, and review the accounts of high-balance customers who are inactive.
- Assign dedicated relationship management to the highest-balance customers.
- Start a retention campaign with the 1,584 inactive high-balance customers who are still with the bank, beginning with France and Germany.
- Give German female customers a dedicated offer, since they are the riskiest segment (37.55% churn).
- Run activation campaigns for the large share of French and Spanish customers with zero balance.

## 9. Limitations

The dataset has no dates, transaction history, or reason for leaving, so the analysis cannot show when or why customers left. The findings describe associations between customer attributes and churn, not proof of cause. Some groups are small (for example, 60 customers with four products), so their percentages should be read with caution. One surname in the source CSV had a corrupted character (`H?`) and was replaced with a placeholder name in the database; this column is not used in any calculation.

## 10. GitHub Repository

**Public repository:** [BankChurn SQL Project](https://github.com/abdonabawy2003-netizen/BankChurn_SQL_Project)
