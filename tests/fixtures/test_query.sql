-- name: Test Query From File
-- description: A test query loaded from SQL file
-- tags: test, fixture
-- private: true

SELECT 
    date_trunc('day', block_time) as date,
    count(*) as transaction_count,
    sum(amount_usd) as total_volume
FROM dex.trades
WHERE block_time >= now() - interval '7' day
GROUP BY 1
ORDER BY 1 DESC
