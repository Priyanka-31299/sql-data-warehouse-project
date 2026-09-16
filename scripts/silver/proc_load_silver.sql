/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/
create or alter procedure silver.load_silver as 
begin
	Declare @start_time datetime, @end_time datetime, @batch_start_time datetime, @batch_end_time datetime;
	begin try
		set @batch_start_time = getdate();
		print '>> Executing the stored procedures';
		print '============================================';
		print 'Loading silver layer';
		print '============================================';
		print '---------------------------------------------';
		print 'Loading crm tables'
		print '---------------------------------------------';

		-- loading silver.crm_cust_info
		set @start_time = getdate();
		print '>>truncating table: silver.crm_cust_info';
		truncate table silver.crm_cust_info;
		Print '>>inserting data into:silver.crm_cust_info';

		insert into silver.crm_cust_info
		(	cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
		)

		select 
			cst_id,
			cst_key,
			TRIM(cst_firstname) as cst_firstname,
			trim(cst_lastname) as cst_last_name,
			case when  upper(trim(cst_material_status))= 'S' then 'Single'
			  when UPPER(trim(cst_material_status))= 'M' then 'Married'
				else 'n/a'
			end cst_marital_status,
			case when upper(trim(cst_gndr)) = 'M' then 'Male'
				when upper(trim(cst_gndr)) ='F' then 'Female'
			  else 'n/a'
			end cst_gndr,
			cst_create_date
			from
		(
		select * ,
		row_number() over(partition by cst_id	order by cst_create_date desc) as flag_last
		from bronze.crm_cust_info
		)t
		where flag_last =1 ;
		set @end_time = getdate();
		print '>> load duration :'+ cast(datediff(second,@start_time, @end_time) as nvarchar)+ 'seconds';
		print '>>----------------';

		-- loading silver.crm_prd_info
		set @start_time = getdate();
		print '>>truncating table: silver.crm_prd_info	';
		truncate table silver.crm_prd_info;
		Print '>>inserting data into:silver.crm_prd_info';

		insert into Silver.crm_prd_info	
		(
			prd_id  ,
			cat_id   ,
			prd_key  ,
			prd_nm   ,
			prd_cost ,
			prd_line  ,
			prd_start_dt ,
			prd_end_dt  
		)
		select 
			prd_id,
			replace(SUBSTRING(prd_key,1,5),'-','_') cat_id,
			substring(prd_key,7,len(prd_key)) prd_key,
			prd_nm,
			isnull(prd_cost,0) prd_cost,
			case  upper(trim(prd_line)) 
				when 'M' then 'Mountain'
				when 'R' then 'Road'
				when 'S' then 'Other sales'
				when 'T' then 'Touring'
				Else 'n/a'
			end prd_line,
			cast(prd_start_dt as date) as prd_start_dt,
			cast(lead(prd_start_dt) over(partition by prd_key order by prd_start_dt)-1 as date) as prd_end_dt
		from bronze.crm_prd_info;
		set @end_time = getdate();
		print '>> load duration:' + cast(datediff(second, @start_time, @end_time) as nvarchar) +'Seconds';
		print '--------------------------------------';

		
		-- loading silver.crm_sales_details
		set @start_time = getdate();
		print '>>truncating table: silver.crm_sales_details	';
		truncate table silver.crm_sales_details;
		Print '>>inserting data into:silver.crm_sales_details';

		insert into Silver.crm_sales_details
		(	
			sls_ord_num ,
			sls_prd_key ,
			sls_cust_id ,
			sls_order_dt ,
			sls_ship_dt  ,
			sls_due_dt  ,
			sls_sales   ,
			sls_quantity ,
			sls_price 
		)
		SELECT 
      sls_ord_num
			,sls_prd_key
			,sls_cust_id,
			case 
				when sls_order_dt = 0 or len(sls_order_dt) !=8  then NULL
				else cast(CAST(sls_order_dt as varchar) as date) 
			 end sls_order_dt
			,case 
				when sls_ship_dt = 0 or len(sls_ship_dt) !=8  then NULL
				else cast(CAST(sls_ship_dt as varchar) as date) 
			 end sls_ship_dt
			,case 
				when sls_due_dt = 0 or len(sls_due_dt) !=8  then NULL
				else cast(CAST(sls_due_dt as varchar) as date) 
			 end sls_due_dt
			,case 
        when sls_sales != sls_price* sls_quantity or sls_sales<=0 or sls_sales is null then sls_quantity*abs(sls_price)
			  else sls_sales
			end sls_sales
			,sls_quantity
			,case 
        when sls_price is null or sls_price <=0 
				then sls_sales/nullif(sls_quantity,0)
				else sls_price
			end sls_price
		FROM bronze.crm_sales_details;
		set @end_time = Getdate();
		print '>>load duration ;' +cast(datediff(second,@start_time, @end_time) as nvarchar) +'seconds';
		print '---------------------------------------';

		-- loading silver.erp_cust_az12
		set @start_time = getdate();
		print '>>truncating table: silver.erp_cust_az12	';
		truncate table silver.erp_cust_az12;
		Print '>>inserting data into:silver.erp_cust_az12';

		Insert into silver.erp_cust_az12
			(cid, bdate,gen)
		select
			case when cid like 'NAS%' then substring(cid,4,len(cid))
				else cid
			end cid,
			case
				when bdate> GETDATE() then null
				else bdate
			end bdate,
			case when upper(trim(gen)) ='F' or gen = 'Female' then 'Female'
				when upper(trim(gen))='M' or gen = 'Male' then 'Male'
				else 'n/a'
			end gen
		from bronze.erp_cust_az12;
		set @end_time = getdate();
		print '>>load duration:' +cast(datediff(second, @start_time, @end_time) as nvarchar) +'seconds';
		print '---------------------------------';

		
		-- loading   Silver.erp_loc_a101
		set @start_time = Getdate();
		print '>>truncating table:  Silver.erp_loc_a101	';
		truncate table Silver.erp_loc_a101;
		Print '>>inserting data into: Silver.erp_loc_a101';

		insert into Silver.erp_loc_a101
			(cid,cntry)
			select 
				REPLACE(cid,'-','') cid, 
				case when trim(cntry) in ('DE','Germany') then 'Germany'
					when trim(cntry) in ('USA','United States','US') then 'United states of America'
					when trim(cntry) is null or cntry ='' then null
					else cntry
				end cntry
			from bronze.erp_loc_a101;
		set @end_time = getdate();
		print '>>load duration:' +cast(datediff(second, @start_time, @end_time) as nvarchar) +'seconds';
		print '---------------------------------';
		  
		--loading Silver.erp_px_cat_g1v2
		set @start_time = getdate();
		print '>>truncating table: Silver.erp_px_cat_g1v2	';
		truncate table Silver.erp_px_cat_g1v2;
		Print '>>inserting data into: Silver.erp_px_cat_g1v2';

		insert into Silver.erp_px_cat_g1v2 (
			id,
			cat, 
			subcat,
			maintenance)
		select id,
			cat, 
			subcat,
			maintenance
			from bronze.erp_px_cat_g1v2;
		set @end_time = getdate();
		print '>>load duration:' +cast(datediff(second, @start_time, @end_time) as nvarchar) +'seconds';
		print '---------------------------------';

		set @batch_end_time = getdate();
		print '================================';
		print 'Loading silver layer is completed';
		print '-Total duration:' +cast(datediff(second,@batch_start_time,@batch_end_time) as nvarchar) +'Seconds';
		print '================================';

	end try
	begin catch 
		print '=====================================';
		print 'Error occured during loading silver layer';
		print 'error_message:' + Error_message();
		print 'Error Message:' +Cast(error_number() as nvarchar);
		print 'Error message:' + cast(error_state() as nvarchar);
		print '=====================================';
	end catch
End
