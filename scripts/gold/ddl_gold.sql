/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

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
		ON		  t1.cst_key = t3.cid	;
GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products 
	AS 
		SELECT 
			ROW_NUMBER() OVER 
				(ORDER BY t1.prd_start_dt, t1.prd_key)  AS product_key		,
			t1.prd_id									AS product_id		,
			t1.prd_key									AS product_number	,
			t1.prd_nm									AS product_name		,
			t1.cat_id									AS category_id		,
			t2.cat										AS category			,
			t2.subcat									AS subcategory		,
			t2.maintenance								AS maintenance		,
			t1.prd_cost									AS cost				,
			t1.prd_line									AS product_line		,
			t1.prd_start_dt								AS start_date	
		FROM 		silver.crm_prd_info 	t1 
		LEFT JOIN	silver.erp_px_cat_g1v2	t2 
		ON 			t1.cat_id = t2.id 
		WHERE 		prd_end_dt IS NULL		;
GO	

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

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
			ON 		t1.sls_cust_id = t3.customer_id		;
GO
