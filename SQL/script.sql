-- Calculate RFM from Recency, Frequency, Monetary

-- Traditional way
-- use as a common table 
with calculating_stats as( 
select CustomerID, 
-- calculate Recency (how long the last time customer purchase)
datediff('2022-09-01', max(ct.Purchase_Date)) as Recency, 
-- calculate Frequency (frequency of date that customer purchase)
count(distinct ct.Purchase_Date) as Frequency, 
-- calculate Monetary (how much has the customer spent)
sum(GMV) as Monetary  
from customer_transaction ct
where CustomerID != 0 # ID = 0 la khach vang lai 
group by CustomerID ),

-- use as a common table 
RFM as (
-- divide into 4 levels
select *, case when Recency >= 92 then '1'
			   when Recency < 92 and Recency >= 62 then '2'
			   when Recency < 62 and Recency >= 31 then '3'
			   else '4' end as R, 
		  case when Frequency >= 1 and Frequency < 2 then '1'
			   when Frequency >= 2 and Frequency < 3 then '2'
			   when Frequency >= 3  and Frequency < 4 then '3'
			   else '4' end as F,
		  case when Monetary >= 0 and Monetary < 87826 then '1'
			   when Monetary >= 87.826 and Monetary < 170000 then '2'
			   when Monetary >= 170000 and Monetary < 200000 then '3'
			   else '4' end as M
from calculating_stats ) -- take RFM from calculating_stats table above

select * from RFM

-- Advanced Technique using window function
with calculating_stats as(
select CustomerID, datediff('2022-09-01', max(ct.Purchase_Date)) as Recency, 
count(distinct ct.Purchase_Date) as Frequency, 
sum(GMV) as Monetary  
from customer_transaction ct
where CustomerID != 0 # ID = 0 la khach vang lai 
group by CustomerID )

# F và M càng cao thì giá trị càng lớn (chú ý thứ tự order)
select *, ntile(4) over (order by Recency desc) as R, 
		ntile(4) over (order by Frequency asc) as F,
		ntile(4) over (order by Monetary asc) as M
from calculating_stats