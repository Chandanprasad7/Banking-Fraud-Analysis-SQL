-- ============================================================================
-- Project Title : Banking Transaction and Fraud Analysis Using MySQL
-- Author        : Chandan Prasad
-- Dataset       : PaySim Synthetic Financial Dataset (100,000-row sample)
-- Database      : banking_fraud_analysis
-- Main Table    : transactions
-- ============================================================================

USE banking_fraud_analysis;

-- ============================================================================
-- SECTION 1: DATA VALIDATION & EXPLORATORY OVERVIEW (Queries 1 - 4)
-- ============================================================================

-- Query 1: Dataset overview and summary statistics
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT nameOrig) AS unique_senders,
    COUNT(DISTINCT nameDest) AS unique_receivers,
    ROUND(SUM(amount), 2) AS total_transaction_value,
    ROUND(AVG(amount), 2) AS average_transaction_value,
    MAX(amount) AS highest_transaction_value,
    MIN(amount) AS lowest_transaction_value
FROM transactions;

-- Query 2: Check for missing (NULL) values across key columns
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS missing_amount,
    SUM(CASE WHEN type IS NULL THEN 1 ELSE 0 END) AS missing_type,
    SUM(CASE WHEN nameOrig IS NULL THEN 1 ELSE 0 END) AS missing_sender,
    SUM(CASE WHEN nameDest IS NULL THEN 1 ELSE 0 END) AS missing_receiver,
    SUM(CASE WHEN isFraud IS NULL THEN 1 ELSE 0 END) AS missing_fraud_status
FROM transactions;

-- Query 3: Check for exact duplicate transactions
SELECT
    step,
    type,
    amount,
    nameOrig,
    oldbalanceOrg,
    newbalanceOrig,
    nameDest,
    oldbalanceDest,
    newbalanceDest,
    isFraud,
    isFlaggedFraud,
    COUNT(*) AS duplicate_count
FROM transactions
GROUP BY
    step,
    type,
    amount,
    nameOrig,
    oldbalanceOrg,
    newbalanceOrig,
    nameDest,
    oldbalanceDest,
    newbalanceDest,
    isFraud,
    isFlaggedFraud
HAVING COUNT(*) > 1;

-- Query 4: Transaction counts and total amount by transaction type
SELECT
    type,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_amount
FROM transactions
GROUP BY type
ORDER BY total_transactions DESC;

-- ============================================================================
-- SECTION 2: CORE FRAUD METRICS & TYPE BREAKDOWN (Queries 5 - 12)
-- ============================================================================

-- Query 5: Total fraudulent transactions count
SELECT
    COUNT(*) AS total_fraud_transactions
FROM transactions
WHERE isFraud = 1;

-- Query 6: Total amount of fraudulent transactions
SELECT
    ROUND(SUM(amount), 2) AS total_fraud_amount
FROM transactions
WHERE isFraud = 1;

-- Query 7: Fraudulent transaction count, total amount, and average amount by type
SELECT
    type,
    COUNT(*) AS fraud_count,
    ROUND(SUM(amount), 2) AS total_fraud_amount,
    ROUND(AVG(amount), 2) AS average_fraud_amount
FROM transactions
WHERE isFraud = 1
GROUP BY type
ORDER BY total_fraud_amount DESC;

-- Query 8: Fraud rate percentage by transaction type
SELECT
    type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage
FROM transactions
GROUP BY type
ORDER BY fraud_rate_percentage DESC;

-- Query 9: Average fraudulent transaction amount
SELECT
    ROUND(AVG(amount), 2) AS average_fraud_amount
FROM transactions
WHERE isFraud = 1;

-- Query 10: Fraudulent vs. Normal transaction count and average amount
SELECT
    isFraud,
    COUNT(*) AS total_transactions,
    ROUND(AVG(amount), 2) AS average_amount
FROM transactions
GROUP BY isFraud;

-- Query 11: Top 10 highest-value fraudulent transactions
SELECT
    step,
    type,
    amount,
    nameOrig,
    nameDest,
    isFraud
FROM transactions
WHERE isFraud = 1
ORDER BY amount DESC
LIMIT 10;

-- Query 12: Fraud analysis by simulated hour (step)
SELECT
    step,
    COUNT(*) AS fraud_count,
    ROUND(SUM(amount), 2) AS total_fraud_amount
FROM transactions
WHERE isFraud = 1
GROUP BY step
ORDER BY total_fraud_amount DESC;

-- ============================================================================
-- SECTION 3: AMOUNT TIERS, SYSTEM FLAGS & RANKINGS (Queries 13 - 21)
-- ============================================================================

-- Query 13: Fraud analysis by transaction amount category
SELECT
    CASE
        WHEN amount < 100000 THEN 'Low Value'
        WHEN amount < 500000 THEN 'Medium Value'
        ELSE 'High Value'
    END AS amount_category,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage
FROM transactions
GROUP BY amount_category
ORDER BY fraud_rate_percentage DESC;

-- Query 14: Fraud detection flag analysis (isFraud vs. isFlaggedFraud)
SELECT
    isFraud,
    isFlaggedFraud,
    COUNT(*) AS transaction_count
FROM transactions
GROUP BY isFraud, isFlaggedFraud
ORDER BY isFraud DESC, isFlaggedFraud DESC;

-- Query 15: Fraud flag detection rate on actual fraud transactions
SELECT
    COUNT(*) AS total_fraud_transactions,
    SUM(CASE WHEN isFlaggedFraud = 1 THEN 1 ELSE 0 END) AS flagged_fraud_transactions,
    ROUND(
        SUM(CASE WHEN isFlaggedFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS flag_detection_rate
FROM transactions
WHERE isFraud = 1;

-- Query 16: Rank top 5 transactions by amount within each type using ROW_NUMBER()
WITH ranked_transactions AS (
    SELECT
        type,
        amount,
        nameOrig,
        nameDest,
        ROW_NUMBER() OVER (
            PARTITION BY type
            ORDER BY amount DESC
        ) AS transaction_rank
    FROM transactions
)
SELECT *
FROM ranked_transactions
WHERE transaction_rank <= 5
ORDER BY type, transaction_rank;

-- Query 17: Rank top 5 fraudulent transactions by amount within each type
WITH ranked_fraud AS (
    SELECT
        type,
        amount,
        nameOrig,
        nameDest,
        ROW_NUMBER() OVER (
            PARTITION BY type
            ORDER BY amount DESC
        ) AS fraud_rank
    FROM transactions
    WHERE isFraud = 1
)
SELECT *
FROM ranked_fraud
WHERE fraud_rank <= 5
ORDER BY type, fraud_rank;

-- Query 18: Find repeated fraudulent senders
SELECT
    nameOrig,
    COUNT(*) AS fraud_transactions,
    ROUND(SUM(amount), 2) AS total_fraud_amount
FROM transactions
WHERE isFraud = 1
GROUP BY nameOrig
HAVING COUNT(*) > 1
ORDER BY fraud_transactions DESC;

-- Query 19: Find repeated fraudulent receivers
SELECT
    nameDest,
    COUNT(*) AS fraud_transactions,
    ROUND(SUM(amount), 2) AS total_fraud_amount
FROM transactions
WHERE isFraud = 1
GROUP BY nameDest
HAVING COUNT(*) > 1
ORDER BY fraud_transactions DESC;

-- Query 20: Fraud count and total fraud amount by detailed amount range
SELECT
    CASE
        WHEN amount < 10000 THEN 'Below 10K'
        WHEN amount < 100000 THEN '10K - 100K'
        WHEN amount < 500000 THEN '100K - 500K'
        ELSE 'Above 500K'
    END AS amount_range,
    COUNT(*) AS fraud_transactions,
    ROUND(SUM(amount), 2) AS total_fraud_amount
FROM transactions
WHERE isFraud = 1
GROUP BY amount_range
ORDER BY fraud_transactions DESC;

-- Query 21: Fraud rate percentage by detailed transaction amount range
SELECT
    CASE
        WHEN amount < 10000 THEN 'Below 10K'
        WHEN amount < 100000 THEN '10K - 100K'
        WHEN amount < 500000 THEN '100K - 500K'
        ELSE 'Above 500K'
    END AS amount_range,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage
FROM transactions
GROUP BY amount_range
ORDER BY fraud_rate_percentage DESC;

-- ============================================================================
-- SECTION 4: BALANCE DISCREPANCIES & ANOMALY PATTERNS (Queries 22 - 29)
-- ============================================================================

-- Query 22: Fraudulent vs. Normal Transaction Analysis (Average & Max Amount)
SELECT
    CASE
        WHEN isFraud = 1 THEN 'Fraudulent'
        ELSE 'Normal'
    END AS transaction_status,
    COUNT(*) AS total_transactions,
    ROUND(AVG(amount), 2) AS average_amount,
    ROUND(MAX(amount), 2) AS highest_amount
FROM transactions
GROUP BY transaction_status
ORDER BY average_amount DESC;

-- Query 23: Fraud analysis by sender's starting balance category
SELECT
    CASE
        WHEN oldbalanceOrg < 10000 THEN 'Low Balance'
        WHEN oldbalanceOrg < 100000 THEN 'Medium Balance'
        ELSE 'High Balance'
    END AS balance_category,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage
FROM transactions
GROUP BY balance_category
ORDER BY fraud_rate_percentage DESC;

-- Query 24: Analyze sender balance discrepancies in fraudulent transactions
SELECT
    type,
    COUNT(*) AS fraud_transactions,
    ROUND(SUM(amount), 2) AS total_fraud_amount,
    ROUND(AVG(oldbalanceOrg), 2) AS avg_old_sender_balance,
    ROUND(AVG(newbalanceOrig), 2) AS avg_new_sender_balance,
    ROUND(AVG(oldbalanceOrg - newbalanceOrig), 2) AS avg_balance_difference
FROM transactions
WHERE isFraud = 1
GROUP BY type
ORDER BY total_fraud_amount DESC;

-- Query 25: Analyze receiver balance discrepancies in fraudulent transactions
SELECT
    type,
    COUNT(*) AS fraud_transactions,
    ROUND(SUM(amount), 2) AS total_fraud_amount,
    ROUND(AVG(oldbalanceDest), 2) AS avg_old_receiver_balance,
    ROUND(AVG(newbalanceDest), 2) AS avg_new_receiver_balance,
    ROUND(AVG(newbalanceDest - oldbalanceDest), 2) AS avg_receiver_balance_change
FROM transactions
WHERE isFraud = 1
GROUP BY type
ORDER BY total_fraud_amount DESC;

-- Query 26: Identify complete account balance draining (Zero Balance After Transaction)
SELECT
    type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage
FROM transactions
WHERE oldbalanceOrg > 0
  AND newbalanceOrig = 0
GROUP BY type
ORDER BY fraud_count DESC;

-- Query 27: Transactions where amount exceeds the sender's available balance
SELECT
    type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage,
    ROUND(AVG(amount - oldbalanceOrg), 2) AS avg_excess_amount
FROM transactions
WHERE amount > oldbalanceOrg
GROUP BY type
ORDER BY fraud_count DESC;

-- Query 28: Receiver accounts with zero initial balance that received funds
SELECT
    type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage,
    ROUND(AVG(amount), 2) AS avg_received_amount
FROM transactions
WHERE oldbalanceDest = 0
  AND amount > 0
GROUP BY type
ORDER BY fraud_count DESC;

-- Query 29: Receiver accounts where destination balance remained zero after receiving money
SELECT
    type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage,
    ROUND(SUM(amount), 2) AS total_unreflected_amount
FROM transactions
WHERE oldbalanceDest = 0
  AND newbalanceDest = 0
  AND amount > 0
GROUP BY type
ORDER BY fraud_count DESC;

-- ============================================================================
-- SECTION 5: RULE-BASED DETECTION, VIEWS & OPTIMIZATION (Queries 30 - 35)
-- ============================================================================

-- Query 30: Multi-condition high-risk fraud detection filter
SELECT
    step,
    type,
    amount,
    nameOrig,
    oldbalanceOrg,
    newbalanceOrig,
    nameDest,
    oldbalanceDest,
    newbalanceDest,
    isFraud
FROM transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
  AND oldbalanceOrg > 0
  AND newbalanceOrig = 0
  AND oldbalanceDest = 0
ORDER BY amount DESC;

-- Query 31: Performance evaluation of the rule-based filter against actual fraud labels
SELECT
    COUNT(*) AS flagged_transactions,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS true_positives,
    SUM(CASE WHEN isFraud = 0 THEN 1 ELSE 0 END) AS false_positives,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS precision_rate_percentage,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / 116,
        2
    ) AS recall_rate_percentage
FROM transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
  AND oldbalanceOrg > 0
  AND newbalanceOrig = 0
  AND oldbalanceDest = 0;

-- Query 32: Detect paired pass-through transactions (Same step and identical amount across TRANSFER and CASH_OUT)
SELECT
    step,
    amount,
    COUNT(*) AS total_matching_transactions,
    SUM(CASE WHEN type = 'TRANSFER' THEN 1 ELSE 0 END) AS transfer_count,
    SUM(CASE WHEN type = 'CASH_OUT' THEN 1 ELSE 0 END) AS cash_out_count,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_count
FROM transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY step, amount
HAVING transfer_count > 0
   AND cash_out_count > 0
ORDER BY fraud_count DESC, amount DESC;

-- Query 33: Rank fraudulent transactions within each transaction type using DENSE_RANK()
SELECT
    type,
    amount,
    nameOrig,
    nameDest,
    oldbalanceOrg,
    newbalanceOrig,
    DENSE_RANK() OVER (
        PARTITION BY type
        ORDER BY amount DESC
    ) AS fraud_amount_rank
FROM transactions
WHERE isFraud = 1;

-- Query 34: Create a reusable reporting view summarizing key metrics by transaction type
CREATE OR REPLACE VIEW v_fraud_risk_summary AS
SELECT
    type,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_amount,
    ROUND(AVG(amount), 2) AS avg_amount,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_transactions,
    ROUND(SUM(CASE WHEN isFraud = 1 THEN amount ELSE 0 END), 2) AS total_fraud_amount,
    ROUND(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percentage
FROM transactions
GROUP BY type;

-- Query the view to verify
SELECT *
FROM v_fraud_risk_summary
ORDER BY total_fraud_amount DESC;

-- Query 35: Query execution plan and performance check for fraud filtering
EXPLAIN
SELECT
    step,
    type,
    amount,
    nameOrig,
    nameDest,
    oldbalanceOrg,
    newbalanceOrig
FROM transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
  AND isFraud = 1;
