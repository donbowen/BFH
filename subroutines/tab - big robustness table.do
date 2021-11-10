* subroutines/make_AnnualStartupPanel.do --> 
		
	//  load panel data and bring in all the parts
			
		use data/startup_qtr_panel, clear
		table_set_up	
		rescale_y_prepost_OLS 100 // y={0,100} for OLS		
		
		// bank financing as a control
		
		merge m:1 vxfirm_id using data/auxilliary/bankfinancing_firstdealdate, nogen keep(1 3)
		g bankdebt = qtr >= bank_fin_onAndAfter
		*order vxfirm_id qtr bank_fin_onAndAfter bankdebt // check... good
		drop bank_fin_onAndAfter
		lab var bankdebt "Existing Bank Debt"

		// different aggregations of RETech
		
		merge 1:1 vxfirm_id qtr using "temp/diff_agg_panel", keep(1 3) nogen
				
	// on to the show...
	
		eststo clear
		
		local X $x_bfh_regs $x_base
		local FE year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor
		local vce vce(cluster vxfirm_id)
	
	// Change SE clustering	
	
		foreach cluster in nber_vx_cat year first_year {
			local othernote "Clu-`cluster'"
			
			stset firm_age1, id(vxfirm_id)          failure(failtype1 == 1) 			
				eststo, title("IPO"): stcrreg  `X', compete(failtype1 = 4 5) vce(cluster `cluster')
				estadd local model = "Haz"
				estadd local other = "`othernote'"
		
			stset firm_age1, id(vxfirm_id)           failure(failtype1==4) 	
				eststo, title("Acq"): stcrreg  `X' , compete(failtype1 = 1 5) vce(cluster `cluster') 
				estadd local model = "Haz"
				estadd local other = "`othernote'"

			eststo: reghdfe  t_q1_to_q1_b_ipo `X', a(`FE') vce(cluster `cluster')  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"
		
			eststo: reghdfe  t_q1_to_q1_b_acq `X', a(`FE') vce(cluster `cluster')  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"
}
		
	// Next set of robustness	- no cites in X
	{
		local X = subinstr("$x_bfh_regs $x_base","l_cite_stock","",.)
		local othernote "No Cite"

		stset firm_age1, id(vxfirm_id)          failure(failtype1 == 1) 			
			eststo, title("IPO"): stcrreg  `X', compete(failtype1 = 4 5) `vce'
			estadd local model = "Haz"
			estadd local other = "`othernote'"
	
		stset firm_age1, id(vxfirm_id)           failure(failtype1==4) 	
			eststo, title("Acq"): stcrreg  `X' , compete(failtype1 = 1 5) `vce' 
			estadd local model = "Haz"
			estadd local other = "`othernote'"

		eststo: reghdfe  t_q1_to_q1_b_ipo `X', a(`FE') `vce'  noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	
		eststo: reghdfe  t_q1_to_q1_b_acq `X', a(`FE') `vce'  noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	}
	// Next set of robustness	- simple X	
	{
		local X noPatsLast5 retech_stock l_pats_last_20qtr
		local othernote "RETech+PatCount"

		stset firm_age1, id(vxfirm_id)          failure(failtype1 == 1) 			
			eststo, title("IPO"): stcrreg  `X', compete(failtype1 = 4 5) `vce'
			estadd local model = "Haz"
			estadd local other = "`othernote'"
	
		stset firm_age1, id(vxfirm_id)           failure(failtype1==4) 	
			eststo, title("Acq"): stcrreg  `X' , compete(failtype1 = 1 5) `vce' 
			estadd local model = "Haz"
			estadd local other = "`othernote'"

		eststo: reghdfe  t_q1_to_q1_b_ipo `X', a(`FE') `vce'  noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	
		eststo: reghdfe  t_q1_to_q1_b_acq `X', a(`FE') `vce'  noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	}
	// Next set of robustness - VC fixed effect
	{
		local X $x_bfh_regs $x_base  
		local othernote "VCfe"

		eststo: reghdfe  t_q1_to_q1_b_ipo `X', a(i.latestLead_vc_index `FE') `vce'  noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE  VCFE
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	
		eststo: reghdfe  t_q1_to_q1_b_acq `X', a(i.latestLead_vc_index `FE') `vce'  noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE  VCFE
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	}
	// Add generality and bankdebt
	{
		local X $x_bfh_regs $x_base  adj_generality_2017PView_stock bankdebt
		local othernote "Gen+Bank"

		stset firm_age1, id(vxfirm_id)          failure(failtype1 == 1) 			
			eststo, title("IPO"): stcrreg  `X', compete(failtype1 = 4 5) `vce'
			estadd local model = "Haz"
			estadd local other = "`othernote'"
	
		stset firm_age1, id(vxfirm_id)           failure(failtype1==4) 	
			eststo, title("Acq"): stcrreg  `X' , compete(failtype1 = 1 5) `vce' 
			estadd local model = "Haz"
			estadd local other = "`othernote'"

		eststo: reghdfe  t_q1_to_q1_b_ipo `X', a(`FE') `vce'  noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE  
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	
		eststo: reghdfe  t_q1_to_q1_b_acq `X', a(`FE') `vce'  noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE  
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"	
	}	
	// Next set of robustness	- different aggregations	
	
		local X = subinstr("$x_bfh_regs $x_base","retech_stock","",.)
		foreach func in mean max {
		foreach win in 4 8 12 16 20 {
			local ret retech_`func'_roll`win'
			local othernote "`func' RET over `win' qtr "

			stset firm_age1, id(vxfirm_id)          failure(failtype1 == 1) 			
				eststo, title("IPO"): stcrreg  `ret' `X', compete(failtype1 = 4 5) `vce'
				estadd local model = "Haz"
				estadd local other = "`othernote'"
		
			stset firm_age1, id(vxfirm_id)           failure(failtype1==4) 	
				eststo, title("Acq"): stcrreg  `ret' `X' , compete(failtype1 = 1 5) `vce' 
				estadd local model = "Haz"
				estadd local other = "`othernote'"

			eststo: reghdfe  t_q1_to_q1_b_ipo  `ret' `X', a(`FE') `vce'  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"
		
			eststo: reghdfe  t_q1_to_q1_b_acq  `ret' `X', a(`FE') `vce'  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"	
		}
		}	
	// subsamples	
	
		use data/startup_qtr_panel, clear
		table_set_up	
		rescale_y_prepost_OLS 100 // y={0,100} for OLS	
		
		local X $x_bfh_regs $x_base
		local FE year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor
		local vce vce(cluster vxfirm_id)
	
		foreach if in "if year < 1996" "if year >= 1996" {
			local othernote "`if'"
			
			stset firm_age1, id(vxfirm_id)          failure(failtype1 == 1) 			
				eststo, title("IPO"): stcrreg  `X' `if', compete(failtype1 = 4 5) `vce'
				estadd local model = "Haz"
				estadd local other = "`othernote'"
		
			stset firm_age1, id(vxfirm_id)           failure(failtype1==4) 	
				eststo, title("Acq"): stcrreg  `X' `if', compete(failtype1 = 1 5) `vce' 
				estadd local model = "Haz"
				estadd local other = "`othernote'"

			eststo: reghdfe  t_q1_to_q1_b_ipo `X' `if', a(`FE') `vce'  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"
		
			eststo: reghdfe  t_q1_to_q1_b_acq `X' `if', a(`FE') `vce' noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"
		}
	
	// Recode low value sell-outs as liquidation (failures)
	{
		// this will do it
		
			cap prog drop newSelloutDefinition_switch
			prog define newSelloutDefinition_switch
			* argument `1' = small_sellout, or finbuyer

				local nonLquidationThreshold = 25

				// "vxfirm_id small_sellout.dta" are the small price sell outs deflated to 2009 USD
				
				merge m:1 vxfirm_id using "data/auxilliary/vxfirm_id small_sellout", keep(1 3) nogen
				
				// "finbuyer.dta" are vxfirm_id of startups acq'ed by financial buyers
								
				merge m:1 vxfirm_id using "data/auxilliary/vxfirm_id finbuyer", keep(1 3) 
				g finbuyer=_m == 3	
												
replace b_fail = 1 if b_acq == 1 & (`1' == 1 ) 
replace b_acq = 0 if b_acq == 1 &  (`1' == 1 )
				
				// remake the t_q1_qK variables
				
		cap 	drop t_q1_to_q*_b_acq
		cap		drop t_q1_to_q*_b_fail
				
				xtset vxfirm_id qtr
				
				qui foreach v of varlist b_acq b_fail {
					forval forward = 1/20 {
						g temp_`v'_`forward' = F`forward'.`v'
					}
					egen t_q1_to_q1_`v'  = rowtotal( temp_`v'_1), missing
					
					foreach end in 4 8 12 16 20 {		
						egen t_q1_to_q`end'_`v'  = rowtotal( temp_`v'_1 - temp_`v'_`end'), missing
					}	
					foreach end in 1 4 8 12 16 20 {					
						lab var t_q1_to_q`end'_`v' "`v'[t+1,t+`end']=1"
					}
					drop temp_`v'_*
				}	
				count if t_q1_to_q1_b_ipo != F1.b_ipo
				
			end	
		
		// now use that for small sellouts
		
			use data/startup_qtr_panel, clear
			table_set_up	
			
			qui newSelloutDefinition_switch small_sellout //, or finbuyer		
			
			drop failtype1 // we have to pass the new def to this to use Haz
			g failtype1 = b_ipo + 2*b_lbo + 3*b_active + 4*b_acq + 5*b_fail
			xtset vxfirm_id qtr
			replace failtype1 = f1.failtype1

			rescale_y_prepost_OLS 100 // y={0,100} for OLS		

			local X $x_bfh_regs $x_base
			local othernote "recode small sellout"
			local vce vce(cluster vxfirm_id)
			local FE year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor
		
			stset firm_age1 ,             id(vxfirm_id) failure(failtype1==1) 			
			eststo, title("IPO"):     stcrreg  `X',  compete(failtype1 = 4 5) `vce'
				estadd local model = "Haz"
				estadd local other = "`othernote'"
		
			stset firm_age1, id(vxfirm_id)           failure(failtype1==4) 	
				eststo, title("Acq"): stcrreg  `X' , compete(failtype1 = 1 5) `vce' 
				estadd local model = "Haz"
				estadd local other = "`othernote'"
		
			eststo: reghdfe  t_q1_to_q1_b_ipo `X', a(`FE') `vce'  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"	
		
			eststo: reghdfe  t_q1_to_q1_b_acq `X', a(`FE') `vce'  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"	
				
		// now use that for finbuyer
		
			use data/startup_qtr_panel, clear
			table_set_up	
			
			qui newSelloutDefinition_switch finbuyer //, or finbuyer		
			
			drop failtype1 // we have to pass the new def to this to use Haz
			g failtype1 = b_ipo + 2*b_lbo + 3*b_active + 4*b_acq + 5*b_fail
			xtset vxfirm_id qtr
			replace failtype1 = f1.failtype1

			rescale_y_prepost_OLS 100 // y={0,100} for OLS		
				
			local X $x_bfh_regs $x_base
			local othernote "recode finbuyer"
			local vce vce(cluster vxfirm_id)
			local FE year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor
		
			stset firm_age1 ,             id(vxfirm_id) failure(failtype1==1) 			
			eststo, title("IPO"):     stcrreg  `X',  compete(failtype1 = 4 5) `vce'
				estadd local model = "Haz"
				estadd local other = "`othernote'"
		
			stset firm_age1, id(vxfirm_id)           failure(failtype1==4) 	
				eststo, title("Acq"): stcrreg  `X' , compete(failtype1 = 1 5) `vce' 
				estadd local model = "Haz"
				estadd local other = "`othernote'"
		
			eststo: reghdfe  t_q1_to_q1_b_ipo `X', a(`FE') `vce'  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"	
		
			eststo: reghdfe  t_q1_to_q1_b_acq `X', a(`FE') `vce'  noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
				estadd local model = "OLS"
				estadd local other = "`othernote'"	
					
	}
	// year X industry FE
	
		use data/startup_qtr_panel, clear
		table_set_up	
		rescale_y_prepost_OLS 100 // y={0,100} for OLS		
	
		encode vxindgrpmajor, g(i_vxindgrpmajor) // can't interact with string var
	
		local X $x_bfh_regs $x_base
		local FE year#i_vxindgrpmajor firm_age first_year i.state_FE nber_vx_cat 
		local vce vce(cluster vxfirm_id)
		local othernote "yearXindFE"
		
		reghdfe  t_q1_to_q1_b_acq `X', a(`FE') `vce' noconst 
	
		eststo: reghdfe  t_q1_to_q1_b_ipo `X', a(`FE') `vce' noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	
		eststo: reghdfe  t_q1_to_q1_b_acq `X', a(`FE') `vce' noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
			estadd local model = "OLS"
			estadd local other = "`othernote'"
	
	
	// output 

		local n1  "QUARTERLY sample: 1980-2010" 
		local n2  "Statistical issues: " 
		local n3  "   -Std errors clustered by firm (EXCEPT model 5 - by qtr)" 
		local n4  "   -R2 (in PERCENT) is psuedo for logit model and adjusted for OLS models" 
		local n5  "Interpretation issues: " 
		local n6  "   -Logit coefficients are relative change in probability for 1 unit increase" 
		local n7  "    ie the log odd coefficients ``beta'' are transformed: exp(beta)-1"         
		local n8  "   -OLS coefficients are % change for 1 unit increase (ie outcome={0,100})" 
		local n9  "   -Dummy variables: NoPatsLast5 Q4 cum_VC_fund_zero" 
		local n9a "   -LI Similarity and Foreign Similarity are orthoganal to Peer Similarity" 
		local n10 "   -$std_note" 		
	
		local opts compress b(3) star(* .10 ** .05 *** .01 ) nonotes label /*
					*/ title("Predicting Next Period Firm Exits")  /*
					*/ stats(N myr2 YearFE AgeFE CohortFE CatFE StateFE IndFE VCFE model other, fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" "AgeFE" "CohortFE" "TechCatFE" "StateFE" "VXIndFE" "VCFE" "model" "other")) 					

		esttab_to_excel_sheet using "$output_excel",  ///
			sheet_name("Exits-BigRobustness") temp_csv("temp12345.csv") ///
			esttab_options( `opts' ) ///
			notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n6'" "`n7'" "`n8'" "`n9'" "`n9a'" "`n10'" "')
	
	
	
