/*
================================================================================
Quality Checks
================================================================================

Script Purpose:
  This script performs various quality checks for data consistency, accuracy, 
  and standardization across the 'silver' schema. It includes checks for:

  - NULL or DUPLICATE primary Keys.
  - Unwanted spaces in string fields.
  - Data Standardization and Consistency.
  - Invalid date ranges and orders.
  - Data Consistency between related fields.

Usage Notes:
  - Run these checks after data loading into silver Layer.
  - Investigate and resolve any discrepancies found during the checks.
  - At the last of this query, you can find out the actual cleaned data altogether.
  - Also I have added proper notes, key-points, and expectations from the query 
  (Please don't run the whole query all at once)

================================================================================
*/

---------------------------------------------------------------------------------------
--------------------------- Procedure for cleaning the data ---------------------------
---------------------------------------------------------------------------------------

-- Quality Check:

--------------------------- CRM TABLES ---------------------------

----------------------
TABLE : cst_id
----------------------

-- 1. Duplicates OR NULL - A primary key must be unique and NOT NULL 
-- Checking whether we have duplicated values or not 

	SELECT 
		cst_id,
		COUNT(*) Duplicates
	FROM bronze.crm_cust_info
	GROUP BY cst_id
	HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Removing all the duplicated values using Windows Functions and ranking them
-- Ranking them according to dates and fetching the latest date 

	SELECT *
	FROM
		(SELECT 
			*,
			ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) last_update 
		FROM bronze.crm_cust_info) t
	WHERE last_update = 1
	
-- 2. Check for unwanted spaces in string values
-- Expectation : NO RESULT

-- These 2 COLUMNS THAT are OK! - cst_gndr AND cst_marital_status

PROBLEMS ARE IN these 2 COLUMNS:

-- cst_firstname

SELECT 
	cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- cst_lastname

SELECT 
	cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

-- 3. Check the consistency of values in low cardinality columns 
-- Expectation: In our Data Warehouse, we aim to store clear and meaningful values rather than data abbreviated terms 
-- 				Also, make sure to change the abbreviated terms in UPPER AND unwanted space

-- abbreviated terms : M, F(cst_gndr)  OR  M, S (cst_marital_status) 
INSTEAD 
-- meaningful terms  : Male, Female(cst_gndr)  OR  Married, Single (cst_marital_status) 

-- cst_marital_status
  
SELECT 
	DISTINCT cst_marital_status
FROM bronze.crm_cust_info;

-- cst_gndr

SELECT 
	DISTINCT cst_gndr
FROM bronze.crm_cust_info;
------------------------------------------------------------------------------------------------------

----------------
CLEANED QUERY:
----------------

TABLE: crm_cust_info

SELECT 
	cst_id,
	cst_key,
	TRIM(cst_firstname) AS cst_firstname,
	TRIM(cst_lastname)	AS cst_lastname,
	CASE
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
		WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
		ELSE 'n/a'
	END 
		AS cst_marital_status,
	CASE
		WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
		WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
		ELSE 'n/a'
	END 
		AS cst_gndr,
	cst_create_date
FROM
	(SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) last_update 
	FROM bronze.crm_cust_info
	WHERE cst_id IS NOT NULL) t
WHERE last_update = 1

------------------------------------------------------------------------------------------------------

----------------------
TABLE : crm_prd_info
----------------------

-- 1. Duplicates OR NULL - A primary key must be unique and NOT NULL 

NO NULL PRESENT in prd_id


-- 2.	 Column: prd_key 
-- 		For connecting table erp_loc_a101, we need column: REFERENCES(1)
-- 		For connecting table erp_px_cat_g1v2, we need column: REFERENCES(2)

	prd_key				REFERENCES(1)	REFERENCES(2)
	CO-RF-FR-R92B-58	CO_RF			FR-R92B-58

-- That's why we're making new columns using String cleaning methods

-- prd_key

SELECT
	prd_key,
	REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_'),
	SUBSTRING(prd_key, 7, LEN(prd_key))
FROM bronze.crm_prd_info;

-- 3. After checking prd_nm if there aint any unwanted spaces and etc
	
	SELECT
		prd_nm 
	FROM bronze.crm_prd_info
	WHERE prd_nm != TRIM(prd_nm)
	
-- 4. Moving to prd_cost checking if there is any value negative or null:

	SELECT 
		prd_cost 
	FROM bronze.crm_prd_info
	WHERE 
		prd_cost < 0 OR prd_cost IS NULL;
		
-- In the main query if its advised to change the value to 0 then we can do that:
	
	ISNULL(prd_cost, 0) OR COALESCE(prd_cost, 0)

-- 5. abbreviated terms in prd_line

	SELECT DISTINCT prd_line FROM bronze.crm_prd_info

	SELECT
		prd_line,
		CASE UPPER(TRIM(prd_line))
			WHEN  'M' THEN 'Mountain'
			WHEN  'R' THEN 'Road'
			WHEN  'S' THEN 'Other Sales'
			WHEN  'T' THEN 'Touring'
			ELSE 'n/a'
		END AS prd_lines
	FROM bronze.crm_prd_info;
	
-- 6. For complex transformation SQL, typically narrow it down to specific example and brainstorm multiple solution approaches 
-- (COPY AND PASTE SOME EXAMPLES IN EXCEL AND CHECK)

/*
============================================================================================================
Problem in prd_start_dt and prd_end_dt is:

  - Sometimes start date is NULL (Not right)- End date could be but NULL   
  - Sometimes start date is OVERLAPPING End date - That means we are getting 2 different values for same date 
  - And mainly Start Date should be smaller than End Date 
  - Also End date of the following start Date should be smaller 
  - Also there is no need of Time as every single record has 0:00:00 time which is meaningless.


Solution :
End Date =  Start Date of the 'NEXT' Record 
============================================================================================================
*/
	CAST(prd_start_dt AS DATE) AS prd_start_dt,
	CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_nm ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt

------------------------------------------------------------------------------------------------------

----------------
CLEANED QUERY:
----------------

TABLE: crm_prd_info

SELECT
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
	SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
	prd_nm,
	COALESCE(prd_cost, 0) AS prd_cost,
	CASE UPPER(TRIM(prd_line))
		WHEN  'M' THEN 'Mountain'
		WHEN  'R' THEN 'Road'
		WHEN  'S' THEN 'Other Sales'
		WHEN  'T' THEN 'Touring'
		ELSE 'n/a'
	END AS prd_line,
	CAST(prd_start_dt AS DATE) AS prd_start_dt,
	CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_nm ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt
FROM bronze.crm_prd_info;

--------------------------------------------------------------------------

QUALITY CHECK AFTER INSERTING THE DATA INTO SILVER TABLE:

--------
-- Check for NULL OR DUPLICATES in PRIMARY KEY
-- Expectation - NO RESULT

SELECT 
	prd_id,
	COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

--------
-- Check for unwanted Spaces 
-- Expectation - NO RESULT

SELECT 
	prd_nm 
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

--------
-- Check for NULL or Negative Numbers
-- Expectation - NO RESULT

SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

--------
-- Data Standardization & consistency

SELECT DISTINCT prd_line
FROM silver.crm_prd_info;

--------
-- Check for invalid Date Orders

SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

--------------------------------------------------------------------------

---------------------------
TABLE : crm_sales_details
---------------------------

-- 1. Changing the sls_order_dt, sls_ship_dt, sls_due_dt to DATE FORMAT

- Checking if sls_order_dt has 8 digits or not AS YYYY/MM/DD
- Checking if there is no null value and Negative value 

-- sls_order_dt
	SELECT
		sls_order_dt
	FROM bronze.crm_sales_details
	WHERE 
		LEN(sls_order_dt) != 8 
	OR	sls_order_dt <= 0
	OR sls_order_dt IS NULL;

-- sls_ship_dt
	SELECT
		sls_ship_dt
	FROM bronze.crm_sales_details
	WHERE 
		LEN(sls_ship_dt) != 8 
	OR	sls_ship_dt <= 0
	OR sls_ship_dt IS NULL;

-- sls_due_dt
	SELECT
		sls_due_dt
	FROM bronze.crm_sales_details
	WHERE 
		LEN(sls_due_dt) != 8 
	OR	sls_due_dt <= 0
	OR sls_due_dt IS NULL;
	
-- 2. According to the Business rules

Sales = Quantity * Price
-- Negatives, 0 and NULL ARE NOT ALLOWED

	SELECT DISTINCT
		sls_sales,
		sls_quantity,
		sls_price
	FROM bronze.crm_sales_details
	WHERE 
		sls_sales != sls_quantity * sls_price
	OR	sls_sales <= 0 
	OR sls_quantity <= 0  
	OR sls_price <= 0 
	OR sls_sales IS NULL 
	OR sls_quantity IS NULL 
	OR sls_price IS NULL
	ORDER BY sls_sales, 
			sls_quantity, 
			sls_price;


IMPORTANT:
----- After facing issues here in sls_price we have to comeup with a solution -----
  
-- Advise:1
	According to the business, Data issues will be fixed directly in source system
  
-- Advise:2
	According to the business, Data is very old and we dont have budget to make the required fixes. 
	So, its on you if you want to make the changes or leave it as it is 

Solution:
-- According to the data the problems we are facing in these columns and the way to fix it is:

-- If sales is negative, zero, or null, derive it using Quantity and Price 
-- If price is Zero or null, calculate it using Sales and Quantity 
-- If price is negative, convert it to a positive Value 

	-- SELECT * FROM bronze.crm_sales_details;

	SELECT	DISTINCT
			sls_sales AS old_sls_sales,
			sls_quantity,
			sls_price AS old_sls_price,
		CASE 
			WHEN sls_sales IS NULL 
					OR sls_sales <= 0 
					OR sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity * ABS(sls_price)
			ELSE sls_sales
		END AS sls_sales,
		sls_quantity,
		CASE 
			WHEN sls_price IS NULL OR sls_price <= 0 
			THEN sls_sales / NULLIF(sls_quantity, 0)
			ELSE sls_price
		END AS sls_price
	FROM bronze.crm_sales_details; 

------------------------------------------------------------------------------------------------------

----------------
CLEANED QUERY:
----------------

TABLE: crm_sales_details

SELECT 
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
	CASE 
		WHEN LEN(sls_order_dt) != 8 
			OR	sls_order_dt = 0 
			OR sls_order_dt IS NULL 
		THEN NULL
		ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
	END AS sls_order_dt,
	CASE 
		WHEN LEN(sls_ship_dt) != 8 
			OR sls_ship_dt = 0 
			OR sls_ship_dt IS NULL 
		THEN NULL
		ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
	END AS sls_ship_dt,
	CASE 
		WHEN LEN(sls_due_dt) != 8 
			OR sls_due_dt = 0 
			OR sls_due_dt IS NULL 
		THEN NULL
		ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
	END AS sls_due_dt,
	CASE 
		WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
		THEN sls_quantity * ABS(sls_price)
		ELSE sls_sales
	END AS sls_sales,
	sls_quantity,
	CASE 
		WHEN sls_price IS NULL OR sls_price <= 0 
		THEN sls_sales / NULLIF(sls_quantity, 0)
		ELSE sls_price
	END AS sls_price
FROM bronze.crm_sales_details;

--------------------------- CRM TABLES ---------------------------

---------------------------
TABLE : erp_cust_az12
---------------------------


-- 1. In the column cid, some of the values had NAS in front which we had to remove in order to make it compatible
-- to get merged with 'crm_cust_info' table 

	SELECT 
		CASE 
			WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
			ELSE cid 
		END AS cid 
	FROM bronze.erp_cust_az12

-- For checking if any values are not in the 'crm_cust_info' table 

	SELECT 
		CASE 
			WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
			ELSE cid 
		END AS cid 
	FROM bronze.erp_cust_az12
	WHERE CASE 
			WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
			ELSE cid 
		END 
			NOT IN (SELECT 
						DISTINCT cst_key 
					FROM bronze.crm_cust_info);
					

-- 2. Identify out of range dates 

	SELECT 
		bdate
	FROM bronze.erp_cust_az12
	WHERE 
		bdate < '1924-01-01' 
	OR 
		bdate > GETDATE();
		
-- 3. Data Standardization and consistency

	SELECT 
		DISTINCT gen,
		CASE 
			WHEN UPPER(TRIM(gen)) IN ('M','Male') 	THEN 'Male'
			WHEN UPPER(TRIM(gen)) IN ('F','Female') THEN 'Female'
			ELSE 'n/a'
		END AS gen
	FROM bronze.erp_cust_az12;
	
------------------------------------------------------------------------------------------------------

----------------
CLEANED QUERY:
----------------

TABLE : erp_cust_az12

SELECT 
CASE 
	WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
	ELSE cid 
END AS cid,
CASE 
	WHEN bdate > GETDATE() THEN NULL 
	ELSE bdate 
END AS bdate,
CASE 
		WHEN gen IN ('M','Male') 	THEN 'Male'
		WHEN gen IN ('F','Female')	THEN 'Female'
		ELSE 'n/a'
END AS gen
FROM bronze.erp_cust_az12;
	
------------------------------------------------------------------------------------------------------

---------------------------
TABLE : erp_loc_a101
---------------------------

-- 1. In order to merge it with the table 'crm_cust_info' we need to change the 'cid' to the appropriate id 
-- Also checking if there is any value unmatched or not present in the other table 

	SELECT 
		cid AS old_cid,
		TRIM(REPLACE(cid,'-','')) AS new_cid
	FROM bronze.erp_loc_a101
	WHERE 
		TRIM(REPLACE(cid,'-','')) 
	NOT IN 
		(SELECT cst_key 
		FROM bronze.crm_cust_info);

-- 2. In the 'cntry' column, some of the values are repeated, missing and abbreviated

	SELECT
		DISTINCT cntry AS old_cntry,
		CASE
			WHEN LOWER(TRIM(cntry)) IN ('usa','united states','us') THEN 'United States'
			WHEN LOWER(TRIM(cntry)) = 'de' 							THEN 'Germany'
			WHEN LOWER(TRIM(cntry)) = '' OR cntry IS NULL 			THEN 'n/a'
			ELSE TRIM(cntry)
		END AS cntry
	FROM bronze.erp_loc_a101; 
	
------------------------------------------------------------------------------------------------------

----------------
CLEANED QUERY:
----------------

	SELECT
		TRIM(REPLACE(cid,'-','')) AS cid,
		CASE
			WHEN LOWER(TRIM(cntry)) IN ('usa','united states','us') THEN 'United States'
			WHEN LOWER(TRIM(cntry)) = 'de' 							THEN 'Germany'
			WHEN LOWER(TRIM(cntry)) = '' OR cntry IS NULL 			THEN 'n/a'
			ELSE TRIM(cntry)
		END AS cntry
	FROM bronze.erp_loc_a101;
	
------------------------------------------------------------------------------------------------------

---------------------------
TABLE : erp_px_cat_g1v2
---------------------------

-- Data in this table is OK and ready to use 

----------------
CLEANED QUERY:
----------------

SELECT
	id,
	cat,
	subcat,
	maintenance
FROM bronze.erp_px_cat_g1v2;

/*
=========================================================================
FINAL QUERY - CLEANED ALTOGETHER, READY TO LOAD
=========================================================================
*/

		PRINT '==================================================';
		PRINT 'Loading CRM Tables';
		PRINT '==================================================';

		-- Loading silver.crm_cust_info

		PRINT '>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		
		PRINT '>> Inserting Data Into: silver.crm_cust_info';

		INSERT INTO silver.crm_cust_info
		(
			cst_id				         ,
			cst_key				         ,
			cst_firstname          ,
			cst_lastname		       ,
			cst_marital_status     ,
			cst_gndr			         ,
			cst_create_date
		)
		
		SELECT 
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname)	AS cst_lastname,
			CASE
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				ELSE 'n/a'
			END 
				AS cst_marital_status,
			CASE
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				ELSE 'n/a'
			END 
				AS cst_gndr,
			cst_create_date
		FROM
			(SELECT 
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) last_update 
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL) t
		WHERE last_update = 1;

    PRINT '>> -----------------------------------------------';
	
		-- Loading silver.crm_prd_info

		PRINT '>> Truncating Table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;

		PRINT '>> Inserting Data Into: silver.crm_prd_info';

		INSERT INTO silver.crm_prd_info
		(
			prd_id		  ,
			cat_id		  ,          	
			prd_key		  ,         	
			prd_nm		  ,          	
			prd_cost	  ,        	
			prd_line	  ,        
			prd_start_dt,
			prd_end_dt
		)

		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
			SUBSTRING(prd_key, 7, LEN(prd_key)) 		AS prd_key,
			prd_nm,
			COALESCE(prd_cost, 0) 						AS prd_cost,
			CASE UPPER(TRIM(prd_line))
				WHEN  'M' THEN 'Mountain'
				WHEN  'R' THEN 'Road'
				WHEN  'S' THEN 'Other Sales'
				WHEN  'T' THEN 'Touring'
				ELSE 'n/a'
			END 										AS prd_line,
			CAST(prd_start_dt AS DATE) 					AS prd_start_dt,
			CAST(LEAD(prd_start_dt) OVER 
									(PARTITION BY prd_nm 
									ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info;

		PRINT '>> -----------------------------------------------';

		-- Loading silver.crm_sales_details

		PRINT '>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;

		PRINT '>> Inserting Data Into: silver.crm_sales_details';

		INSERT INTO silver.crm_sales_details 
		(
			sls_ord_num ,
			sls_prd_key ,
			sls_cust_id ,
			sls_order_dt,
			sls_ship_dt ,
			sls_due_dt  ,
			sls_sales   ,
			sls_quantity,
			sls_price   
		)

		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE 
				WHEN LEN(sls_order_dt) != 8 
					OR	sls_order_dt = 0 
					OR sls_order_dt IS NULL 
				THEN NULL
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END AS sls_order_dt,
			CASE 
				WHEN LEN(sls_ship_dt) != 8 
					OR sls_ship_dt = 0 
					OR sls_ship_dt IS NULL 
				THEN NULL
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,
			CASE 
				WHEN LEN(sls_due_dt) != 8 
					OR sls_due_dt = 0 
					OR sls_due_dt IS NULL 
				THEN NULL
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,
			CASE 
				WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
				THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales,
			sls_quantity,
			CASE 
				WHEN sls_price IS NULL OR sls_price <= 0 
				THEN sls_sales / NULLIF(sls_quantity, 0)
				ELSE sls_price
			END AS sls_price
		FROM bronze.crm_sales_details;
		
		PRINT '>> -----------------------------------------------';

		PRINT '==================================================';
		PRINT 'Loading ERP Tables';
		PRINT '==================================================';
		
		-- Loading erp_loc_a101
		
		PRINT '>> Truncating Table: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		
		PRINT '>> Inserting Data Into: silver.erp_loc_a101';
		
		INSERT INTO silver.erp_loc_a101 (
			cid  ,
			cntry
		)
		
		SELECT
			TRIM(REPLACE(cid,'-','')) AS cid,
			CASE
				WHEN LOWER(TRIM(cntry)) IN ('usa','united states','us') THEN 'United States'
				WHEN LOWER(TRIM(cntry)) = 'de' 							THEN 'Germany'
				WHEN LOWER(TRIM(cntry)) = '' OR cntry IS NULL 			THEN 'n/a'
				ELSE TRIM(cntry)
			END AS cntry
		FROM bronze.erp_loc_a101;
		
	  PRINT '>> -----------------------------------------------';
		
		-- Loading erp_cust_az12
		
		PRINT '>> Truncating Table: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		
		PRINT '>> Inserting Data Into: silver.erp_cust_az12';
		
		INSERT INTO silver.erp_cust_az12 
		(
			cid   ,
			bdate ,
			gen   
		)
		
		SELECT 
		CASE 
			WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
			ELSE cid 
		END AS cid,
		CASE 
			WHEN bdate > GETDATE() THEN NULL 
			ELSE bdate 
		END AS bdate,
		CASE 
				WHEN gen IN ('M','Male') 	THEN 'Male'
				WHEN gen IN ('F','Female')	THEN 'Female'
				ELSE 'n/a'
		END AS gen
		FROM bronze.erp_cust_az12;
		
    PRINT '>> -----------------------------------------------';
		
		-- Loading erp_px_cat_g1v2
		
		PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		
		PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
		
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance
		)
		
		SELECT
			id          ,
			cat         ,
			subcat      ,
			maintenance
		FROM bronze.erp_px_cat_g1v2;
		
    PRINT '>> -----------------------------------------------';

		PRINT '==================================================';
		PRINT 'Loading Silver Layer is Completed';
		PRINT '==================================================';
