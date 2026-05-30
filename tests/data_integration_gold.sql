-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

-- Merging Tables:

-- 1. silver.crm_cust_info
-- 2. silver.erp_cust_az12
-- 3. silver.erp_loc_a101

	SELECT 
		t1.cst_id				,
		t1.cst_key				,
		t1.cst_firstname		,
		t1.cst_lastname			,
		t1.cst_marital_status	,
		t1.cst_gndr				,
		t1.cst_create_date		,
		t2.bdate				,
		t2.gen					,
		t3.cntry
	FROM 	  silver.crm_cust_info t1
	LEFT JOIN silver.erp_cust_az12 t2
	ON		  t1.cst_key = t2.cid
	LEFT JOIN silver.erp_loc_a101  t3
	ON		  t1.cst_key = t3.cid

-- Quality Checks

-- 1. Checking if the PRIMARY KEY has any duplicates or not

	SELECT 
		cst_id,
		COUNT(*)
	FROM
		(
			SELECT 
			t1.cst_id				,
			t1.cst_key				,
			t1.cst_firstname		,
			t1.cst_lastname			,
			t1.cst_marital_status	,
			t1.cst_gndr				,
			t1.cst_create_date		,
			t2.bdate				,
			t2.gen					,
			t3.cntry
		FROM 	  silver.crm_cust_info t1
				  silver.crm_cust_info t1
		LEFT JOIN silver.erp_cust_az12 t2
		ON		  t1.cst_key = t2.cid
		LEFT JOIN silver.erp_loc_a101  t3
		ON		  t1.cst_key = t3.cid
	) t
	GROUP BY cst_id
	HAVING COUNT(*) > 1;
	
/*
2. There are 2 columns for Gender.

- But both are different, also NULL values are present
- In some scenarios t1 has a data and t2 donot and vice versa, 
		- We can simply get the data from the opposite table 
- But we need to figure out something about the data where we have different genders for a particular customer.
		- Ask the experts here "Which is the master for these values?"
			- They told CRM is the master here 

NULL : This appeared when we joined the tables and often we get NULL whenever we're doing joins other than INNER JOIN 
*/

	SELECT 
		t1.cst_gndr ,
		t2.gen		,
		CASE
			WHEN t1.cst_gndr != 'n/a' THEN t1.cst_gndr
			ELSE COALESCE(t2.gen, 'n/a')
		END AS new_gndr
	FROM 
			  silver.crm_cust_info t1
	LEFT JOIN silver.erp_cust_az12 t2
	ON		  t1.cst_key = t2.cid
	LEFT JOIN silver.erp_loc_a101  t3
	ON		  t1.cst_key = t3.cid;
	
/*
3. We need to fix the naming conventions and use proper names so that it's more convenient to use 
	After naming we have to reorder the columns according to its relevance.
	
	We have to make sure we've a PRIMARY KEY, if not then we have to create one. 
*/

	SELECT 
		ROW_NUMBER() OVER (ORDER BY t1.cst_id) AS customer_key	,
		t1.cst_id				AS customer_id		,
		t1.cst_key				AS customer_number	,
		t1.cst_firstname		AS first_name		,
		t1.cst_lastname			AS last_name		,
		t3.cntry				AS country			,
		t1.cst_marital_status	AS marital_status	,
		CASE
			WHEN t1.cst_gndr != 'n/a' THEN t1.cst_gndr
			ELSE COALESCE(t2.gen, 'n/a')
		END						AS gender			,
		t2.bdate				AS birthdate		,
		t1.cst_create_date		AS create_date		
	FROM 	  silver.crm_cust_info t1
	LEFT JOIN silver.erp_cust_az12 t2
	ON		  t1.cst_key = t2.cid
	LEFT JOIN silver.erp_loc_a101  t3
	ON		  t1.cst_key = t3.cid


-- =============================================================================
-- FINAL QUERY - Dimension: gold.dim_customers
-- =============================================================================

-- Creating a VIEW TABLE

	CREATE VIEW gold.dim_customers 
	AS 
		SELECT 
				ROW_NUMBER() OVER (ORDER BY t1.cst_id)  AS customer_key		,
				t1.cst_id								AS customer_id		,
				t1.cst_key								AS customer_number	,
				t1.cst_firstname						AS first_name		,
				t1.cst_lastname							AS last_name		,
				t3.cntry								AS country			,
				t1.cst_marital_status					AS marital_status	,
				CASE
					WHEN t1.cst_gndr != 'n/a' 
						THEN t1.cst_gndr
					ELSE COALESCE(t2.gen, 'n/a')
				END										AS gender			,
				t2.bdate								AS birthdate		,
				t1.cst_create_date						AS create_date		
			
		FROM 
				  silver.crm_cust_info t1
		LEFT JOIN silver.erp_cust_az12 t2
		ON		  t1.cst_key = t2.cid
		LEFT JOIN silver.erp_loc_a101  t3
		ON		  t1.cst_key = t3.cid;


-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================

-- Merging Tables:

-- 1. silver.crm_prd_info
-- 2. silver.erp_px_cat_g1v2

	SELECT 
		t1.prd_id		,
		t1.cat_id		,
		t1.prd_key		,
		t1.prd_nm		,
		t1.prd_cost		,
		t1.prd_line		,
		t1.prd_start_dt	,
		t2.cat			,
		t2.subcat		,
		t2.maintenance
	FROM 		silver.crm_prd_info 	t1 
	LEFT JOIN	silver.erp_px_cat_g1v2	t2 
	ON 			t1.cat_id = t2.id 
	WHERE 		prd_end_dt IS NULL; -- Filtering out all historical data 

-- Checking uniqueness of prd_id

	SELECT 
		prd_id ,
		COUNT(*)
	FROM 
	(
		SELECT 
			t1.prd_id		,
			t1.cat_id		,
			t1.prd_key		,
			t1.prd_nm		,
			t1.prd_cost		,
			t1.prd_line		,
			t1.prd_start_dt	,
			t2.cat			,
			t2.subcat		,
			t2.maintenance
		FROM 		silver.crm_prd_info 	t1 
		LEFT JOIN	silver.erp_px_cat_g1v2	t2 
		ON 			t1.cat_id = t2.id 
		WHERE 		prd_end_dt IS NULL
	) t
	GROUP BY prd_id
	HAVING 	 COUNT(*) > 1
	
-- Sort the columns into logical groups to improve readability 

	SELECT 
		t1.prd_id		,
		t1.prd_key		,
		t1.prd_nm		,
		t1.cat_id		,
		t2.cat			,
		t2.subcat		,
		t2.maintenance	,
		t1.prd_cost		,
		t1.prd_line		,
		t1.prd_start_dt	
	FROM 		silver.crm_prd_info 	t1 
	LEFT JOIN	silver.erp_px_cat_g1v2	t2 
	ON 			t1.cat_id = t2.id 
	WHERE 		prd_end_dt IS NULL;
	
-- Giving feasible names to the columns 
-- Also adding PRIMARY KEY to the table 

	SELECT 
		ROW_NUMBER() OVER 
			(ORDER BY t1.prd_start_dt, t1.prd_key)  AS product_key	,
		t1.prd_id									AS product_id	,
		t1.prd_key									AS product_key	,
		t1.prd_nm									AS product_name	,
		t1.cat_id									AS category_id	,
		t2.cat										AS category		,
		t2.subcat									AS subcategory	,
		t2.maintenance								AS maintenance	,
		t1.prd_cost									AS cost			,
		t1.prd_line									AS product_line	,
		t1.prd_start_dt								AS start_date
	FROM 		silver.crm_prd_info 	t1 
	LEFT JOIN	silver.erp_px_cat_g1v2	t2 
	ON 			t1.cat_id = t2.id 
	WHERE 		prd_end_dt IS NULL;
	
-- =============================================================================
-- FINAL QUERY - Dimension: gold.dim_products
-- =============================================================================

	CREATE VIEW gold.dim_products 
	AS 
		SELECT 
			ROW_NUMBER() OVER 
				(ORDER BY t1.prd_start_dt, t1.prd_key)  AS product_key	,
			t1.prd_id									AS product_id	,
			t1.prd_key									AS product_key	,
			t1.prd_nm									AS product_name	,
			t1.cat_id									AS category_id	,
			t2.cat										AS category		,
			t2.subcat									AS subcategory	,
			t2.maintenance								AS maintenance	,
			t1.prd_cost									AS cost			,
			t1.prd_line									AS product_line	,
			t1.prd_start_dt								AS start_date
		FROM 		silver.crm_prd_info 	t1 
		LEFT JOIN	silver.erp_px_cat_g1v2	t2 
		ON 			t1.cat_id = t2.id 
		WHERE 		prd_end_dt IS NULL;
		
-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================
/*
Use the dimensions surrogate keys instead of IDs to easily connect facts with dimensions 
*/

	CREATE VIEW gold.fact_sales AS
		SELECT
			t1.sls_ord_num  AS order_number	,
			t2.product_key  AS product_key	, -- Surrogate Keys 
			t3.customer_key AS customer_key	, -- Surrogate Keys 
			t1.sls_order_dt AS order_date	,
			t1.sls_ship_dt  AS shipping_date,
			t1.sls_due_dt   AS due_date		,
			t1.sls_sales    AS sales_amount	,
			t1.sls_quantity AS quantity		,
			t1.sls_price    AS price
		FROM 		silver.crm_sales_details 			t1
		LEFT JOIN 	gold.dim_products 					t2
			ON 		t1.sls_prd_key = t2.product_number
		LEFT JOIN 	gold.dim_customers 					t3
			ON 		t1.sls_cust_id = t3.customer_id;
			
			
-- =============================================================================
-- COMPLETED
-- =============================================================================

-- After completion - Foreign Key Integrity (Dimensions)
-- Checking with dim_customers table 

SELECT 
	*
FROM 		gold.fact_sales		t1
LEFT JOIN	gold.dim_customers	t2
ON 			t1.customer_key = t2.customer_key
WHERE 		t2.customer_key IS NULL ;

-- Also checking with dim_products table 

SELECT 
	*
FROM 		gold.fact_sales		t1
LEFT JOIN	gold.dim_customers	t2
ON 			t1.customer_key = t2.customer_key
LEFT JOIN 	gold.dim_products	t3
ON 			t1.product_key = t3.product_key
WHERE 		t3.product_key IS NULL ;
