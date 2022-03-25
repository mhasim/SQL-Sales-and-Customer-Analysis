----- CHANGING TABLE NAMES AND ASSIGNING PRIMARY KEYS
-- CUST_DIMEN TABLE
SELECT * FROM cust_dimen

ALTER TABLE cust_dimen
ADD PRIMARY KEY (Cust_id)

SELECT * FROM cust_dimen

-- MARKET_FACT TABLE
SELECT * FROM market_fact

EXEC sp_rename '[dbo].[market_fact.xlsx - market_fact]', 'market_fact'

ALTER TABLE market_fact
ADD PRIMARY KEY 

-- ORDERS_DIMEN TABLE
EXEC sp_rename '[dbo].[orders_dimen (1)]', 'orders_dimen'

select * from orders_dimen

ALTER TABLE orders_dimen
ADD PRIMARY KEY (Ord_id)

-- PROD_DIMEN TABLE
EXEC sp_rename '[dbo].[prod_dimen.xlsx - prod_dimen]', 'prod_dimen'

select * from prod_dimen

ALTER TABLE prod_dimen
add PRIMARY KEY (Prod_id)

-- SHIPPING_DIMEN
EXEC sp_rename '[dbo].[shipping_dimen (2)]', 'shipping_dimen'
EXEC sp_rename 'dbo.shipping_dimen.Ship_Date', 'ship_veh'
EXEC sp_rename 'dbo.shipping_dimen.Ship_id', 'ship_date'
EXEC sp_rename 'dbo.shipping_dimen.column5', 'shipping_id'
EXEC sp_rename 'dbo.shipping_dimen.shipping_id', 'Ship_id' 


select * from shipping_dimen

alter TABLE shipping_dimen
add PRIMARY KEY (Ship_id)

SELECT ('Ord_' + CAST(Order_ID AS varchar))
from shipping_dimen

ALTER TABLE shipping_dimen
ALTER COLUMN Order_ID VARCHAR (25)

UPDATE shipping_dimen
SET Order_ID = 'Ord_' + CAST(Order_ID AS varchar)

EXEC sp_rename 'shipping_dimen.Order_ID', 'Ord_id'

----- Analyze the data by finding the answers to the questions below:

---- 1. Using the columns of “market_fact”, “cust_dimen”, “orders_dimen”, 
---- “prod_dimen”, “shipping_dimen”, Create a new table, named as 
---- “combined_table”.
SELECT *
INTO combined_table
FROM (
    SELECT A.*, B.Customer_Name, B.Customer_Segment, B.Province, 
        B.Region, C.Order_Date, C.Order_Priority, D.Product_Category,
        D.Product_Sub_Category, E.Ship_Mode, E.ship_veh, E.ship_date
    FROM market_fact A, cust_dimen B, orders_dimen C,
        prod_dimen D, shipping_dimen E
    WHERE A.Cust_id = B.Cust_id and A.Ord_id = C.Ord_id
        and A.Prod_id = D.Prod_id and A.Ship_id = E.Ship_id
) n

SELECT *
from combined_table

---- 2. Find the top 3 customers who have the maximum count of orders.
SELECT TOP 3 A.Cust_id, A.Customer_Name, COUNT(B.Ord_id) count_of_orders
FROM cust_dimen A, market_fact B
WHERE A.Cust_id = B.Cust_id
GROUP BY A.Cust_id, A.Customer_Name
ORDER BY COUNT(B.Ord_id) DESC

---- 3. Create a new column at combined_table as DaysTakenForDelivery 
---- that contains the date difference of Order_Date and Ship_Date.
alter table combined_table
add DaysTakenForDelivery int

UPDATE combined_table
SET DaysTakenForDelivery = DATEDIFF(DAY, Order_Date, ship_date)

---- 4. Find the customer whose order took the maximum time to get delivered.
SELECT Top 1 Cust_id, Customer_Name, DaysTakenForDelivery
from combined_table
ORDER BY DaysTakenForDelivery DESC

---- 5. Count the total number of unique customers in January and how many 
---- of them came back every month over the entire year in 2011
-- List of New Customers in January 2011:
SELECT COUNT(Cust_id) New_Customers_In_January_2011
FROM combined_table
WHERE '2011-01-01' <= Order_date  and Order_date < '2011-02-01' and
Cust_id NOT IN (
    SELECT Cust_id
    FROM combined_table
    WHERE Order_date < '2011-01-01'
)
-- January 2011 customers who made purchases in every month in 2011:
CREATE VIEW Repeated_Sales AS
SELECT Cust_id, DATENAME(month, Order_Date) Repeated_Sales
FROM combined_table
WHERE Cust_id IN (
    SELECT Cust_id
    FROM combined_table
    WHERE '2011-01-01' <= Order_date  and Order_date < '2011-02-01' and
        Cust_id NOT IN (
            SELECT Cust_id
            FROM combined_table
            WHERE Order_date < '2011-01-01'
            )
) and DATENAME(YEAR, Order_Date) = '2011'

-- Customers' monthly transactions in 2011
SELECT Cust_id, 
    COUNT(CASE WHEN Repeated_Sales = 'January' THEN 1 END) AS [January],
    COUNT(CASE WHEN Repeated_Sales = 'February' THEN 1 END) AS [February],
    COUNT(CASE WHEN Repeated_Sales = 'March' THEN 1 END) AS [March],
    COUNT(CASE WHEN Repeated_Sales = 'April' THEN 1 END) AS [April],
    COUNT(CASE WHEN Repeated_Sales = 'May' THEN 1 END) AS [May],
    COUNT(CASE WHEN Repeated_Sales = 'June' THEN 1 END) AS [June],
    COUNT(CASE WHEN Repeated_Sales = 'July' THEN 1 END) AS [July],
    COUNT(CASE WHEN Repeated_Sales = 'August' THEN 1 END) AS [August],
    COUNT(CASE WHEN Repeated_Sales = 'September' THEN 1 END) AS [September],
    COUNT(CASE WHEN Repeated_Sales = 'October' THEN 1 END) AS [October],
    COUNT(CASE WHEN Repeated_Sales = 'November' THEN 1 END) AS [November],
    COUNT(CASE WHEN Repeated_Sales = 'December' THEN 1 END) AS [December]
FROM Repeated_Sales
GROUP BY Cust_id

---- 6. Write a query to return for each user the time elapsed between the 
---- first purchasing and the third purchasing, in ascending order by Customer ID.
SELECT *
FROM combined_table

Create VIEW ccte AS 
WITH cte AS (
    SELECT Cust_id, Order_date, ROW_NUMBER() OVER (PARTITION BY Cust_id ORDER BY Order_date) rn
    FROM combined_table
)

SELECT
    Cust_id,
    MAX(CASE WHEN rn = 1 THEN Order_date END) "first",
    MAX(CASE WHEN rn = 3 THEN Order_date END) "third"
FROM cte
WHERE rn <= 3
GROUP BY
    Cust_id


SELECT Cust_id, 
    DATEDIFF(DAY, first, third) 'Number_of_Days_Between_Orders'
FROM ccte
WHERE DATEDIFF(DAY, first, third) IS NOT NULL

---- 7. Write a query that returns customers who purchased both product 11 and product 14, as well 
---- as the ratio of these products to the total number of products purchased by the customer.
SELECT *
FROM combined_table

CREATE VIEW ratio AS
SELECT Cust_id, Prod_id, Order_Quantity,
    (Order_Quantity * 1.0) / SUM(Order_quantity) OVER(PARTITION BY Cust_id) Ratio
FROM combined_table
WHERE Cust_id IN (
    SELECT Cust_id
    FROM combined_table
    WHERE Prod_id = 'Prod_11'
    INTERSECT
    SELECT Cust_id
    FROM combined_table
    WHERE Prod_id = 'Prod_14'
)
-- Customers, who bought Prod_11 and Prod_14, and their total ratio
SELECT Cust_id, SUM(Ratio) total_ratio
FROM ratio
WHERE Prod_id in ('Prod_11', 'Prod_14')
GROUP BY Cust_id

----- CUSTOMER SEGMENTATION
----- Categorize customers based on their frequency of visits. 
----- The following steps will guide you. If you want, you can track your own way.

---- 1. Create a “view” that keeps visit logs of customers on a monthly basis. 
---- (For each log, three field is kept: Cust_id, Year, Month)
CREATE VIEW Logs AS
SELECT Cust_id, DATENAME(year, Order_Date) 'Year', DATENAME(month, Order_Date) 'Month', 
Order_date
FROM combined_table

SELECT * FROM Logs

---- 2. Create a “view” that keeps the number of monthly visits by users. 
---- (Show separately all months from the beginning business)
CREATE VIEW monthly_visits AS
SELECT Cust_id, DATENAME(year, Order_Date) 'Year', DATENAME(month, Order_Date) 'Month',
    COUNT(Ord_id) OVER(PARTITION BY Cust_id, DATENAME(year, Order_Date), DATENAME(month, Order_Date)) 'Number_of_Visits'
FROM combined_table

SELECT * FROM monthly_visits

---- 3. For each visit of customers, create the next month of the visit as a separate column.
SELECT Cust_id, Year, Month,
    LEAD(Month) OVER(ORDER BY Cust_id, Year) as 'next_month_of_the_visit'
FROM Logs
WHERE Cust_id = 'Cust_1012'
ORDER BY [Year], [Month], Cust_id

-- Alternative:
SELECT Cust_id, Order_Date,
    LEAD(Order_date) OVER(ORDER BY DATENAME(year, Order_Date), DATENAME(month, Order_Date)) as 'next_date_of_the_visit'
FROM combined_table


---- 4. Calculate the monthly time gap between two consecutive visits by each customer.
CREATE VIEW T2 AS
WITH T1 AS
(
SELECT Cust_id, Order_Date,
    LEAD(Order_date) OVER(Partition by Cust_id ORDER BY DATENAME(year, Order_Date), MONTH(Order_Date)) as 'next_date'
FROM combined_table
)
SELECT *, DATEDIFF(Month, Order_date, next_date) Date_diff
FROM T1
WHERE DATEDIFF(Month, Order_date, next_date) != 0

SELECT * FROM T2

---- 5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.
---- For example:
---- o Labeled as churn if the customer hasn't made another purchase in the months since they made their first purchase.
---- o Labeled as regular if the customer has made a purchase every month. Etc.
SELECT Cust_id, AVG(Date_diff) 'Avg_month_diff',
    CASE WHEN AVG(Date_diff) < 7 THEN 'regular' ELSE 'churn' END AS Cust_type
FROM T2
GROUP BY Cust_id

----- MONTH-WISE RETENTION RATE
---- Find month-by-month customer retention rate since the start of the business.
---- There are many different variations in the calculation of Retention Rate. 
---- But we will try to calculate the month-wise retention rate in this project.
---- So, we will be interested in how many of the customers in the previous month could be retained in the next month.
---- Proceed step by step by creating “views”. You can use the view you got at the end of the Customer Segmentation section as a source.

---- 1. Find the number of customers retained month-wise. (You can use time gaps)
CREATE VIEW monthly_retention AS
WITH T1 AS
(
SELECT Cust_id, Order_Date,
    LEAD(Order_Date) OVER(PARTITION BY Cust_id ORDER BY Order_Date) date2,
    DATEDIFF(month, Order_Date, (LEAD(Order_Date) OVER(PARTITION BY Cust_id ORDER BY Order_Date))) gap
FROM combined_table
)
SELECT YEAR(date2) 'Year', MONTH(date2) 'Month', SUM(gap) 'Ret_Cust'
FROM T1
WHERE gap = 1
GROUP BY YEAR(date2), MONTH(date2)
ORDER BY YEAR(date2), MONTH(date2)

---- 2. Calculate the month-wise retention rate.
CREATE VIEW monthly_cust AS
SELECT YEAR(Order_Date) 'Year', MONTH(Order_Date) 'Month', COUNT(Cust_id) 'Total_cust'
FROM combined_table
GROUP BY YEAR(Order_Date), MONTH(Order_Date)

SELECT A.Year, A.Month,
    CAST((1.00 * A.Ret_Cust / B.Total_cust) AS DECIMAL(10,2)) AS 'Ret_Rate'
FROM monthly_retention A
JOIN monthly_cust B ON A.Year = B.Year and A.Month = B.Month
ORDER BY Year, Month