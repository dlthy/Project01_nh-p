select*from sales_dataset_rfm_prj
create table SALES_DATASET_RFM_PRJ
(
  ordernumber VARCHAR,
  quantityordered VARCHAR,
  priceeach        VARCHAR,
  orderlinenumber  VARCHAR,
  sales            VARCHAR,
  orderdate        VARCHAR,
  status           VARCHAR,
  productline      VARCHAR,
  msrp             VARCHAR,
  productcode      VARCHAR,
  customername     VARCHAR,
  phone            VARCHAR,
  addressline1     VARCHAR,
  addressline2     VARCHAR,
  city             VARCHAR,
  state            VARCHAR,
  postalcode       VARCHAR,
  country          VARCHAR,
  territory        VARCHAR,
  contactfullname  VARCHAR,
  dealsize         VARCHAR
) 
--1) Chuyển đổi kiểu dữ liệu phù hợp cho các trường ( sử dụng câu lệnh ALTER) 
alter table sales_dataset_rfm_prj
alter column ordernumber type integer using ordernumber::integer,
alter column quantityordered type integer using quantityordered::integer,
alter column  priceeach  type numeric using priceeach::numeric,
alter column orderlinenumber type integer using  orderlinenumber::integer,
alter column sales type numeric using sales::numeric,
alter column orderdate type date using orderdate::date,
alter column msrp type integer using msrp::integer,
alter column productcode  type text using productcode::text,
alter column customername  type text using customername::text,
alter column phone  type text using phone::text,
alter column addressline1 type text using addressline1::text,
alter column addressline2 type text using addressline2::text,
alter column city  type text using city::text,
alter column state type text using state::text,
alter column postalcode type text using postalcode::text,
alter column country  type text using country::text,
alter column territory type text using territory::text,
alter column contactfullname type text using contactfullname::text,
alter column dealsize type text using dealsize::text

-- 2) Check NULL/BLANK (‘’)  ở các trường: ORDERNUMBER, QUANTITYORDERED, PRICEEACH, ORDERLINENUMBER, SALES, ORDERDATE.
Select count(*)
From sales_dataset_rfm_prj
Where ORDERNUMBER is null
or QUANTITYORDERED is null
or PRICEEACH is null 
or ORDERLINENUMBER is null
or SALES is null
or ORDERDATE is null 

-- Thêm cột CONTACTLASTNAME, CONTACTFIRSTNAME được tách ra từ CONTACTFULLNAME . 
-- Chuẩn hóa CONTACTLASTNAME, CONTACTFIRSTNAME theo định dạng chữ cái đầu tiên viết hoa, chữ cái tiếp theo viết thường. 
-- Gợi ý: ( ADD column sau đó INSERT)
alter table sales_dataset_rfm_prj
add CONTACTLASTNAME text,
add	CONTACTFIRSTNAME text
 

with cte as 
( 
select 
	substring (contactfullname from 1 for position ('-'in contactfullname)-1) as contactlastname ,
	substring (contactfullname from position ('-'in contactfullname)+1 for 50) as contactfirstname
from sales_dataset_rfm_prj)

select
	contactlastname as CONTACTLASTNAME,
	contactfirstname as CONTACTFIRSTNAME
from cte
set contactfullname = upper(left(contactfullname,1))||substring(contactfullname from 2 for 50)
update sales_dataset_rfm_prj
set contactfullname = upper(left(contactfullname,1))||substring(contactfullname from 2 for 50),
 contactlastname = substring (contactfullname from 1 for position ('-'in contactfullname)-1),
 contactfirstname = substring (contactfullname from position ('-'in contactfullname)+1 for 50)
 update sales_dataset_rfm_prj set contactfirstname = upper(left(contactfirstname,1))||substring(contactfirstname from 2 for 50)
-- Thêm cột QTR_ID, MONTH_ID, YEAR_ID lần lượt là Qúy, tháng, năm được lấy ra từ ORDERDATE 
alter table sales_dataset_rfm_prj
add QTR_ID integer,
add MONTH_ID integer,
add year_id integer

update sales_dataset_rfm_prj
set QTR_ID= extract (quarter from orderdate),
	MONTH_ID = extract (month from orderdate),
	YEAR_ID= extract (year from orderdate) 

--Hãy tìm outlier (nếu có) cho cột QUANTITYORDERED và hãy chọn cách xử lý cho bản ghi đó (2 cách) ( Không chạy câu lệnh trước khi bài được review)
--Cach 1
with cte as (
select ordernumber,quantityordered ,
(select avg(quantityordered) 
from sales_dataset_rfm_prj) as avg,
(select stddev(quantityordered) 
 from sales_dataset_rfm_prj) as stddev
from sales_dataset_rfm_prj)
select ordernumber,quantityordered, 
(quantityordered-avg)/stddev as z_score
from cte
where abs((quantityordered-avg)/stddev)>3
--Cach 2
with twt_min_max_value as(
SELECT Q1-1.5*IQR AS min_value,
Q3+1.5*IQR as max_value
from (
select 
percentile_cont(0.25) WITHIN GROUP (ORDER BY quantityordered) as Q1,
percentile_cont(0.75) WITHIN GROUP (ORDER BY quantityordered) as Q3,
percentile_cont(0.75) WITHIN GROUP (ORDER BY quantityordered) -percentile_cont(0.25) WITHIN GROUP (ORDER BY quantityordered) as IQR
from sales_dataset_rfm_prj ))
select * from sales_dataset_rfm_prj
where quantityordered< (select min_value from twt_min_max_value)
or quantityordered>(select max_value from twt_min_max_value)
--Sau khi làm sạch dữ liệu, hãy lưu vào bảng mới tên là SALES_DATASET_RFM_PRJ_CLEAN
delete from sales_dataset_rfm_prj
