# Banking-Fraud-Analysis-SQL

# Banking Transaction and Fraud Analysis Using MySQL

## 1. Project Overview
This project analyzes financial transaction records using **MySQL 8.0 (MySQL Workbench)** to identify fraudulent behavior, evaluate transaction risk across payment channels, investigate sender and receiver balance anomalies, and test a rule-based fraud detection filter.

The goal of this analysis is to move beyond basic transaction totals and uncover actionable fraud patterns—such as complete account balance draining, zero-balance destination accounts, and paired pass-through laundering transactions—that financial institutions and risk analysts can use to strengthen fraud monitoring.

---

## 2. Dataset & Scope Limitation
* **Dataset Source:** [PaySim Synthetic Financial Datasets for Fraud Detection (Kaggle)](https://www.kaggle.com/datasets/ealaxi/paysim1)
* **Database Name:** `banking_fraud_analysis`
* **Main Table:** `transactions`
* **Sample Size Analyzed:** `100,000` imported rows

> **Important Scope Limitation:** This analysis is performed on a **100,000-row sample** imported into MySQL, not the entire 6.3-million-row PaySim dataset. The sample is not random, so all metrics, fraud rates, and findings documented below describe this 100,000-row sample only.

### Table Schema (`transactions`)
| Column Name | Description |
| :--- | :--- |
| `step` | Unit of time in the simulation (1 step = 1 hour) |
| `type` | Transaction type (`PAYMENT`, `CASH_OUT`, `CASH_IN`, `TRANSFER`, `DEBIT`) |
| `amount` | Transaction amount in local currency |
| `nameOrig` | Customer ID who initiated the transaction (Sender) |
| `oldbalanceOrg` | Sender's initial balance before the transaction |
| `newbalanceOrig` | Sender's new balance after the transaction |
| `nameDest` | Customer/Merchant ID who received the transaction (Receiver) |
| `oldbalanceDest` | Receiver's initial balance before the transaction |
| `newbalanceDest` | Receiver's new balance after the transaction |
| `isFraud` | Actual fraud label (`1` = Fraudulent, `0` = Normal) |
| `isFlaggedFraud` | System-flagged fraud indicator (`1` = Flagged, `0` = Not Flagged) |

---

## 3. SQL Skills Demonstrated
Across **35 structured SQL queries**, this project demonstrates:
* **Data Quality & Validation:** `COUNT()`, `DISTINCT`, `IS NULL` checks with conditional `CASE` sums, and exact duplicate detection using `GROUP BY` and `HAVING`.
* **Aggregations & KPIs:** `SUM()`, `AVG()`, `MIN()`, `MAX()`, and `ROUND()` across transaction types and fraud statuses.
* **Conditional Logic & Risk Segmentation:** Multi-tier transaction amount and account balance bucketing using `CASE WHEN`.
* **Common Table Expressions (CTEs) & Window Functions:** Partitioned rankings using `WITH` clauses, `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`, and `DENSE_RANK()`.
* **Anomaly & Pattern Detection:** Multi-condition filtering for account draining, overdraft checks, shadow/mule receiver accounts, and paired pass-through transactions.
* **Rule Evaluation Metrics:** Calculating True Positives, False Positives, Precision, and Recall directly in SQL.
* **Database Views & Query Optimization:** Creating reusable reporting views (`CREATE OR REPLACE VIEW v_fraud_risk_summary`) and inspecting query execution plans using `EXPLAIN`.

---

## 4. Key Verified Findings (100,000-Row Sample)

### 4.1 Overall Fraud Summary
| Metric | Verified Result |
| :--- | :--- |
| **Total Transactions** | 100,000 |
| **Normal Transactions (`isFraud = 0`)** | 99,884 (99.88%) |
| **Fraudulent Transactions (`isFraud = 1`)** | 116 (0.12%) |
| **Total Fraudulent Amount** | 62,823,097.20 |
| **Average Fraudulent Transaction Amount** | 541,578.42 |
| **Average Normal Transaction Amount** | 173,174.87 |
| **Highest Fraudulent Transaction Amount** | 10,000,000.00 |
| **System-Flagged Transactions (`isFlaggedFraud = 1`)** | 0 (0.00% detection rate) |

### 4.2 Fraud Breakdown by Transaction Type (Query 34 View)
Fraud occurs **exclusively** in `TRANSFER` and `CASH_OUT` transactions. Zero fraud cases occurred in `PAYMENT`, `CASH_IN`, or `DEBIT`.

| Transaction Type | Total Transactions | Total Amount | Avg Amount | Fraud Cases | Total Fraud Amount | Fraud Rate (%) |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| **TRANSFER** | 8,597 | 7,452,556,856.26 | 866,878.78 | 57 | 31,943,510.60 | **0.66%** |
| **CASH_OUT** | 30,718 | 5,960,895,829.92 | 194,052.21 | 59 | 30,879,586.60 | **0.19%** |
| **PAYMENT** | 39,512 | 431,188,999.17 | 10,912.86 | 0 | 0.00 | 0.00% |
| **CASH_IN** | 20,185 | 3,511,533,617.97 | 173,967.48 | 0 | 0.00 | 0.00% |
| **DEBIT** | 988 | 4,046,873.09 | 4,096.03 | 0 | 0.00 | 0.00% |

### 4.3 Critical Fraud Behavioral Patterns
1. **Complete Account Balance Draining (Query 26):**
   * Out of 116 total fraudulent transactions, **110 cases (94.83%)** completely emptied the sender's starting balance (`oldbalanceOrg > 0` and `newbalanceOrig = 0`), comprising 56 `CASH_OUT` and 54 `TRANSFER` frauds.
2. **Fraudsters Target Available Funds Rather Than Overdrawing (Query 27):**
   * Only **5 out of 116** fraudulent transactions (`4 CASH_OUT`, `1 TRANSFER`) exceeded the sender's starting balance (`amount > oldbalanceOrg`), showing that attackers primarily drain existing available funds.
3. **Zero Initial Balance on Destination Accounts (Query 28):**
   * **56 out of 57 fraudulent transfers (98.25%)** and **20 fraudulent cash-outs** were sent to receiver accounts that had an initial balance of `0` (`oldbalanceDest = 0`). The fraud rate for `TRANSFER` to zero-balance accounts jumped to **5.33%** (8x higher than the overall `TRANSFER` fraud rate of 0.66%).
4. **Unreflected Receiver Balances — Major Red Flag (Query 29):**
   * In `TRANSFER` transactions where the receiver started with `0` balance and still showed `0` balance after receiving funds (`oldbalanceDest = 0 AND newbalanceDest = 0 AND amount > 0`), **48 out of 72 transactions were fraudulent—a 66.67% fraud rate** totaling `35,059,151.38`.
5. **1-to-1 Paired Pass-Through Laundering (Query 32):**
   * High-value fraud frequently occurs in exact pairs within the same simulated hour (`step`): one `TRANSFER` immediately followed by one `CASH_OUT` for the exact same amount (e.g., `10,000,000.00` in step 4; `5,460,002.91` in step 7; `2,930,418.44` in step 4).
6. **Rule-Based Filter Evaluation (Query 31):**
   * A simple 4-condition rule (`type IN ('TRANSFER', 'CASH_OUT') AND oldbalanceOrg > 0 AND newbalanceOrig = 0 AND oldbalanceDest = 0`) flagged 3,561 transactions and successfully captured **73 of the 116 fraud cases (62.93% Recall)** with a **2.05% Precision**, far outperforming the dataset's built-in `isFlaggedFraud` column (which caught 0 cases).
7. **Query Performance Optimization (Query 35):**
   * Running `EXPLAIN` on fraud filtering revealed a full table scan (`type = ALL`, `rows = 99,401`, `filtered = 2.00%`). Creating a composite index on `(type, isFraud)` is recommended for production deployment.

---

## 5. Selected Result Screenshots

* **Query 26 — Account Balance Draining:**
  ![Query 26 Balance Draining](Account%20balance%20drained%20to%20zero.png)
* **Query 28 — Zero Initial Destination Balance:**
  ![Query 28 Zero Initial Balance](Zero%20starting%20receiver%20balance.png)
* **Query 29 — Unreflected Destination Balance (66.67% Fraud Rate):**
  ![Query 29 Unreflected Balance](66.67%25%20fraud%20rate%20on%20unreflected%20receiver%20balances.png)
* **Query 31 — Rule-Based Filter Precision & Recall:**
  ![Query 31 Precision Recall](Rule-based%20filter%20catching%2062.93%25%20of%20all%20fraud.png)
* **Query 32 — Paired Pass-Through Transactions:**
  ![Query 32 Paired Pass-Through](1-to-1%20paired%20TRANSFER%20and%20CASH_OUT%20transactions.png)
* **Query 34 — Executive Fraud Risk Summary View:**
  ![Query 34 Summary View](Executive%20summary%20view%20output.png)

---

## 6. Business Recommendations
1. **Replace Static Threshold Flags with Behavioral Rules:** The legacy `isFlaggedFraud` rule detected `0%` of frauds in this sample. Risk systems should trigger real-time verification whenever a `TRANSFER` or `CASH_OUT` drains 100% of an account's balance (`newbalanceOrig = 0`).
2. **Hold or Step-Up Authenticate Zero-Balance Destination Transfers:** Since `66.67%` of transfers where `oldbalanceDest = 0` and `newbalanceDest = 0` are fraudulent, transactions matching this pattern should require multi-factor authentication or a temporary cooling hold before settlement.
3. **Block Rapid Same-Amount `TRANSFER` -> `CASH_OUT` Chains:** Implement velocity checks within the same hour (`step`) that flag or freeze `CASH_OUT` requests matching the exact amount of a recent incoming `TRANSFER`.
4. **Database Indexing for Real-Time Monitoring:** Add a composite index `CREATE INDEX idx_type_isfraud ON transactions(type, isFraud);` to eliminate full-table scans (`99,401` rows) on analytical and monitoring queries.

---

## 7. Repository Files
* `banking_fraud_analysis.sql` — Complete, sectioned SQL script containing all 35 queries.
* `README.md` — Project documentation, verified results, and business insights.

---

## 8. Author
**Chandan Prasad**  
*Data Analytics & MIS Reporting Portfolio*  
* **GitHub:** [Chandanprasad7](https://github.com/Chandanprasad7)
