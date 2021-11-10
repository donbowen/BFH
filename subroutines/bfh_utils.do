	
	cap prog drop table_set_up
	prog define table_set_up

		keep if year >= $start_yr
		
		cap	g first_year = year(dofq(first_qtr))
			
		// table specific set up (orthoganolized versions)	
			g sim_foreign_m_priv_stock = sim_foreign_stock    - sim_priv_stock 
			g sim_li_m_priv_stock        = sim_li_stock - sim_priv_stock 
		
		// better labels
			lab var t_q1_to_q1_b_ipo               "IPO"
			lab var t_q1_to_q1_b_acq               "Acquired"
   			lab var sim_li_m_priv_stock            "LI Similarity (orth)"
   			lab var sim_foreign_m_priv_stock       "Foreign Similarity (orth)"		
		
		// standardize RHS vars that are NOT dummy vars	
			global vars_to_std /*
			*/ l_pats_last_20qtr L2_l_mtb1 pastMTKreturn_asdeci    adj_originality_nber_stock l_cite_stock l_cum_VC_fund /* base minus dummies
			*/ $x_bfh_regs retech_estab_stock retech_new_stock   /*  bfh regs
			*/ sim_li_stock sim_foreign_stock  /* maybe we'll need the UNoorthog vars sometime 
			*/ myVCsMktshare  scope_stock   num_claims_stock 
			global std_note = "VARIABLES STANDARDIZED: "
			qui foreach v in $vars_to_std {
				cap sum `v'
				// this check is here so this works even if a var is missing (e.g. the annual smaple doesnt have l_pats_20qtrs)
				if _rc == 0 {
				sum `v' 
				replace `v' = `v' / `r(sd)'
				global std_note = "$std_note `v'"
				}
			}
			
		// set up for COMPETING RISK HAZARD MODELS	
		
			g failtype1 = b_ipo + 2*b_lbo + 3*b_active + 4*b_acq + 5*b_fail
			cap xtset vxfirm_id qtr
			if _rc == 111 {
				xtset vxfirm_id year // this check allows this code to work on a robustness test on an annual sample
			}
			replace failtype1 = f1.failtype1 // so that hazard models have y(t+1)=f(X(t))
			cap rename firm_age_qtr firm_age
			if _rc == 111 {
				rename firm_age_year firm_age // this check allows this code to work on a robustness test on an annual sample
			}					
					
			g firm_age1 = firm_age+1 		
				* stset thinks of time as "time since risk exposure began" 
				* so rather than firm_age=0 in the first year of a firm (which stset will IGNORE in tests!)
				* set the first year of a firm to 1, as in "the firm has been at risk of an IPO for a year"
				* it's like saying these are end of year observations	
					
	end
	
********************************************************************************

	cap prog drop postreg_add
	prog define postreg_add
	    * convenience: add a bunch of FE notes at once 
		foreach FE in `0' {
			estadd local `FE'   = "Yes"
		}
	end

********************************************************************************
	
	cap prog drop rescale_y_prepost_OLS
	prog define rescale_y_prepost_OLS	
		* use this before OLS tests so betas have percentage point interps
		* use this after OLS tests bc logit/haz/etc need binary y vars
		* argument needed: do you want them scaled to 1 or 100
		* ex: rescale_y_prepost_OLS 1
		* ex: rescale_y_prepost_OLS 100
		
		foreach v of varlist t_* {
			qui sum `v'
			if `r(max)' == 1 & `1' == 100 {
				replace `v' = `v' * 100
			}
			if `r(max)' == 100 & `1' == 1 {
				replace `v' = `v' / 100
			}			
		}
	end			
	
********************************************************************************	
	
	cap prog drop prep_for_ts_plot
	prog def prep_for_ts_plot 
	/* give it a list of variables that you want to turn into a time series for 
	ploting, and it will return a TS with qtr, year, # pats that qtr, # patents on 
	prior 5 years, and the stocked amounts for the variables provided to the fcn  */
		
		collapse (sum) `0' (count) pnum_qtr = pnum , by(aqtr)
		g year = floor(aqtr/4)+1960

		// create stocks
		

		tsset aqtr
		tsfill // so that gaps get running stocks

		global d = .95 // =(1-depreciation) --> depreciation = .05 PER QUARTER
			
		foreach v of varlist pnum_qtr `0' {
			// copy lagged values into a given row and set non-existant to 0 (so they can be summed)
			forval lag = 0/19 {
				g `v'_`lag' = L`lag'.`v'
				replace `v'_`lag' = 0 if `v'_`lag' == .
			}
		*	drop `v'
			
			cap egen running_pnum = rowtotal(pnum_qtr_*) // raw count, not depreciated
			
			g `v'_stock = `v'_0		
			drop `v'_0
			forval i = 1/19 {
				replace `v'_stock = `v'_stock + `v'_`i' * ($d)^`i'
				drop `v'_`i'
			}
			replace `v'_stock = `v'_stock / running_pnum		
			replace `v'_stock = 0 if running_pnum == 0		
			lab var `v'_stock "`v' stock: [t-19,t] (5% qtly depr)"
		}	
			
		// drop all of the flow versions of the variables
		
		drop `0'
		
		// smooth series and prep for plotting
		
		tsset aqtr
		foreach v of varlist `0'  {
			tssmooth ma `v'_smooth = `v', window(4) replace
		}	
		drop *_stock // drop the non-smoothed versions
		format aqtr %tq
		rename *_stock_smooth * // shorten names, otherwise twoways's name option will freak out 
	end
