# Banking Transaction and Fraud Analysis Using MySQL

**Author:** Chandan Prasad  
**Tools Used:** MySQL, MySQL Workbench  
**Database & Table:** `banking_fraud_analysis.transactions`  
**Dataset:** PaySim Synthetic Financial Dataset ($100,000$-row sample)

---

## 1. Executive Summary & Business Problem

Financial institutions process thousands of digital transactions every hour, making it difficult for legacy threshold rules to detect sophisticated account takeovers and money laundering in real time. 

In this project, **$100,000$ banking transactions** were analyzed using **35 structured MySQL queries** to:
1. Identify high-risk transaction channels where fraudulent activity concentrates.
2. Evaluate the effectiveness of the existing automated system flag (`isFlaggedFraud`).
3. Uncover behavioral anomalies in sender and receiver account balances (such as complete balance draining and zero-balance pass-through accounts).
4. Build and evaluate a multi-condition **rule-based fraud detection filter** using SQL.
5. Optimize query execution performance and build a reusable reporting view for MIS and executive dashboards.

---

## 2. Dataset Overview & Schema

This analysis uses a **$100,000$-row sample** from the PaySim synthetic financial dataset, which simulates mobile money transactions based on real-world financial logs.

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `step` | `INT` | Unit of time in the real world ($1\text{ step} = 1\text{ simulated hour}$) |
| `type` | `VARCHAR` | Transaction type (`PAYMENT`, `CASH_OUT`, `CASH_IN`, `TRANSFER`, `DEBIT`) |
| `amount` | `DECIMAL` | Transaction value in local currency |
| `nameOrig` | `VARCHAR` | Unique customer ID of the sender (origin account) |
| `oldbalanceOrg` | `DECIMAL` | Sender's account balance before the transaction |
| `newbalanceOrig` | `DECIMAL` | Sender's account balance after the transaction |
| `nameDest` | `VARCHAR` | Unique ID of the recipient (destination account) |
| `oldbalanceDest` | `DECIMAL` | Recipient's account balance before the transaction |
| `newbalanceDest` | `DECIMAL` | Recipient's account balance after the transaction |
| `isFraud` | `TINYINT` | Actual fraud status (`1` = Fraudulent, `0` = Normal) |
| `isFlaggedFraud` | `TINYINT` | Legacy system flag (`1` = Flagged by system, `0` = Not flagged) |

### Dataset Scope & Limitations
* The sample contains **$100,000$ total rows** and **$116$ verified fraudulent transactions** ($0.12\%$ overall fraud rate), reflecting the extreme class imbalance typical of real-world banking data.
* Because this is a chronological sample from the beginning of the simulation log, customer origin accounts (`nameOrig`) appear as single events rather than long multi-month histories.

---

## 3. SQL Project Structure (35 Queries)

All SQL queries are organized into 5 logical sections inside [`banking_fraud_analysis.sql`](./banking_fraud_analysis.sql):

* **Section 1: Data Validation & Exploratory Overview (Queries 1–4)**
  * Dataset volume, unique senders/receivers, `NULL` value checks, exact duplicate checks, and volume breakdown by transaction type.
* **Section 2: Core Fraud Metrics & Type Breakdown (Queries 5–12)**
  * Total fraud count, fraud value, average ticket size comparison (Fraud vs. Normal), top 10 largest fraud transactions, and hourly (`step`) trends.
* **Section 3: Amount Tiers, System Flags & Window Function Rankings (Queries 13–21)**
  * Value segmentation (`CASE WHEN`), evaluation of `isFlaggedFraud`, top 5 transactions per type using CTEs and `ROW_NUMBER()`, and repeat sender/receiver checks.
* **Section 4: Account Balance Discrepancies & Anomaly Patterns (Queries 22–29)**
  * Sender vs. receiver balance reconciliation, complete account balance draining (`newbalanceOrig = 0`), overdrafts (`amount > oldbalanceOrg`), and unreflected receiver balances (`oldbalanceDest = 0` and `newbalanceDest = 0`).
* **Section 5: Rule-Based Detection, Views & Performance Optimization (Queries 30–35)**
  * Multi-condition SQL fraud filter, precision and recall evaluation, 1-to-1 paired pass-through transaction detection (`TRANSFER` followed by `CASH_OUT`), `DENSE_RANK()` analysis, reusable reporting view (`v_fraud_risk_summary`), and `EXPLAIN` query execution plan analysis.

---

## 4. Key Analytical Findings

### 1. Fraud Occurs Exclusively in `TRANSFER` and `CASH_OUT`
* Out of $100,000$ transactions, all **$116$ fraudulent transactions** occurred in only two channels: **`TRANSFER`** and **`CASH_OUT`**.
* `PAYMENT`, `CASH_IN`, and `DEBIT` recorded **$0$ fraudulent transactions** ($0.00\%$ fraud rate).
* Fraudulent transactions carry a significantly higher average transaction value than normal transactions, as attackers attempt to maximize stolen funds in a single transfer.

### 2. Legacy System Flag (`isFlaggedFraud`) Caught $0\%$ of Fraud
* Evaluating `isFlaggedFraud` against `isFraud` (Queries 14 & 15) revealed that the default system flag detected **$0$ out of $116$ fraudulent transactions** ($0.00\%$ detection rate), proving that simple static amount thresholds fail to catch real-world account takeovers.

### 3. Complete Account Balance Draining ($94.8\%$ of All Fraud)
* In **Query 26**, analyzing transactions where a positive sender balance was completely emptied (`oldbalanceOrg > 0 AND newbalanceOrig = 0`) captured **$110$ out of the $116$ total fraud cases** ($94.83\%$ of all fraud in the dataset).
* While legitimate customers occasionally empty their accounts during `CASH_OUT` or `PAYMENT`, complete balance draining during a `TRANSFER` is a primary indicator of compromised credentials.

![Account Balance Draining Analysis](./screenshots/query_26_balance_draining.png)

### 4. Unreflected Destination Balances Signal Pass-Through Laundering ($66.67\%$ Fraud Rate)
* **Query 28** showed that fraudulent transfers frequently target recipient accounts with a starting balance of zero (`oldbalanceDest = 0`).
* **Query 29** isolated transactions where money was sent to a zero-balance account and the destination balance **still remained zero** after the transaction (`oldbalanceDest = 0 AND newbalanceDest = 0 AND amount > 0`). In the `TRANSFER` channel, **$66.67\%$ of these transactions were confirmed fraud**, indicating immediate pass-through laundering before ledger updates.

![Zero Starting Receiver Balance](./screenshots/query_28_zero_initial_dest_balance.png)

![Unreflected Receiver Balance Fraud Rate](./screenshots/query_29_unreflected_dest_balance.png)

### 5. Paired 1-to-1 Pass-Through Fraud (`TRANSFER` $\rightarrow$ `CASH_OUT`)
* **Query 32** grouped `TRANSFER` and `CASH_OUT` transactions by identical `step` (hour) and identical `amount`.
* The results proved the core laundering pattern in the dataset: attackers first execute a `TRANSFER` from the victim's account to a mule account, and within the exact same hour (`step`), execute a matching `CASH_OUT` for the exact same amount.

![Paired Pass-Through Fraud](./screenshots/query_32_paired_passthrough_fraud.png)

---

## 5. Rule-Based Fraud Filter Evaluation (Precision & Recall)

In **Queries 30 and 31**, a custom rule-based SQL filter was created using the behavioral patterns discovered in Section 4:

```sql
WHERE type IN ('TRANSFER', 'CASH_OUT')
  AND oldbalanceOrg > 0
  AND newbalanceOrig = 0
  AND oldbalanceDest = 0
```

* **Recall Rate (Fraud Coverage):** The rule successfully captured **$73$ out of $116$ total fraudulent transactions** ($\text{Recall} = \frac{73}{116} \times 100 = 62.93\%$), compared to $0.00\%$ from the legacy `isFlaggedFraud` column.
* **Operational Insight:** Because legitimate `CASH_OUT` transactions also frequently empty small balances into zero-balance merchant/ATM accounts, applying this rule to `TRANSFER` transactions alone—or combining it with minimum amount thresholds and `newbalanceDest = 0`—dramatically reduces false positives for fraud investigation teams.

![Rule Precision and Recall Evaluation](./screenshots/query_31_rule_precision_recall.png)

---

## 6. Reporting View & Query Optimization

* **Executive Reporting View (Query 34):** Created a reusable SQL view (`v_fraud_risk_summary`) that aggregates transaction volume, total value, average ticket size, confirmed fraud count, total fraud value, and fraud rate percentage by transaction type for direct connection to BI tools like Power BI or Excel.

![Fraud Risk Summary View](./screenshots/query_34_fraud_risk_summary_view.png)

* **Performance Optimization (Query 35):** Running `EXPLAIN` on the fraud filtering query revealed a full-table scan (`type = ALL`) across the transaction table. In a production banking environment, creating a composite B-Tree index reduces disk I/O and speeds up real-time fraud monitoring:

```sql
CREATE INDEX idx_type_isfraud ON transactions (type, isFraud);
```

---

## 7. Business Recommendations

1. **Enforce Step-Up Authentication on Balance-Draining Transfers:** Require multi-factor authentication (OTP/biometric verification) and a temporary cooling period whenever a `TRANSFER` transaction drains $100\%$ of an account's available balance (`newbalanceOrig = 0`).
2. **Block Rapid Pass-Through `CASH_OUT` Requests:** Implement a velocity rule that flags or holds `CASH_OUT` requests when the exact same amount was received via `TRANSFER` within the same hour (`step`).
3. **Audit Zero-Balance Mule Accounts:** Automatically flag recipient accounts where `oldbalanceDest = 0` and `newbalanceDest = 0` on high-value incoming transfers.
4. **Replace Static Threshold Flags:** Retire the ineffective `isFlaggedFraud` static rule and transition to multi-condition behavioral rules combining transaction channel (`TRANSFER`, `CASH_OUT`), balance depletion ratio, and destination account history.

---

## 8. How to Run This Project

1. Clone or download this repository.
2. Open **MySQL Workbench** and create the database:
   ```sql
   CREATE DATABASE banking_fraud_analysis;
   USE banking_fraud_analysis;
   ```
3. Import the $100,000$-row PaySim CSV sample into a table named `transactions`.
4. Open [`banking_fraud_analysis.sql`](./banking_fraud_analysis.sql) and run the queries section by section.