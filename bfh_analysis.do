/* 

REPLICATION KIT FOR "Rapidly Evolving Technologies and Startup Exits", 
MANAGEMENT SCIENCE, FORTHCOMING

Authors: Donald Bowen, Gerard Hoberg, and Laurent Fresard
Date:    27-10-2021

To run this, you need the two key dta files inside the data folder plus some 
auxilliary files therein and the xlsx file inside the output folder (which will 
store the table results and format them automatically). 

Some stata packages are needed:

*/

	cd // put the path to this folder if needed
	
	di "Is the cd set to the directory of this repo? If so,"
	di "delete the next line of code and run the rest as you please."
	
	stop //

	ssc install heatplot           // delete this line after install
	ssc install palettes, replace  // delete this line after install
	ssc install colrspace, replace // delete this line after install	
	ssc install gtools             // delete this line after install
	ssc install ftools             // delete this line after install
	ssc install reghdfe            // delete this line after install
	ssc install rangestat          // delete this line after install
	ssc install distinct           // delete this line after install
	
********************************************************************************
*
*	Presets
*
********************************************************************************

	clear all
	macro drop _all
	set rmsg on, perm
	set more off, perm
	set scrollbufsize 100000
	set matsize 800

	* key folders (I/O/temp)
	
	cap mkdir "temp/"
		
	global output_excel         "output/bfh-tables.xlsx"
			
	* analysis params

	global start_yr      = 1980	
	
	* control vars:	
	global x_base              noPatsLast5yrs l_pats_last_20qtr L2_l_mtb1 pastMTKreturn_asdeci l_cite_stock /*
					           */ q4 adj_originality_nber_stock l_cum_VC_fund cum_VC_fund_zero myVCsMktshare /*
						       */ scope_stock num_claims_stock
								
	* text based vars, unaltered vars for sum stat tables
	global x_bfh               retech_stock                         tech_breadth_stock sim_priv_stock sim_li_stock sim_foreign_stock 	 
	
	* for regs, due to multi col, we orthog the distance vars 
	global x_bfh_regs          retech_stock                         tech_breadth_stock sim_priv_stock sim_li_m_priv_stock sim_foreign_m_priv_stock  
	global x_bfh_regs_decomp   retech_estab_stock retech_new_stock  tech_breadth_stock sim_priv_stock sim_li_m_priv_stock sim_foreign_m_priv_stock 
	
********************************************************************************
* load utility functions
********************************************************************************
	
	qui do "subroutines/FCN_esttab_to_excel_sheet_v2.do"
	qui do "subroutines/bfh_utils.do"
	qui do "subroutines/FCN_winsorby" 
	
********************************************************************************
* download larger data files that aren't in the repo by default
********************************************************************************
		
	local url1 "https://github.com/donbowen/BFH/releases/download/v2017/RETech_fixedDelta_1960.zip"
	local url2 "https://github.com/donbowen/BFH/releases/download/v2017/pat_lv_dta.zip"
	
	* only download if you don't already have them
	
	cap confirm file "data/auxilliary/RETech_fixedDelta_1960.dta"
	if _rc {
		copy "`url1'" "data/auxilliary/RETech_fixedDelta_1960.zip"
		
		cd data/auxilliary
		unzipfile RETech_fixedDelta_1960.zip, replace 
		cap erase RETech_fixedDelta_1960.zip
		cd ../../
		
	}

	cap confirm file "data/pat_lv.dta" 
	if _rc {
		copy "`url2'" "data/pat_lv.zip"
		
		cd data
		unzipfile pat_lv.zip, replace 
		cap erase pat_lv.zip
		cd ../
		
	}	
		
			
********************************************************************************
* PAT LEVEL TABLES
*
* 	table 2 - summary stats in pat lv 
*   table 3 - pat level corr
* 	table 4 - pat level regs (subs/comp)
*
********************************************************************************

	////////////////////////////////
	// table 2 - summary stats in pat lv
	////////////////////////////////	
	{	
		use data/pat_lv, clear				
		keep if ayear >= 1930 & ayear <= 2010
		
		eststo clear		
		qui estpost tabstat retech tech_breadth sim_priv sim_li sim_foreign  /*
			*/ adj_originality_nber cite scope num_claims xi subs comp  /*
			*/ retech_new retech_estab, s(n mean sd p25 p50 p75) c(s) 
		esttab_to_excel_sheet using "$output_excel", temp_csv("temp12345.csv") ///
			sheet_name("PatLvSummStats") ///
			esttab_options( cells("count(fmt(%9.0fc)) mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f))") noobs nonumber label ) ///	
			notes(`""Patent level" "All vars winsorized at 1% (annual)" "SAMPLE: ayear =[1930,2010]"  "')		
	}			
	////////////////////////////////
	// table 3 - patent level corr
	////////////////////////////////
	{	
		use data/pat_lv, clear				
		keep if ayear >= 1930 & ayear <= 2010
		
		eststo clear		
		qui estpost correlate retech  tech_breadth sim_priv sim_li  sim_foreign adj_originality_nber  /*
			*/ l_cite l_xi subs comp scope num_claims, matrix listwise	
		esttab_to_excel_sheet using "$output_excel", temp_csv("temp12345.csv") ///
			sheet_name("PatLvCorr-Summ") esttab_options( unstack not noobs compress b(%9.2f) label nostar ) ///	
			notes(`""Patent level" "All vars winsorized at 1% (annual)" "SAMPLE: ayear =[1930,2010]" "')
	}					
	////////////////////////////////
	// table 4 - pat level regs (subs/comp)		
	////////////////////////////////
	{	
		use data/pat_lv, clear
		keep if ayear >= 1930 & ayear <= 2000
		eststo clear
		
		* scale vars
		
		replace subs = subs*100
		replace comp = comp*100

		local std_note = "VARIABLES STANDARDIZED: "
		qui foreach v in retech  tech_breadth sim_li sim_priv sim_foreign {
			sum `v'
			replace `v' = `v' / `r(sd)'
			local std_note = "`std_note' `v'"
		}
					
		eststo, title("Subs"): reghdfe subs retech    , absorb(gyear nber bfhcode) cluster(gyear) nocons
				postreg_add YearFE CatFE bfhcodeFE
				estadd scalar myr2 = 100*e(r2_a)
		eststo, title("Comp"): reghdfe comp   retech  , absorb(gyear nber bfhcode) cluster(gyear) nocons
				postreg_add YearFE CatFE bfhcodeFE
				estadd scalar myr2 = 100*e(r2_a)
		eststo, title("Subs"): reghdfe subs retech    , absorb(nber#gyear bfhcode) cluster(gyear) nocons
				postreg_add YearCatFE bfhcodeFE
				estadd scalar myr2 = 100*e(r2_a)
		eststo, title("Comp"): reghdfe comp   retech  , absorb(nber#gyear bfhcode) cluster(gyear) nocons
				postreg_add YearCatFE bfhcodeFE
				estadd scalar myr2 = 100*e(r2_a)
				
		local n1  "PATENT LEVEL sample: apps from 1930-2000" 
		local n2  "Statistical issues: " 
		local n3  "   -Std errors clustered by grant year" 
		local n4  "   -R2 (in PERCENT) is adjusted R2" 
		local n6  "Interpretation issues: " 
		local n8  "   -y variables are %age of follow on cites that indicate focal pat is" 
		local n9  "    complementary or substituting for focal pat's predecessors" 
		local n10 "   -`std_note'" 		
		local opts compress b(3) star(* .10 ** .05 *** .01 ) nonotes label /*
					*/ title("Patent level subs/comp regs")  mtitle /*
					*/ stats(N myr2 YearFE CatFE YearCatFE bfhcodeFE, fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "PatCohortFE" "CategoryFE" "CohortXCategoryFE" "AssigneeTypeFE")) 					
					
		// output in excel for latex formatting
		local opts `opts' 
		esttab_to_excel_sheet using "$output_excel",  ///
			sheet_name("SubsCompRegs") temp_csv("temp12345.csv") ///
			esttab_options( `opts' ) ///
			notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n6'" "`n8'" "`n9'" "`n9a'" "`n10'" "')		
	}
********************************************************************************
* STARTUP PANEL TABLES
*
* 	table 6  - summary stats in startup panel
*   table 7  - exit analysis: panel A (baseline) and panel B (logit and multinom)
*	table 8  - dynamic regs
* 	table 9  - big robustness table
* 	table 10 - decomp
* 	table 11 - anciliary evid from merger subsample and IPO subsample
*	table a2 - life cycle timing
*	table a3 - important patents 
*	table a4 - financing determinants
*  	table ia.1 - aggregation robustness
*  	table ia.2 - lawyer FE
*
********************************************************************************

	////////////////////////////////
	// table 6 - summary stats in panel
	////////////////////////////////
	{
		use data/startup_qtr_panel, clear		
		keep if year >= $start_yr & retech_stock != . 
		
		// set up
		
		replace b_ipo =b_ipo*100
		replace b_acq =b_acq*100
		replace b_fail = b_fail*100
		g b_stay = 100-b_ipo-b_acq-b_fail
		lab var b_ipo 	"IPO Rate (x100)"       // table specific labels
		lab var b_acq 	"Sell-Out Rate (x100)"
		lab var b_fail  "Failure Rate (x100)"
		lab var b_stay  "Remain Rate (x100)"		
		
		// table
		
		eststo clear
		estpost tabstat $x_bfh l_firm_age $x_base b_ipo b_acq b_fail b_stay  , s(n mean sd p25 p50 p75) c(s) 
		esttab_to_excel_sheet using "$output_excel", temp_csv("temp12345.csv") ///
			sheet_name("VC_Qtr_PanelSummStats") ///
			esttab_options( cells("count(fmt(%9.0fc)) mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f))") noobs nonumber label ) ///	
			notes(`""VC Quarter Panel" "IPO and Acq rates are (%)" "SAMPLE: year =[1980,2010]"  "')
	}
	////////////////////////////////
	// table 7, panel A - exit baseline
	////////////////////////////////
	{
	use data/startup_qtr_panel, clear
	table_set_up	
	eststo clear
	
	// COMPETING RISK HAZARD MODELS	
	
		// failtype is the firm's status in the next quarter
		// 1 if ipo, 4 if acq, 5 if failure, 3 if still private, 4 if LBO (extremely rare, ignored)

		// IPO
		stset firm_age1 ,             id(vxfirm_id) failure(failtype1==1) 			
		eststo, title("IPO"):      stcrreg  $x_bfh_regs $x_base ///
			, compete(failtype1 = 4 5) cluster(vxfirm_id)
	
		// M&A
		stset firm_age1 ,             id(vxfirm_id) failure(failtype1==4) 	
		eststo, title("Acquired"): stcrreg  $x_bfh_regs $x_base ///
			, compete(failtype1 = 1 5) cluster(vxfirm_id)
	
		drop firm_age1	failtype1	
		
	// OLS
	
		rescale_y_prepost_OLS 100 // y={0,100} for OLS		
					
		eststo: reghdfe  t_q1_to_q1_b_ipo $x_bfh_regs $x_base  ///
			, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
			cluster(vxfirm_id) noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
		
		eststo: reghdfe  t_q1_to_q1_b_acq $x_bfh_regs $x_base  ///
			, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
			cluster(vxfirm_id) noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)

		// the exit only subsample should be standardized to unit sd within itself
		preserve					
				local regme reghdfe  t_q1_to_q1_b_ipo $x_bfh_regs $x_base  if t_q1_to_q1_b_ipo == 100 | t_q1_to_q1_b_acq == 100 , absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  )  cluster(year) noconst
				qui `regme'
				keep if e(sample)
				tab t_q1_to_q1_b_ipo // 36.11% ipo
				qui foreach v in  $x_bfh_regs $x_base {
					sum `v' 
					if `r(max)' != 1 replace `v' = `v'/`r(sd)' // don't STD the binary vars
				}
				eststo: `regme'
					postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
					estadd scalar myr2 = 100*e(r2_a)
				sum $x_bfh_regs $x_base if e(sample) // just to double check 
		restore		
						
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
		local n9a "   -LI Similarity and Foreign Similarity are orthoganal to Priv Similarity" 
		local n10 "   -$std_note" 		
	
		local opts compress b(3) star(* .10 ** .05 *** .01 ) nonotes label /*
					*/ mgroups("Competing Risk Hazard" "OLS" , pattern(1 0 1 )) /*
					*/ title("Predicting Next Period Firm Exits")  /*
					*/ mtitle("IPO" "Acquired" "IPO" "Acquired"  "ExitONLYsample"  ) /*
					*/ stats(N myr2 YearFE AgeFE CohortFE CatFE StateFE IndFE VCFE, fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" "AgeFE" "CohortFE" "TechCatFE" "StateFE" "VXIndFE" "VCFE")) 					

		esttab_to_excel_sheet using "$output_excel",  ///
			sheet_name("Exits-Baseline") temp_csv("temp12345.csv") ///
			esttab_options( `opts' ) ///
			notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n6'" "`n7'" "`n8'" "`n9'" "`n9a'" "`n10'" "')
	}	
	////////////////////////////////
	// table 7, panel B - exit - logit and multinomial logit
	////////////////////////////////
	{
	use data/startup_qtr_panel, clear
	table_set_up	
	eststo clear
	
	// logit
			
		eststo: logit  t_q1_to_q1_b_ipo $x_bfh_regs $x_base  ///
			,  cluster(vxfirm_id) 
			estadd scalar myr2 = 100*e(r2_p)
		
		eststo: logit  t_q1_to_q1_b_acq $x_bfh_regs $x_base  ///
			,  cluster(vxfirm_id) 
			estadd scalar myr2 = 100*e(r2_p)
	
	// multinomial
	
		cap drop out_next_period // just here as I dev the code
		g       out_next_period = t_q1_to_q1_b_ipo
		replace out_next_period = 2 if t_q1_to_q1_b_acq == 1
		
		eststo: mlogit out_next_period $x_bfh_regs $x_base  ///
			, base(0) vce(cluster vxfirm_id) nolog
		
	// output 

		local n1  "QUARTERLY sample: 1980-2010" 
		local n2  "Statistical issues: " 
		local n3  "   -Std errors clustered by firm" 
		local n4  "   -R2 (in PERCENT) is psuedo for logit model and adjusted for OLS models" 
		local n5  "Interpretation issues: " 
		local n6  "   -(multinomial)Logit coefficients are relative change in probability for 1 unit increase" 
		local n7  "    ie the log odd coefficients ``beta'' are transformed: exp(beta)-1"         
		local n8  "   -OLS coefficients are % change for 1 unit increase (ie outcome={0,100})" 
		local n9  "   -Dummy variables: NoPatsLast5 Q4 cum_VC_fund_zero" 
		local n9a "   -LI Similarity and Foreign Similarity are orthoganal to Peer Similarity" 
		local n10 "   -$std_note" 		
	
		local opts compress b(3) star(* .10 ** .05 *** .01 ) nonotes label /*
					*/ unstack	noomitted /* this applies to the multinormial
					*/ mgroups("Logit" "Multinomial Logit", pattern(1 0 1 0 )) /*
					*/ title("Predicting Next Period Firm Exits")  /*
					*/ transform(exp(@)-1 exp(@), pattern(1 1 1 1 ) ) /* 
					*/ mtitle("IPO" "Acquired" "IPOis1 Acqis-2"  ) /*
					*/ stats(N myr2 YearFE AgeFE CohortFE CatFE StateFE IndFE VCFE, fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" "AgeFE" "CohortFE" "TechCatFE" "StateFE" "VXIndFE" "VCFE")) 					
					
		esttab_to_excel_sheet using "$output_excel",  ///
			sheet_name("Exits-LogitMulti") temp_csv("temp12345.csv") ///
			esttab_options( `opts' ) ///
			notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n6'" "`n7'" "`n8'" "`n9'" "`n9a'" "`n10'" "')
	}
	////////////////////////////////
	// Table 8 dynamic  
	////////////////////////////////
	{		
		use data/startup_qtr_panel, clear
		table_set_up	
		eststo clear
		
		foreach horizon in 1 4 8 12 16 20 {
			bysort vxfirm_id (qtr): g t_q1_to_q`horizon'_b_priv = _n <= _N - `horizon' - 1
		}
		
		// make sure the sample across y vars and horizons is consistent size
		
		reghdfe  t_q1_to_q1_b_ipo $x_bfh_regs $x_base , absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) cluster(vxfirm_id) noconst 
		g sample = e(sample)
								
		// OLS models
		
			rescale_y_prepost_OLS 100 // y={0,100} for OLS

			qui foreach outcome in priv ipo acq  {
			
				eststo clear
				
				foreach horizon in 1 4 8 12 16 20 {	
					eststo, title("t+`horizon'"): reghdfe  t_q1_to_q`horizon'_b_`outcome' $x_bfh_regs $x_base   ///
						if sample , absorb(year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor ) ///
						cluster(vxfirm_id) noconst 
						postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE
						estadd scalar myr2 = 100*e(r2_a)
						
				}

				// SET UP TABLE OUTPUT
				
				if "`outcome'" == "ipo" {
					local panel = "Panel A: IPO" 
					local sheetname = "DynamicPred_IPO_OLS"
				}
				if "`outcome'" == "acq" {
					local panel = "Panel B: Acquired" 
					local sheetname = "DynamicPred_ACQ_OLS"
				}
				if "`outcome'" == "priv" {
					local panel = "Panel C: Still Private" 
					local sheetname = "DynamicPred_priv_OLS"
				}
				if "`outcome'" == "fail" {
					local panel = "Panel D: Non IPO/Acq Exit" 
					local sheetname = "DynamicPred_FAIL_OLS"
				}
				if "`outcome'" == "ipoORacq" {
					local panel = "IPO OR Acq Exit" 
					local sheetname = "DynamicPred_ipooracq_OLS"
				}
				
				
				// OUTPUT	
				
				local n1  "QUARTERLY sample: 1980-2010" 
				local n2  "Statistical issues: " 
				local n3  "   -Std errors clustered by firm" 
				local n4  "   -R2 (in PERCENT) is psuedo for logit model and adjusted for OLS models" 
				local n5  "Interpretation issues: " 
				local n6  "   -(multinomial)Logit coefficients are relative change in probability for 1 unit increase" 
				local n7  "    ie the log odd coefficients ``beta'' are transformed: exp(beta)-1"         
				local n8  "   -OLS coefficients are % change for 1 unit increase (ie outcome={0,100})" 
				local n9  "   -Dummy variables: NoPatsLast5 Q4 cum_VC_fund_zero" 
				local n9a "   -LI Similarity and Foreign Similarity are orthoganal to Peer Similarity" 
				local n10 "   -$std_note" 		
			
				local opts compress b(3) star(* .10 ** .05 *** .01 ) nonotes label /*
							*/ title("Predicting Next Period Firm Exits")  /*
							*/ stats(N myr2 YearFE AgeFE CohortFE CatFE StateFE IndFE, fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" "AgeFE" "CohortFE" "TechCatFE" "StateFE" "VXIndFE")) 					
				
				esttab_to_excel_sheet using "$output_excel",  ///
					sheet_name("`sheetname'") temp_csv("temp12345.csv") ///
					esttab_options( `opts' ) ///
					notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n6'" "`n7'" "`n8'" "`n9'" "`n9a'" "`n10'" "')
			
			}
	}
	////////////////////////////////
	// Table 9 big robustness
	////////////////////////////////
	
	// first, build different aggregations of RETech
	{
		// compute firm-qtr vars, like; avg RETech for patents over prior K qtrs
	
		// rangestat can produce firm-qtr stats over prior ranges nicely, from
		// the pnum level data, but to 
		// have values in quarters where a firm doesn't patent, we need to have 
		// obs for all firm-qtrs. so get the union of the list of vxfirm_ids and 
		// all qtrs, and then merge this with patents
	
		tempfile firms qtrs 
	
		use vxfirm_id ayear if vxfirm_id != . & ayear >= 1970 using data/pat_lv, clear
		drop ayear
		duplicates drop *, force
		save `firms'

		use aqtr ayear if ayear >= 1970 & aqtr != . using data/pat_lv, clear
		drop ayear
		duplicates drop *, force
		tsset aqtr
		tsfill, full
		cross using `firms'
		merge 1:m vxfirm_id aqtr using data/pat_lv, nogen keep(1 3) keepusing(retech)
		sort vxfirm_id aqtr

		// compute rolling mean/max over desired interval
		
		foreach win in 4 8 12 16 20 {
			local lookback = 1-`win' // ex: stats over [-3,0] for win length = 4
			
			rangestat (mean) retech (max) retech, by(vxfirm) interval(aqtr `lookback' 0)
			rename *_mean *_mean_roll`win'
			rename *_max  *_max_roll`win'
		}
		
		// now reduce to quarterly; rangestats duplicates same values for multiple 
		// obs in a qtr, so just delete them
		keep vxfirm aqtr *roll* //*_max*
		duplicates drop vxfirm aqtr, force
		rename aqtr qtr // in the panel, the time var is "qtr"
			
	// merge with the panel, clean up, ready for tests
	
		merge 1:1 vxfirm_id qtr using data/startup_qtr_panel, keep(2 3) nogen keepusing(latestLead_vc_index)
	
		// and fill missings with 0 (these are 0 patent qtrs anyways and are absorbed by FE) 
		// and standardize
		
		foreach v of varlist *roll* {
			replace `v' = 0 if `v' == .
			sum `v' 
			replace `v' = `v' / `r(sd)'			
		}
	
		save "temp/diff_agg_panel", replace
	
	}
	// now run tests
	{
		// this SPOOKY subroutine takes 4-5 hours, so it is commented out
		// only the brave and steady of heart should continue forth 
		// (Sorry: It's halloween week as I write this.)
		
		*do "subroutines/tab - big robustness table.do"	// 4-5 hrs
	}
	
	////////////////////////////////
	// table 10 - exit baseline decomp RETech
	////////////////////////////////
	{

	use data/startup_qtr_panel, clear
	table_set_up	
	eststo clear
	
	// COMPETING RISK HAZARD MODELS	

		// IPO
		stset firm_age1 ,             id(vxfirm_id) failure(failtype1==1) 			
		eststo, title("IPO"):      stcrreg  $x_bfh_regs_decomp $x_base ///
			, compete(failtype1 = 4 5)	// lbo and active are treated as right censored
	
		// M&A
		stset firm_age1 ,             id(vxfirm_id) failure(failtype1==4) 	
		eststo, title("Acquired"): stcrreg  $x_bfh_regs_decomp $x_base ///
			, compete(failtype1 = 1 5)	// lbo and active are treated as right censored	
	
		drop firm_age1	failtype1	
		
	// OLS
	
		rescale_y_prepost_OLS 100 // y={0,100} for OLS		
					
		eststo: reghdfe  t_q1_to_q1_b_ipo $x_bfh_regs_decomp $x_base  ///
			, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
			cluster(vxfirm_id) noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
		
		eststo: reghdfe  t_q1_to_q1_b_acq $x_bfh_regs_decomp $x_base  ///
			, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
			cluster(vxfirm_id) noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
			
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
					*/ mgroups("Competing Risk Hazard" "OLS" , pattern(1 0 1 )) /*
					*/ title("Predicting Next Period Firm Exits")  /*
					*/ mtitle("IPO" "Acquired" "IPO" "Acquired"  "ExitONLYsample"  ) /*
					*/ stats(N myr2 YearFE AgeFE CohortFE CatFE StateFE IndFE VCFE, fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" "AgeFE" "CohortFE" "TechCatFE" "StateFE" "VXIndFE" "VCFE")) 					

		esttab_to_excel_sheet using "$output_excel",  ///
			sheet_name("Exits-BaselineDecomp") temp_csv("temp12345.csv") ///
			esttab_options( `opts' ) ///
			notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n6'" "`n7'" "`n8'" "`n9'" "`n9a'" "`n10'" "')
	}
	
	////////////////////////////////
	// Table 11 exit subsamples
	////////////////////////////////
	{
	/* Below, we provide the code to replicate this table. However, due to 
	the need for substantial licensed data for this table, we omit the 
	necessary data files containing CARs (from WRDS) and IPO data (from 
	SDC). Please contact if curious about this table. 		

	// CAR for public acq of startups
	
		// get CAR for acquirors - exclude if pub acquiror acquires multiple targets on day

		foreach w in 1 3 {
			import delim using "$data/VX and SDC sell out data/cars_ff3_win`w'`w'_cusip10.txt", clear varn(1) delim(comma)
			replace cusip = substr(cusip,1,6)
			g date = date(evtdate,"DMY")
			format date %td
			keep cusip date car
			rename car car`w'`w'
			tempfile cars`w'`w'
			save `cars`w'`w''		
		}
			
		import delim using "$data/VX and SDC sell out data/matchedFirms.txt"  , clear varn(1) delim(comma)
		g date = date(dateannounced,"DMY")
		format date %td
		bysort acquirorcusip date: drop if _N > 1 // if multiple same day targets, don't include
		keep acquirorcusip vxfirm_id date targetind value
		rename acq cusip
		count
		merge 1:1 cusip date using `cars33',   keep(1 3) nogen
		merge 1:1 cusip date using `cars11',   keep(1 3) nogen
		count
		sum

		// merge in RETech of vxfirm at date

		g qtr = qofd(date) 
		merge 1:1 vxfirm_id qtr using data/startup_qtr_panel, keep(1 3) keepusing() nogen

		drop if noPatsLast5yrs == 1
		table_set_up	

		lab var retech_stock "Target RETech"
		lab var l_pats_last_20qtr "Target Log(1+PatApps[q-1,q-20])"
		
		eststo clear
		foreach w in 1 3  {
			eststo, title("[-`w',`w']"): reghdfe car`w'`w' retech_stock  , a(year) vce(cluster targetind) nocons // SDC's target industry is more granular than VX's 
				estadd scalar myr2 = 100*e(r2_a)
				postreg_add YearFE   
		}
		local opts compress b(3) star(* .10 ** .05 *** .01 ) nonotes label /*
					*/ title("Acquiror CAR") mtitles  /*
					*/ stats(N myr2 YearFE , fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" "AgeFE" "CohortFE" "TechCatFE" "StateFE" "VXIndFE" "VCFE")) 					

	// IPO issuance details
		
		use 	data/startup_qtr_panel, clear
		table_set_up
		
		// merge issuance and clean var defs
		
		merge m:1 vxfirm_id using "$data/DataFromJerry\IPO_Data_FromSDC\OUTPUT\link vxfirm_id to DealNumber-all SDC vars", ///
			keep(1 3) keepusing(PrimarySharesOffered SecondaryShsOfrdinthisM MainSICCode) nogen
					
		destring MainSICCode, replace
		replace MainSICCode = floor(MainSICCode/100)			
		
		replace PrimarySharesOffered   = 0 if PrimarySharesOffered == .
		replace SecondaryShsOfrdinthisM = 0 if SecondaryShsOfrdinthisM == .
		replace PrimarySharesOffered    = . if t_q1_to_q1_b_ipo != 1
		replace SecondaryShsOfrdinthisM = . if t_q1_to_q1_b_ipo != 1
		
		tab t_q1_to_q1_b_ipo
		sum PrimarySharesOffered SecondaryShsOfrdinthisM  // good, defined correct
												
		// set up reg indep vars
		
		g primaryshare = 100*PrimarySharesOffered / (PrimarySharesOffered+SecondaryShsOfrdinthisM)
		sum primaryshare, d
		
		g all_primary = primaryshare == 100 if primaryshare != .
		
		lab var primaryshare "Primary Share (%)"
		lab var all_primary  "Only Primary Shares"
		
		qui reghdfe primaryshare retech_stock, a(year ) vce(robust) nocons
		sum retech_stock if e(sample)
		replace retech_stock = retech_stock / `r(sd)'
		
		eststo: reghdfe primaryshare retech_stock, a(year ) vce(cluster MainSICCode) nocons
				postreg_add YearFE  
				estadd scalar myr2 = 100*e(r2_a)
		eststo: reghdfe all_primary retech_stock, a(year ) vce(cluster MainSICCode) nocons
				postreg_add YearFE   
				estadd scalar myr2 = 100*e(r2_a)
		
	// output 

			local n1  "Exit subsamples" 
			local n2  "Statistical issues: " 
			local n3  "   -Std errors clustered by acq industry in sell-out, technology in IPO" 
			local n4  "   -Adj R2 (in PERCENT) " 
			local n5  "Interpretation issues: " 
			local n9  "   -RETech is sd=1" 
					
			local opts compress b(3) star(* .10 ** .05 *** .01 ) nonotes label /*
						*/ mgroups("Sell-outs" "IPOs" , pattern(1 0 1 )) /*
						*/ mtitles("AcqCAR[-1,1]" "AcqCAR[-3,3]" "PrimaryShare(%)" "OnlyPrimaryShares")   /*
						*/ stats(N myr2 YearFE , fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" )) 					

			esttab_to_excel_sheet using "$output_excel",  ///
				sheet_name("ExitSubsamples") temp_csv("temp12345.csv") ///
				esttab_options( `opts' ) ///
				notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n9'" "')
	
	*/
	}

	////////////////////////////////
	// table A2 - timing of events in startup life
	////////////////////////////////
	{
		tempfile firstpatqtr_of_vx firstVCFUNDqtr_of_vx
	
		use vxfirm_id appdate using data/pat_lv, clear
		g first_pat_qtr = qofd(appdate)
		collapse (min) first_pat_qtr , by(vxfirm_id)
		save `firstpatqtr_of_vx'

		use vxfirm_id  vc_fund_qtr using data/startup_qtr_panel, clear
		collapse (min) first_vc_fund_qtr = vc_fund_qtr , by(vxfirm_id)
		save `firstVCFUNDqtr_of_vx'
					
		use data/startup_qtr_panel, clear
		
		keep if year >= $start_yr	
		
		distinct vxfirm_id
		g qtr_ipo  = qtr if b_ipo == 1
		g qtr_acq  = qtr if b_acq == 1
		g qtr_vc   = qtr if vc_fund_qtr == qtr
		collapse (min)  first_firm_qtr    = first_qtr ///
						ipo_qtr           = qtr_ipo ///
						acq_qtr           = qtr_acq ///
						, by(vxfirm_id)
		merge 1:1 vxfirm_id using `firstpatqtr_of_vx', keep(1 3)
		drop _m
		merge 1:1 vxfirm_id using `firstVCFUNDqtr_of_vx', keep(1 3)
		drop _m
		mdesc 
						
		g time_found_to_pat  = first_pat_qtr      - first_firm_qtr
		g time_found_to_vc   = first_vc_fund_qtr  - first_firm_qtr
		g time_found_to_ipo  = ipo_qtr            - first_firm_qtr
		g time_found_to_acq  = acq_qtr            - first_firm_qtr
		
		g time_pat_to_vc    = first_vc_fund_qtr  - first_pat_qtr
		g time_pat_to_ipo   = ipo_qtr            - first_pat_qtr
		g time_pat_to_acq   = acq_qtr            - first_pat_qtr
		
		foreach v of varlist time_* {
				replace `v' = `v' / 4 // report in years !!!!!!!!!!!!!!!!!!!!
		}
				
		// SUMMARY STATS
			eststo clear
			estpost tabstat time_*, s(n mean sd p25 p50 p75) c(s) 
			esttab_to_excel_sheet using "$output_excel", temp_csv("temp12345.csv") ///
				sheet_name("FirmTiming") ///
				esttab_options( cells("count(fmt(%9.0fc)) mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f))") noobs nonumber ) ///	
				notes(`""Firm level" "SAMPLE = vc_FirmQTR_sample.dta" "')
	}
			
	////////////////////////////////
	// table A3 - important patents
	////////////////////////////////
	{

	// vars we will output
	
		global important_patent_table_vars retech cites5 kpss breadth orig sim_priv sim_li sim_foreign

use "data/auxilliary/kellytable", clear

	// load patent level

		use data/pat_lv, clear
		format aqtr %tq	
keep if ayear >= 1930 & ayear <= 2010
				
		rename (forcites_all_within5 xi tech_breadth adj_originality_nber) (cites5 kpss breadth orig)
		keep pnum ayear gyear $important_patent_table_vars
						
	// get percentile variables
		
		/*
		gquantiles p1 = retech, xtile nq(100) // gtools suite, works in 1.15 sec and is BY-ABLE
		fastxtile p2 = retech,  nq(100)       //                        9.77 sec
		count if p1 != p2
		*/
		
		foreach v in $important_patent_table_vars {
		
			di "`v'"
					
			egen temp = mean(`v'), by(ayear)
			g `v'_yearFEremoved = `v' - temp
			drop temp
			
			gquantiles p_yearFE_`v' = `v'_yearFEremoved, nq(100) xtile
						
		}
	
		keep pnum ayear gyear p_*

	// compare to kelly
	
		merge 1:1 pnum using "data/auxilliary/kellytable",  keep(3) nogen keepusing(PercQuality05wyearFE)
		foreach v of varlist Perc* {
			replace `v' = `v' * 100 // so KPST vars are on same scale as ours
		}
		li pnum if missing(p_yearFE_retech) // 3 patents without google patent pages 
		drop if missing(p_yearFE_retech) 
		sum 
				
	// output
				
		drop ayear
		order pnum gyear *retech *5 *kpss P
		export excel   ///
			using "$output_excel" , sheet("Important patents") ///
			cell(A1) first(var) sheetmodify 
	}		

	////////////////////////////////
	// table A4 - startup financing determinants
	////////////////////////////////
	{

	// get bank financing timing
		
		/*
		use "$data\for laurent to get dealscan match\dealscan_packages_matched" , clear
		g qtr = qofd(DealActiveDate)
		format qtr %tq
		keep v qtr	DealAmount SalesAtClose
		duplicates drop v q, force
		tempfile qtrs_of_bank_fin
		save `qtrs_of_bank_fin'
		*/
		
	// set up for the tests
	
		use data/startup_qtr_panel, clear
		table_set_up	
		eststo clear
		
		merge 1:1 vxfirm_id qtr using data/auxilliary/qtrs_of_bank_fin, keep(1 3)
		g bank_debt = _m == 3
			
		* clean the vars up
		
		foreach v in flowVCfund DealAmount {
			winsor `v', p(.01) g(`v'WIN)
			drop `v'
			rename `v' `v'
		}
			
		g t_q1_to_q1_b_round   = (f1.flowVCfund != .)*100
		g t_q1_to_q1_b_bank   = (f1.bank_debt == 1)*100

		g l_newVCfund = log(1+F1.flowVCfund )
		replace l_newVCfund = 0 if l_newVCfund == .
		g l_newBANKfund = log(1+F1.DealAmount )
		replace l_newBANKfund = 0 if l_newBANKfund == .	

		lab var l_newVCfund         "Log(1+VC Round Size)"
		lab var l_newBANKfund       "Log(1+New Bank Debt)"
		lab var t_q1_to_q1_b_round  "New VC Round"
		lab var t_q1_to_q1_b_bank   "New Bank Debt Issue"	
	
	// now the tests - incidence of new financing and size of new financing
	
		eststo clear
	
		eststo: reghdfe  t_q1_to_q1_b_round $x_bfh_regs $x_base  ///
			, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
			cluster(vxfirm_id) noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
		eststo: reghdfe  l_newVCfund $x_bfh_regs $x_base  ///
			, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
			cluster(vxfirm_id) noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
		eststo: reghdfe  t_q1_to_q1_b_bank $x_bfh_regs $x_base  ///
			, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
			cluster(vxfirm_id) noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
		eststo: reghdfe  l_newBANKfund $x_bfh_regs $x_base  ///
			, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
			cluster(vxfirm_id) noconst 
			postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
			estadd scalar myr2 = 100*e(r2_a)
	
		local n1  "QUARTERLY sample: 1980-2010" 
		local n2  "Statistical issues: " 
		local n3  "   -Std errors clustered by firm" 
		local n4  "   -R2 (in PERCENT) is psuedo for logit model and adjusted for OLS models" 
		local n5  "Interpretation issues: " 
		local n6  "   -" 
		local n7  "    "         
		local n8  "   -OLS coefficients are % change for 1 unit increase (ie outcome={0,100})" 
		local n9  "   -Dummy variables: NoPatsLast5 Q4 cum_VC_fund_zero" 
		local n9a "   -LI Similarity and Foreign Similarity are orthoganal to Peer Similarity" 
		local n10 "   -$std_note" 		
	
		local opts compress b(3) star(* .10 ** .05 *** .01 ) nonotes label /*
					*/ stats(N myr2 YearFE AgeFE CohortFE CatFE StateFE IndFE VCFE, fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" "AgeFE" "CohortFE" "TechCatFE" "StateFE" "VXIndFE" "VCFE")) 					
					
		esttab_to_excel_sheet using "$output_excel",  ///
			sheet_name("FinDeterm") temp_csv("temp12345.csv") ///
			esttab_options( `opts' ) ///
			notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n6'" "`n7'" "`n8'" "`n9'" "`n9a'" "`n10'" "')
	}
		
	////////////////////////////////
	// table IA.1 - different aggregations
	////////////////////////////////
	
	* This is done in the big robustness table's code
				
	////////////////////////////////
	// table IA.2 - removing lawyer FE from RETech
	////////////////////////////////
	{
		* see "subroutines/RETech_tilde_stock.do" to see how the RETech_tilde_stock.dta file is created
	
		use data/startup_qtr_panel, clear
		table_set_up	
		eststo clear
		
		merge 1:1 qtr vxfirm_id using data/auxilliary/RETech_tilde_stock, keep(1 3)
	
		global x_bfh_regs2    e_retech_meanadj_stock tech_breadth_stock sim_priv_stock sim_li_m_priv_stock sim_foreign_m_priv_stock  	// due to multi col, we orthog other distance vars in tests
		
		// COMPETING RISK HAZARD MODELS	

			// IPO
			stset firm_age1 ,             id(vxfirm_id) failure(failtype1==1) 			
			eststo, title("IPO"):      stcrreg  $x_bfh_regs2 $x_base ///
				, compete(failtype1 = 4 5) cluster(vxfirm_id)
		
			// M&A
			stset firm_age1 ,             id(vxfirm_id) failure(failtype1==4) 	
			eststo, title("Acquired"): stcrreg  $x_bfh_regs2 $x_base ///
				, compete(failtype1 = 1 5) cluster(vxfirm_id)
		
			drop firm_age1	failtype1	
			
		// OLS
		
			rescale_y_prepost_OLS 100 // y={0,100} for OLS		
						
			eststo: reghdfe  t_q1_to_q1_b_ipo $x_bfh_regs2 $x_base  ///
				, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
				cluster(vxfirm_id) noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
			
			eststo: reghdfe  t_q1_to_q1_b_acq $x_bfh_regs2 $x_base  ///
				, absorb( year firm_age first_year i.state_FE nber_vx_cat vxindgrpmajor  ) ///
				cluster(vxfirm_id) noconst 
				postreg_add YearFE AgeFE CohortFE CatFE StateFE IndFE 
				estadd scalar myr2 = 100*e(r2_a)
							
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
						*/ mgroups("Competing Risk Hazard" "OLS" , pattern(1 0 1 )) /*
						*/ title("Predicting Next Period Firm Exits")  /*
						*/ mtitle("IPO" "Acquired" "IPO" "Acquired"   ) /*
						*/ stats(N myr2 YearFE AgeFE CohortFE CatFE StateFE IndFE VCFE, fmt(%12.0fc %9.1f  0 0 0 0) labels("Observations" "R2(%)" "YearFE" "AgeFE" "CohortFE" "TechCatFE" "StateFE" "VXIndFE" "VCFE")) 					
		*esttab, `opts'
	
		esttab_to_excel_sheet using "$output_excel",  ///
			sheet_name("Exits-SansLaywerFE") temp_csv("temp12345.csv") ///
			esttab_options( `opts' ) ///
			notes( 	`" "`n1'" "`n2'" "`n3'" "`n4'" "`n5'" "`n6'" "`n7'" "`n8'" "`n9'" "`n9a'" "`n10'" "')	
	}			

********************************************************************************
* 
* FIGURES	
*
********************************************************************************

///////////////////////////////////////////////////////////////////////////////	
// time series plots that require a common prep from the patent level data. 
// E.g.: RETech, RETech by tech, RETech by assignee type, RETech decomp
///////////////////////////////////////////////////////////////////////////////	
	
	////////////////////////////////
	// prep to plot: load patent level and convert to needed time series
	////////////////////////////////
	{	
		use pnum ayear aqtr nber bfhcode assignee_id lawyer_id state /* pat info
			*/ retech* tech_breadth sim_priv sim_foreign sim_li  /* pat traits
			*/ using data/pat_lv, clear
		
		// seperate retech by tech cat var
		
		g nber1 = floor(nber/10) 
		tab nber1                  // % by cat over whole 1930-2010 period
		tab nber1 if ayear >= 1980 // -2% chem / drugs / elec, +7% comp, -4% mech, -5% other
		separate retech, by(nber1) g(retech_nber1_) 
		
		// seperate retech by assignee type
		
		separate retech, by(bfhcode) g(retech_type_) 
		
		// strip FE from RETech		

		reghdfe retech                 , absorb(nber)        resid(e_retech_nber)
		reghdfe retech if ayear >= 1976, absorb(assignee_id lawyer_id nber state)  resid(e_retech_all)

		sum e_retech*
		
		// convert to time series of flows, but the "prep_for_ts_plot" function 
		// isn't robust to blank values 
		// (the running pnum count is ALL patents, not just that type!)
		// so do for each type (while dropping other patents),
		// and then stitch together
		
		// get all the vars we want to plot
		
		unab stats_to_stat : *retech* tech_breadth sim_li sim_priv sim_foreign 
		local firstv: word 1 of `stats_to_stat'
		di "`stats_to_stat'"
		di "`firstv'"

		// prep_for_ts_plot for each...
		
		qui foreach v in `stats_to_stat' {
		noi di "`v'"
		preserve
			keep if `v' != .
			prep_for_ts_plot `v'
			tempfile f_`v'
			save `f_`v''
		restore	
		}
		
		// stitch back together
		
		use                  `f_`firstv'', clear
		qui foreach v in `stats_to_stat' {
			merge 1:1 aqtr using `f_`v'', nogen
		}
	}	
	////////////////////////////////
	// fig 2 - RETech
	////////////////////////////////
	{	
		local lineparts aqtr if year(dofq(aqtr)) >= 1930 & year(dofq(aqtr)) <= 2010, c(L) lp(solid)   lcolor(black) lw(thick) ms(i) mlab() mlabpos(9) mlabs(large) mlabc(black)
		local graphoptions ytitle("") xtitle("")	tlabel(1930q1 (80) 2010q4 , format(%tqCY) labs(large) ) legend(off) ylabel(#3, angle(horizontal) glcolor(p2%10) format(%9.0g) labs(large)) graphregion(color(white) lwidth(medium))
		twoway (line retech     `lineparts') , title(""        , size( vlarge )) 		 `graphoptions'
		graph display , ysize(4) xsize(6)
		graph export "output/RETech-1930.png", replace		
	}		
	////////////////////////////////
	// fig 3 - RETech by tech cat 
	////////////////////////////////
	{	
		drop retech_nber1_7 retech_nber1_8
	
		local varnum 1 // will loop over variable labels, explicitly increment var name numbering
		foreach category in "Chemicals (17%)" "Comps & Commun (17%)" "Drugs & Medicine (7%)" "Electricity (19%)" "Mechanics (20%)" "Other (20%)" {
			local graph_name = lower(substr(`"`category'"',1,2)) //
			di  "varnum `varnum' name `graph_name' label `category'"
			
			twoway  /// plot all in gray 
					(line retech_nber1_*        aqtr if year(dofq(aqtr)) >= 1930 & year(dofq(aqtr)) <= 2010 ///
						, lpattern(solid) lwidth(medium) lcolor(gray gray gray gray gray gray)) ///
					/// plot focus on one variable
					(line retech_nber1_`varnum' aqtr if year(dofq(aqtr)) >= 1930 & year(dofq(aqtr)) <= 2010 ///
						, lpattern(solid) lwidth(vthick) lcolor(blue))  ///
					/// options
					, title("`category'", color(black)) legend(off) ytitle("") xtitle("") ///
					  tlabel(1930q1 (80) 2010q4 , format(%tqCY) labs(large) ) 	///			
					  ylabel(, angle(horizontal) glcolor(p2%10)  labs(large) format(%9.0g) ) ///
					  name(`graph_name', replace)   graphregion(color(white) lwidth(medium))
			
			local varnum = `varnum' + 1
		}
		
		window manage close graph _all

		graph combine ch co dr el me ot,  rows(3) graphregion(color(white) lwidth(medium))
		graph display, xsize(5) ysize(7)
		graph export "output/RETech-1930-ByTechCat.png", replace
	}	
	////////////////////////////////
	// fig 4 - RETech by assignee type 
	////////////////////////////////
	{			
		cap drop retech_type_0
		
		local varnum 1 // will loop over variable labels, explicitly increment var name numbering
		foreach category in "Individuals" "Private US Firms" "Public US Firms" "International Firms" {
			local graph_name = "g_`varnum'"
			di  "varnum `varnum' name `graph_name' label `category'"
			
			twoway  /// plot all in gray 
					(line retech_type_*        aqtr if year >= 1930 & year <= 2010 ///
						, lpattern(solid) lwidth(medium) lcolor(gray gray gray gray gray gray)) ///
					/// plot focus on one variable
					(line retech_type_`varnum' aqtr if year >= 1930 & year <= 2010 ///
						, lpattern(solid) lwidth(vthick) lcolor(blue))  ///
					/// options
					, title("`category'", color(black)) legend(off) ytitle("") xtitle("") ///
					  tlabel(1930q1 (80) 2010q4 , format(%tqCY) labs(large) ) 	///			
					  ylabel(, angle(horizontal) glcolor(p2%10)  labs(large) format(%9.0g) ) ///
					  name(`graph_name', replace)   graphregion(color(white) lwidth(medium))
			
			local varnum = `varnum' + 1
		}
		
		window manage close graph _all

		graph combine g_1 g_2 g_3 g_4,  rows(3) graphregion(color(white) lwidth(medium))
		graph display, xsize(7) ysize(5)
					  
		graph export "output/RETech-1930-ByAsgnType.png", replace
	}	
	////////////////////////////////
	// fig IA.1 - all BFH variables 
	////////////////////////////////
	{	
		local gopts  legend(off) graphregion(color(white) lwidth(medium)) 
		local xopts  xtitle("")   tlabel(1930q1 (80) 2010q4 , format(%tqCY)    labs(large) nolab grid )
		local yopts  ytitle("")   ylabel(#4, angle(horizontal) glcolor(p2%10)  labs(large) format(%9.0g)) 

		foreach v in "1930 retech RETech" `"1930 tech_breadth "Tech Breadth""' { 
			tokenize `v', p(" ")

			if `1' == 1980 local gap 40 
			if `1' == 1930 local gap 80 
			local lineparts aqtr if year(dofq(aqtr)) >= `1' & year(dofq(aqtr)) <= 2010,  lp(solid)  lcolor(black) lw(thick)
			
			twoway (line `2' `lineparts') , title("{bf: `3' }" , size( large ) color(black)) ///
					 `gopts' `xopts' `yopts' name(`2'_`1'    , replace)
			
		}

		local lineparts1 aqtr if year(dofq(aqtr)) >= 1930 & year(dofq(aqtr)) <= 2010, c(L) lp(dot)   lcolor(black) lw(thick) ms(i) mlab() mlabpos(3) mlabs(medlarge) mlabc(black)
		local lineparts2 aqtr if year(dofq(aqtr)) >= 1930 & year(dofq(aqtr)) <= 2010, c(L) lp(sold)  lcolor(black) lw(thick) ms(i) mlab() mlabpos(9)  mlabs(medlarge) mlabc(black)
		local lineparts3 aqtr if year(dofq(aqtr)) >= 1930 & year(dofq(aqtr)) <= 2010, c(L) lp(dash)  lcolor(black) lw(thick) ms(i) mlab() mlabpos(3)  mlabs(medlarge) mlabc(black)

		twoway (scatter sim_priv     `lineparts1') ///
			   (scatter sim_li  `lineparts2') ///
			   (scatter sim_foreign     `lineparts3') ///
			   , title("{bf: Similarity to}"  , size( large ) color(black)) ///
				 `gopts' `yopts' ///
				 xtitle("")   tlabel(1930q1 (80) 2010q4 , format(%tqCY)    labs(large) grid ) /// need the labels now! 
				 ttext(.068 1965q1  "LI", place(e) size(large)) ///
				 ttext(.11 1938q1  "Private", place(n) size(large)) ///
				 ttext(.085 1940q1  "Foreign", place(e) size(large)) ///
		name(dist_1930, replace)
		
		graph combine retech_1930 tech_breadth_1930 dist_1930 , rows(3)  graphregion(color(white) lwidth(medium)) 
		graph display , ysize(6.5) xsize(5)

		graph export "output/BFHvars-1930-Vert.png", replace	
	}	
	////////////////////////////////
	// fig IA.3 - RETech after stripping FE
	////////////////////////////////
	{	
		local lineparts1 aqtr if year(dofq(aqtr)) >= 1930 & year(dofq(aqtr)) <= 2010, c(L) lp(solid)   lcolor(black) lw(thick) ms(i) mlab() mlabpos(9) mlabs(large) mlabc(black)
		local lineparts2 aqtr if year(dofq(aqtr)) >= 1930 & year(dofq(aqtr)) <= 2010, c(L) lp(dot)  lcolor(black) lw(thick) ms(i) mlab() mlabpos(3)  mlabs(medlarge) mlabc(black)
		local lineparts3 aqtr if year(dofq(aqtr)) >= 1980 & year(dofq(aqtr)) <= 2010, c(L) lp(dash)  lcolor(black) lw(thick) ms(i) mlab() mlabpos(3)  mlabs(large) mlabc(black)
		local graphoptions ytitle("") xtitle("")	tlabel(1930q1 (80) 2010q4 , format(%tqCY) labs(large) )  ylabel(#3, angle(horizontal) glcolor(p2%10) format(%9.0g) labs(large)) graphregion(color(white) lwidth(medium))
		twoway (scatter retech      `lineparts1') ///
			   (scatter e_retech_nber  `lineparts2') ///
			   (scatter e_retech_all  `lineparts3') ///
			   , title(""  , size( vlarge ))  `graphoptions' ///
					yscale(range(.5 1.75)) ///
					legend(order(1 "RETech" 2 "RETech - E[RETech|Tech. FE]" 3 "RETech - E[RETech|Tech. FE, Asgn. FE, Lawyer FE, State FE]" ) rows(4) )	
					//ttext(.45 1988q1   "Measured from claims", place(c) size(large)) ///
					//ttext(1.6 1998q4  "Measured from descriptions", place(c) size(large))  
		graph export "output/RETech-1930-FE.png", replace	
	}

///////////////////////////////////////////////////////////////////////////////	
// other plots
// i.e. not the TS plots that require a common prep from the pat lv data 
///////////////////////////////////////////////////////////////////////////////	
	
	////////////////////////////////
	// fig 1 - pagerank
	////////////////////////////////

	// a screenshot
	
	////////////////////////////////
	// fig 5 - subs and complements
	////////////////////////////////
	{
	
	// This figure requires an additional large file on all citation pairs not 
	// included in this repo. We include the code for transparency. 
	
	*do "subroutines/fig - subs and comps.do"
	
	}	
	////////////////////////////////
	// fig 6 - exit distribution
	////////////////////////////////
	{
		use vxfirm_id qtr retech_stock b_ipo b_acq pnum_count_last_20_qtrs using data/startup_qtr_panel, clear
		
		// sample condition: exiting firms with patents in last five years, drop extreme tails for figure
		qui sum retech_stock, d
		local plotif pnum_count_last_20_qtrs > 0 & retech_stock < `r(p99)' & retech_stock > `r(p1)'
		
		// ipo part
		kdensity retech_stock                if b_ipo == 1 & `plotif', note("") caption("") lw(thick) lc(red) title("")
		// acq part
		twoway addplot kdensity retech_stock if b_acq == 1 & `plotif', lw(thick) lc(black) ///
			legend(order(1 "IPO firms" 2 "Sell-Out firms") size(*1.1)) ///
			title("") 	xtitle("")  note("") caption("") /// Distribution of RETech at exit , color(black)
			graphregion(color(white) lwidth(medium))  ///
			xscale(range(-1.1 6.1)) xlabel(-1(1)6, labsize(*1.1))  /// 		
			yscale(range(0 .72)) ylabel(  , labsize(*1.1) angle(horizontal) glcolor(p2%10) ) ///
			ytitle("Density", margin(r=4) size(medlarge)) 
		
		graph export "output/exit_distribution.png", replace
	
	}
	////////////////////////////////
	// fig 7 - IPO prob by RETech quantiles
	////////////////////////////////
	{

		use t_q1_to_q1* noPatsLast5yrs retech_stock vxf year /*
			*/ if (t_q1_to_q1_b_ipo == 1 | t_q1_to_q1_b_acq == 1) /* ipo/sell-out firms
			*/ & noPatsLast5yrs == 0 & year >= 1980 & year <= 2010 /* that patent in run up to exit
			*/ using data/startup_qtr_panel, clear
			
		xtile quint = retech_stock, n(5)
		
		rename t_q1_to_q1_b_ipo b_ipo
		collapse b_ipo , by(quint)
		drop if q == . 

		twoway bar b_ipo quint ///
			   , xtitle("RETech quintiles", size(medlarge) margin(t=4)) ///
			   ytitle("") ///
			   fc(gs1) col(black) ///
			   ///title("% of Exits that are IPOs" , size(large) margin(b=4)) ///
			   ylabel(0 "0" .1 "10" .2 "20" .3 "30"  .4 "40" .5 "50%" ,angle(h) glc(gs14) labs(med) ) ///		   
			   graphregion(color(white))   plotr(m(zero)) legend(off) ///
			   xscale(range(.5 5.5)) xlabel(1 "Bottom" 2 " " 3 " " 4 " " 5 "Top", labs(med) ) 
			   
		graph export "output/ipo_prob_by_RETech_quint.png", replace		 
	}
	////////////////////////////////
	// fig 8 - time to exit by RETech quintile
	////////////////////////////////
	{
		use data/startup_qtr_panel, clear

		// sample: 10 years after first VC fund	
		
		g time_since_first_vc = qtr - vc_fund_qtr
		keep if time_since_first_vc <= 40	
		
		// we'll average the RETech of patents they received over the 10 years 
		// but we need to not average the 0s for qtrs without patent apps
		
		replace retech_stock = . if retech_stock == 0 
			
		collapse (max)  b_ipo b_acq b_fail time_since_first_vc (mean) retech_stock , by(vxfirm_id)
		
		// sample: startups that received patents
		
		drop if retech == . 
		
		// set up table
		
		g outcome = ""
		replace outcome = "IPO"      if b_ipo == 1
		replace outcome = "Sell-Out" if b_acq == 1
		replace outcome = "Defunct"  if b_fail == 1
		replace outcome = "Active"   if outcome == ""
		g b_active = outcome == "Active"   
		
		xtile quint = retech, n(5)
		tab quint
		
		// plot
		
		collapse (mean) time (semean) se = time, by(outcome quint)
		
		g upper = time + se
		g lower = time - se
		
		twoway (scatter time q if outcome == "IPO",      c(l) lp(dash) lc(red) mc(red)) ///
			   (scatter time q if outcome == "Sell-Out", c(l) lp(dash) lc(black) mc(black)) ///
			   (rcap upper lower q if outcome == "IPO",      lc(red)) ///
			   (rcap upper lower q if outcome == "Sell-Out", lc(black)) ///
			   , xtitle("RETech quintiles", size(medlarge) margin(t=4)) ///
			   ytitle("Quarters to exit" , size(medlarge) margin(r=4)) ///
			   ylabel(,angle(h) glc(gs14) ) ///		   
			   graphregion(color(white))   plotr(m(zero)) legend(off) ///
			   xscale(range(.5 5.5)) xlabel(1 "Bottom" 2 " " 3 " " 4 " " 5 "Top") ///
			   text( 20.7 3 "Sell-Outs", color(black)) ///	 
			   text( 19 3 "IPOs", color(red)) 
		graph export "output/time-to-exit-by-ret-quintile.png", replace		 
				 
	}
	////////////////////////////////
	// fig 9 - startup/acquirer matching
	////////////////////////////////
	{
		* first, we computed (gvkey-qtr) RETech for public firms
		
		* second, we linked the venture expert sellouts to deals in SDC when 
		* possible which gave use the acquirer's cusip. we merged in gvkey and
		* then RETech. 
									
		use data/auxilliary/tar_acq_matched_sample, clear
		
			local y acq_retech_stock
			local x tar_retech_stock
			local if if acq_r > 0 & tar_p > 0 & `x' < 6 & `y' < 6 

			*ssc install heatplot
			*ssc install palettes, replace
			*ssc install colrspace, replace
			hexplot `y'  `x' `if', size  bins(25)  ///
				keylabels(1 5 10 15 20 25 30 35, transform(floor(@))  subtitle("#", margin(t=4)) ) /// 
				cut(1(1)@max) s(count)  addplot(lfit `y' `x' `if', lw(thick)) ///
				xtitle("Target RETech", size(medlarge) margin(t=10)) ///
				ytitle("Acquirer RETech", size(medlarge)) ///
				title("Number of sell-outs in each bin") ///
				ylabel(0(1)6, angle(horizontal) glcolor(p2%10)  labs(medium) ) ///
				xlabel(-1(1)6, angle(horizontal) glcolor(p2%10)  labs(medium) ) ///
				graphregion(color(white))
			graph export "output/tar_acq_RETech_matching_HEX.png", replace	 	
		
	}				
	////////////////////////////////
	// fig IA.2 - counterfactual RETech
	////////////////////////////////
	{
		use pnum ayear aqtr retech /*
			*/ if ayear >= 1920 /* just to speed things up...
			*/ using data/pat_lv, clear
		
		// load counterfactual RETech and winsorize as normal
		
		merge 1:1 pnum using data/auxilliary/RETech_fixedDelta_1960, keep(1 3) nogen
		foreach v in RETech_1960_Delta {	
			egen temp_lo = pctile(`v'), p(1) by(ayear)
			egen temp_hi = pctile(`v'), p(99) by(ayear)
			replace `v' = temp_hi if `v' > temp_hi & `v' != . 
			replace `v' = temp_lo if `v' < temp_lo & `v' != . 
			drop temp_lo temp_hi
		}
		
		// plot
		
		prep_for_ts_plot RETech_1960_Delta retech
		
		twoway  ///
			(line retech  aqtr           if year >= 1930, lpattern(solid) lwidth(medium) lcolor(black)) ///
			(line RETech_1960_Delta aqtr if year >= 1960, lpattern("..-") lwidth(thick) lcolor(red))  ///
			/// options
			, title("", color(black)) ytitle("") xtitle("") ///
			  legend(order (1 "All patents and words used" 2  "Cap annual # of words at 1960 level") rows(2) )  ///
			  tlabel(1930q1 (80) 2010q4 , format(%tqCY) labs(large) ) 	///			
			  ylabel(, angle(horizontal) glcolor(p2%10)  labs(large) format(%9.0g) ) ///
			  graphregion(color(white) lwidth(medium))
		graph export "output/retech_counterfactual.png", replace		 
	
	}
	////////////////////////////////
	// fig IA.4 - VX representativeness w.r.t Aggregate data
	////////////////////////////////
{
	// compare RETech of all patents to VC backed patents
		
		use pnum retech aqtr vxfirm_id vx_CompanyNation using data/pat_lv, clear

		preserve
			keep if vxfirm_id != . & vx_CompanyNation == "United States" 
			prep_for_ts_plot retech
			keep aqtr retech
			rename retech vc_retech
			tempfile vc_retech
			save `vc_retech'
		restore
			
		prep_for_ts_plot retech 
		merge 1:1 aqtr using `vc_retech', 

		local lineparts1 aqtr if year(dofq(aqtr)) >= 1980 & year(dofq(aqtr)) <= 2010, c(L) lp(dash)   lcolor(black) lw(thick) ms(i) mlab() mlabpos(9) mlabs(large) mlabc(black)
		local lineparts2 aqtr if year(dofq(aqtr)) >= 1980 & year(dofq(aqtr)) <= 2010, c(L) lp(solid)  lcolor(black) lw(thick) ms(i) mlab() mlabpos(3)  mlabs(large) mlabc(black)
		local graphoptions ytitle("") xtitle("")	tlabel(1980q1 (40) 2010q4 , format(%tqCY) labs(large) ) legend(off) ylabel(0(.5)2.5, angle(horizontal) glcolor(p2%10) format(%9.0g) labs(large)) graphregion(color(white) lwidth(medium))
		twoway (scatter retech     `lineparts1') ///
			   (scatter vc_retech  `lineparts2') ///
			   , title(""  , size( vlarge ))  `graphoptions' ///
					ttext(2.4 1998q1  "VC-Backed Patents", place(c) size(large)) ///
					ttext(0.85 1993q1  "All Patents", place(c) size(large))  
		graph display , ysize(4) xsize(8)
		graph export "output/RETech_VC_vs_all.png", replace		 
		
	// compare IPO and sell-out rates of VX's startups to aggregate 
	
		// exit rates within VX data 
		
		* note: The code below requires VentureExpert data. We include the 
		* code that uses it for completeness, and provide the intermediate file 
		* it create in the data/aux subfolder
		
		/*
		import delim using "$data\VentureExpertDataDump_All_V2.txt", delim(tab) clear	
		tostring resolvedate, replace
		g yr_qtr = qofd(date(resolvedate,"YMD"))	
		g vc_ipo_frac = companysituation == "Went Public"
		g vc_acq_frac = (companysituation == "Acquisition" | companysituation == "Merger" | companysituation == "Pending Acquisition")

		preserve
			import excel using "$data/VentureExpertDataDump_All_V2.xlsx", clear first
			keep VXFirm_ID CompanyNation 
			rename VXFirm_ID vxfirm_id
			keep if CompanyNation == "United States"
			tempfile vxfirm_id_if_US
			save `vxfirm_id_if_US', replace
		restore
		
		merge 1:1 vxfirm_id using `vxfirm_id_if_US', keep(3) // reduce to US only
		
		collapse (mean) vc_ipo_frac vc_acq_frac , by(yr_qtr)
		keep if year(dofq(yr_qtr)) >= 1980 & year(dofq(yr_qtr)) <= 2010
		line vc* yr_qtr
				
		save "temp/qtr vc_ipo_frac vc_acq_frac", replace
		*/
		
		// agg ipo and acq rates  
	
		u year qtr n_pubpri n_pripri  ipo_gross_gdp using "data/auxilliary/aggregate_series_year_qtr", clear
		g yr_qtr = qofd(mdy(qtr*3,1,year))
		format yr_qtr %tq
		merge 1:1 year qtr using "data/auxilliary/gdp_year_qtr", nogen // get gdp_real
		keep if year >= 1960
		tsset yr_qtr
		g n_deals_gdp_priv_target = (n_pubpri + n_pripri ) / L1.gdp_real
	
		// bring in the rates from VX data
	
		merge 1:1 yr_qtr using "data/auxilliary/qtr vc_ipo_frac vc_acq_frac"

		// prep to plot
		
		tsset yr_qtr
		foreach v in vc_ipo_frac vc_acq_frac n_deals_gdp_priv_target ipo_gross_gdp {
			tssmooth ma `v' = `v', window(4) replace
			replace `v' = `v' * 100 // % terms
		}		
	
		lab var ipo_gross_gdp              "Aggregate data (Left axis)"
		lab var n_deals_gdp_priv_target    "Aggregate data (Left axis)"
		lab var vc_ipo_frac                      "VC-backed private sample (Right axis)"
		lab var vc_acq_frac                      "VC-backed private sample (Right axis)"

		//////////////////////////////
		// unit change
		//////////////////////////////	
		
		replace ipo_gross_gdp = ipo_gross_gdp * 10 // now GDP is in billions
		replace n_deals_gdp_priv_target = n_deals_gdp_priv_target * 10 // now GDP is in billions
		replace vc_ipo_frac = vc_ipo_frac / 100 // decimals
		replace vc_acq_frac = vc_acq_frac / 100 // decimals

		twoway 	///
			(line vc_ipo_frac   yr_qtr if year >= 1980 & year <= 2010, tlabel( , format(%tqCY) labs(large) angle(horizontal) glcolor(p2%10) ) yaxis(1) ylabel(0 "0%" 1 "1%", axis(1) labs(large) angle(horizontal) glcolor(p2%10) ) lp(solid) lcolor(black) lw(thick)) ///
			(line ipo_gross_gdp yr_qtr if year >= 1980 & year <= 2010, tlabel( , format(%tqCY) labs(large) angle(horizontal) glcolor(p2%10) ) yaxis(2) ylabel(0(.035).035, axis(2) labs(large)angle(horizontal) glcolor(p2%10) ) lp(dash)  lcolor(black) lw(thick)) ///
			, title("IPO", size(vlarge)) xtitle("") legend(off) name(fig1, replace)  graphregion(color(white) lwidth(medium)) ///
			ytitle("Startups (Solid)", axis(1) size(large)) ytitle("Aggregate (Dashed)", axis(2) size(large)) 	
			
		twoway 	///
			(line vc_acq_frac             yr_qtr if year >= 1980 & year <= 2010, tlabel( , format(%tqCY) labs(large) angle(horizontal)) yaxis(1) ylabel(0 "0%" 1 "1%", axis(1) labs(large) angle(horizontal)) lp(solid) lcolor(black) lw(thick)) ///
			(line n_deals_gdp_priv_target yr_qtr if year >= 1980 & year <= 2010, tlabel( , format(%tqCY) labs(large) angle(horizontal)) yaxis(2) ylabel(0(.2).2, axis(2) labs(large) angle(horizontal)) lp(dash)  lcolor(black) lw(thick)) ///
			, title("Sell-Outs", size(vlarge)) xtitle("") legend(off) name(fig2, replace)  graphregion(color(white) lwidth(medium)) ///
			ytitle("Startups (Solid)", axis(1) size(large)) ytitle("Aggregate (Dashed)", axis(2) size(large)) 	

		graph combine  fig1 fig2 , rows(2)  graphregion(color(white) lwidth(medium))
		graph export "output/exits_VX_vs_agg.png", replace		 
}

