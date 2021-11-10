/* 

To use this file, put a Stata file containing these variables from the raw 
venture expert company-level data in your data folder: 

	VARNAME IN OUR CODE        DESCRIPT/NAME IN VENTURE EXPERT
	============================================================
	vxfirm_id                  unique company level identifier
	resolvedate                ResolveDate  or "Company Current Situation Date"
	companysituat~n            CompanySituation or "Company Current Situation"
	founddate                  "Company Founding Date"
	firstvcfunddate            FirstVCFundDate "Date Company Received First Investment" 
	lastvcfunddate             LastVCFundDate "Date Company Received Last Investment"
	vcrounds                   VCRounds "No. of Rounds Company Rcvd"
	vxindgrpmajor              VXIndGrpMajor "Company Industry Major Group"
	CompanyName                
	CompanyStateCode           2 digits, eg "CA" 
	CompanyNation              
	CompanyZipCode      
	
	put the path to this file after "global VX_firm_data"
	
Additionally, from the Venture Expert round-by-round funding data, create a 
firm-qtr level dataset that contains these variables:

	VARNAME IN OUR CODE        DESCRIPT/NAME IN VENTURE EXPERT
	============================================================
	vxfirm_id                  unique company level identifier
	qtr                        qtr of the RoundDate variable
	flowVCfund                 sum(RoundAmount)
	
		where, before creating flowVCfund, set 
		RoundAmount = .01 if RoundAmount < 0 | RoundAmount == .
		0.01 is a negligible amount (since its unknown), but will preserve 
		record of round existing (as opposed to dropping these)
		
	put the path to this file after "global vx_funding_rounds"
	
*/

	// user inputs 

	global VX_firm_data         ""   // set to your file name (and path to it)
	global vx_funding_rounds    ""   // set to your file name (and path to it)


********************************************************************************
*
*	Build a quarterly sample of vc-backed private firms
*
*	Sample: 1970-2017, US firms only, manually code firms as failing if they go 
*	7 years without VC funding
*		1970s kept for use as modeling years
*  	 	2011-2017 have incomplete (or no, depending on the stat) patent info,  
*   	but are kept for look ahead info on firm outcomes
*
*	Patent vars are winsorized at patent level; are based on app date (NOT grant)
*
********************************************************************************

*** PREP - build component files from the patent level data

tempfile vxfirm_qtr_panel_patstocks    vxfirm_modal_nber     patenting_startups

{
*** GET FIRM PANEL OF ~~~stock~~~ VARIABLES
{
	use if vxfirm_id != . using ../data/pat_lv, clear
	format aqtr %tq	
	drop if year(appdate) < 1970 // keep some pre-1980 years to build stock vars 
		
	global stats_to_stock retech tech_breadth sim_li sim_priv sim_foreign /*
	*/ retech_new retech_estab adj_originality_nber adj_generality_2017PView /*
	*/ num_claims scope l_cite
		

	keep vxfirm_id aqtr pnum $stats_to_stock
	
	/* THIS ALGORITHM HAS AN EXAMPLE SCRIPT SHOWING IT WORKS
	"PROOF-the patent weighted pat stock calc is right.do" */
		// the key difference is SUM the stats and divide the deprec stock by the # of patents in the given years

	collapse (sum) $stats_to_stock (count) pnum_qtr = pnum , by(vxfirm_id aqtr)
	xtset vxfirm_id aqtr
	
	// add a new later date, so that the last period of patent carries forward the stock variable...
	bysort vxfirm_id (aqtr): g expand = 1 + (_n==_N)
	expand expand
	bysort vxfirm_id (aqtr): replace aqtr = aqtr[_n-1]+20	if _n == _N
	drop expand
	
	// elim all vars from the new fake year
	foreach v in pnum_qtr $stats_to_stock {
		bysort vxfirm_id (aqtr): replace `v' = 0 if _n == _N
	}
	
	xtset vxfirm_id aqtr	
	tsfill // so that gaps get running stocks

	global d = .95 // =(1-depreciation) --> depreciation = .05 PER QUARTER
	
	foreach v in pnum_qtr $stats_to_stock {
		// copy lagged values into a given row and set non-existant to 0 (so they can be summed)
		forval lag = 0/19 {
			by vxfirm_id (aqtr): g `v'_`lag' = L`lag'.`v'
			replace `v'_`lag' = 0 if `v'_`lag' == .
		}
		
		drop `v'
		
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
			
	rename aqtr qtr
	rename running_pnum pnum_count_last_20_qtrs
	lab var pnum_count_last_20_qtrs "Count from [t-19,t] (qtrs)"
	drop if vxfirm_id == . 
		
	lab var tech_breadt "Tech Breadth"
	lab var sim_li_stoc "LI Similarity"
	lab var sim_priv_st "Private Similarity"
	lab var sim_foreign "Foreign Similarity"
	lab var retech_stoc "RETech"
	lab var retech_new_ "RETech(New)"
	lab var retech_esta "RETech(Established)"
	lab var adj_origina "Originality"
	lab var l_cite_stoc "Log(1+Cites)"
	lab var scope_stock "Scope"
	lab var num_claims_ "NumClaims"
	lab var adj_general "adj_generality_2017PView stock: [t-19,t] (5% qtly depr)"
	
	drop pnum_qtr_stock
	lab var pnum_count_last_20_qtrs "Count from [t-19,t] (qtrs)"
	
	save `vxfirm_qtr_panel_patstocks', replace	
}	
*** GET FIRM TECH CATEGORY FROM PATENTS 
{
	use vxfirm_id nber if vxfirm_id != . using ../data/pat_lv, clear
	egen nber_vx_cat = mode(nber), minmode by(vxfirm_id)
	drop nber
	duplicates drop *, force
	duplicates report vx
	lab var nber_vx_cat "Firm's modal NBER Tech Category"
	save `vxfirm_modal_nber', replace
}
*** get list of patenting startups, (to restrict startup sample)

	use vxfirm_id if vxfirm_id != . using ../data/pat_lv, clear
	duplicates drop *, force	
	keep vxfirm_id
	save `patenting_startups'

}
	
*** CREATE VX FIRM PANEL, 
*** Sample requires both founddate and resolvedate
*** from year(founddate ) to year(resolvedate)
{
	
	/////////////////////////////////////////////////////
	// load startup level data and deal with date vars
	/////////////////////////////////////////////////////
	
		use "$VX_firm_data", clear
		
		tostring founddate, replace
		tostring resolvedate, replace
		tostring firstvcfund, replace

		g first_qtr   = qofd(date(founddate,"YMD"))
		g last_qtr    = qofd(date(resolvedate,"YMD"))	
		g vc_fund_qtr = qofd(date(firstvcfund,"YMD"))
		
		drop firstvcfund
	
		format *qtr %tq
		
	// fix issue: active firms don't have "resolvedate" and thus no "last_year"	
		replace last_qtr = 230 if last_qtr == . & companysituation == "Active" // 6953 vxfirm changed
		tab company if last_qtr == .
	
	// first issue: first two year digits messed up sometimes	
		replace first = first - 1800*4 if year(dofq(first)) >= 3700 // so "3793" becomes "1993" , 59 vxfirm changed
		replace first = first - 1700*4 if year(dofq(first)) < 3700 & year(dofq(first)) >= 3600 // so "3650" becomes "1950" , 1 vxfirm changed
	
	// fix issue: drop firms where last year is before first year, or without 	// start/end dates
		g n_qtrs = last_qtr - first + 1
		drop if n_qtrs < 0 | n_qtrs == . // ***      vxfirms dropped! would be nice to have them... ***		
		
	// sample restrictions 
		merge 1:1 vxfirm_id using `patenting_startups', keep(3) nogen // reduce to patenting firms
		keep if CompanyNation == "United States"
		drop if year(dofq(first)) > 2010				
	
	// bring in firm level tech category
		merge m:1 vxfirm_id using `vxfirm_modal_nber', keep(1 3)
		drop _m
	
	// clean up the state var
		g state = CompanyState
		replace state = "INTL" if CompanyNation != "United States" | "UN" == CompanyState
		distinct state // 52 = 50 states + DC + INTL
		encode state, g(state_FE)		
	
	/////////////////////////////////////////////////////
	// make into a firm panel (startup-qtr)	
	/////////////////////////////////////////////////////
	
		expand n_qtrs
		bysort vxfirm_id:       g qtr          = first_qtr + _n - 1 	
		drop n_qtrs
		format qtr %tq
			
		drop if year(dofq(qtr)) < 1970 // keep the 1970-1980 years for early sample prediction modelling
		
	// create some time vars 
	
		bysort vxfirm_id (qtr): g firm_age_qtr = _n - 1		// starts at 0

		g year       = year(dofq(qtr))		
		g l_firm_age = log(1+firm_age)	
		
		merge m:1 qtr using ../data/auxilliary/qtr_macro, keep(1 3) nogen ///
			keepusing(L2_l_mtb1 q4 pastMTKreturn_asdeci)
	
	/////////////////////////////////////////////////////
	// time varying variables at startup-qtr level
	/////////////////////////////////////////////////////
	
	// bring in firm-qtr vars...			
		merge 1:1 vxfirm_id qtr using `vxfirm_qtr_panel_patstocks', keep(1 3) nogen
	
	// what to do with qtrs without patenting stats (because no patents in last 20 quarters?
		replace pnum_count_last_20_qtrs = 0 if pnum_count_last_20_qtrs == .
		foreach v of varlist *_stock {
			replace `v' = 0 if pnum_count_last_20_qtrs == 0
		}
		g l_pats_last_20qtr  = log(1+pnum_count_last_20_qtrs)
		g noPatsLast5yrs = pnum_count_last_20_qtrs == 0

	// make sure no patent variables are defined when they shouldn't/can't be	
		sum if year(dofq(qtr)) > 2010	// tech stocks invalid after 2010 
		foreach v of varlist pnum_count_last_20_qtrs - l_pats_last_20qtr {
			replace `v' = . if year(dofq(qtr)) > 2010
		}
		sum if year(dofq(qtr)) > 2010	
	
	// put outcome indicators in the last observation for a firm
		bysort vxfirm_id (qtr): g b_ipo     = _n == _N & companysituation == "Went Public"
		bysort vxfirm_id (qtr): g b_lbo     = _n == _N & companysituation == "LBO"
		bysort vxfirm_id (qtr): g b_active  = _n == _N & companysituation == "Active"
		bysort vxfirm_id (qtr): g b_acq     = _n == _N & (companysituation == "Acquisition" | companysituation == "Merger" | companysituation == "Pending Acq")
		bysort vxfirm_id (qtr): g b_fail    = _n == _N & (companysituation == "Bankruptcy" | companysituation == "Defunct")

	/* chance of an event in [t,t+k]	
		xtset vxfirm_id qtr
		qui foreach v of varlist b_ipo b_acq b_fail b_active b_lbo {
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
	*/
			
	// bring in time varying data on funding	
	
		// this data is:
		// vxfirm_id qtr sum(RoundA), 
		// where RoundA = .01 if RoundA < 0 | RoundA == .
		// 0.01 is a negligible amount (since its unknown), but will preserve 
		// record of round existing (as opposed to dropping these)
		merge 1:1 vxfirm_id qtr using "$vx_funding_rounds", keep(1 3) nogen
		bysort vxfirm_id (qtr): g cum_VC_fund = sum(flowVCfund)
		
		g l_cum_VC_fund = log(1+cum_VC_fund)
		g cum_VC_fund_zero = cum_VC_fund == 0				
		
		g t = qtr < vc_fund_qtr
		tab t cum_VC_fund_z // the first round sometimes has "zero" funds... 
		drop t
		replace  cum_VC_fund_zero = qtr < vc_fund_qtr		

	/////////////////////////////////////////////////////
	// Now, impose that firms die when they go 7 years without extra rounds
	/////////////////////////////////////////////////////
		
	global maxage = 50 // 50 years... effectively no max age, coded here to allow for robustness tests 
	global failIfNotFundedInLast = 7 // years 
	
	/*	
	we want new outcome vars:

			t_q1_to_q#_b_X    
			
	where # = {1, 4, 8, 12, 16, 20} and X = 

		fail2           if no VC funds raised in prior 5 years
		priv2           if VC funds raised in prior 5 years
		ipo2            = b_ipo but some will be recoded as fail2 and priv2
		acq2            = b_acq but some will be recoded as fail2 and priv2
	*/		
		
	g qtr_since_first_vc = qtr - vc_fund_qtr
		
	// drop obs if a firm is "too old"
	
		keep if (qtr_since_first_vc <= 4*$maxage) // firms not resolved within 10 years after first vc	
		/* if we want to keep the whole sample, then move this as extra boolean in b_ipo and t_q1_to_q variable sections.... */
	
		*drop b_ipo b_lbo b_active b_acq b_fail l_rounds
	
	// define time since last VC round
		g vcround_thisqtr = 	flowVCfund != . & flowVCfund > 0 // helper vars
		bysort vxfirm_id (qtr): g vcrounds_bynow = sum(vcround_thisqtr) // helper vars to define time elapsed
		
		g qtr_since_last_vc_round = 999*(vcrounds_bynow == 0) // a high number (will change to missing later) if we've had none, 0 else
		bysort vxfirm_id (qtr): replace qtr_since_last_vc_round = /// increment if we've not raised funds since the last round
			qtr_since_last_vc_round[_n-1]+1 if (vcround_thisqtr == 0 & vcrounds_bynow >= 1) // 
		replace qtr_since_last_vc_round = . if qtr_since_last_vc_round == 999 // set as undefined

		drop vcround_thisqtr vcrounds_bynow
		
	// drop obs after firm has "failed" by going a length of time without new rounds
	
		drop if (qtr_since_last_vc_round > 4*$failIfNotFundedInLast & qtr_since_last_vc_round != . )
				
	// overwrite the fail variable for the 			
				
		drop b_fail
		bysort vxfirm_id (qtr): g b_fail = (_n == _N) & (qtr_since_last_vc_round == 4*$failIfNotFundedInLast) ///
				& b_ipo == 0 & b_acq == 0 & b_lbo == 0 
				
		drop b_active		
		bysort vxfirm_id (qtr): g b_active  = _n == _N & (b_fail==0 & b_ipo==0 & b_acq == 0)
		
		
	// drop firms we CAN'T CLASSIFY (not explicit ipo, acq, failure, and no adtl funding info)
	
		// need a temp var first
		g temp = qtr_since_last_vc_round == .
		egen missing_lag_info = sum(temp), by(vxfirm_id)
		bysort vxfirm_id (qtr): g obs = _N
		g no_lag_info = obs == missing_lag_info  // can't distinguish failure based on VC funding lag time (no vc fund TIMING info)
		drop temp missing_lag_info obs 

		* total firms		
		distinct vxfirm_id
		* firms we can classify (works in all obs for the firm)
		distinct vxfirm_id if companysituation == "Went Public" /*
					*/ | (companysituation == "Acquisition" | companysituation == "Merger" | companysituation == "Pending Acq") /*
					*/ | (companysituation == "Bankruptcy" | companysituation == "Defunct") /*
					*/ | no_lag_info == 0
		* firms we can NOT classify (not explicit ipo, acq, failure, and no adtl funding info					
		distinct vxfirm_id if ~(companysituation == "Went Public" /*
					*/ | (companysituation == "Acquisition" | companysituation == "Merger" | companysituation == "Pending Acq") /*
					*/ | (companysituation == "Bankruptcy" | companysituation == "Defunct") /*
					*/ | no_lag_info == 0)
		drop if ~(companysituation == "Went Public" /*
					*/ | (companysituation == "Acquisition" | companysituation == "Merger" | companysituation == "Pending Acq") /*
					*/ | (companysituation == "Bankruptcy" | companysituation == "Defunct") /*
					*/ | no_lag_info == 0)
						
	// chance of an event in [t,t+k]	
			
		xtset vxfirm_id qtr
		qui foreach v of varlist b_ipo b_acq  {
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
		
	/////////////////////////////////////////////////////
	// Output
	/////////////////////////////////////////////////////

		drop cum_VC_fund CompanyStateCode CompanyNation founddate no_lag_info /*
		*/ resolvedate qtr_since_last_vc_round companysituation vcrounds /*
		*/ lastvcfunddate CompanyName last_qtr CompanyZipCode qtr_since_first_vc 
		
		* vxfirm_id qtr latestLead_vc_index myVCsMktshare
		
		order vxfirm_id qtr  first_qtr vc_fund_qtr firm_age_qtr b_ipo b_lbo b_acq pnum_count_last_20_qtrs tech_breadth_stock sim_li_stock sim_priv_stock sim_foreign_stock retech_stock retech_new_stock retech_estab_stock adj_originality_nber_stock l_pats_last_20qtr pastMTKreturn_asdeci q4 L2_l_mtb1 vxindgrpmajor noPatsLast5yrs l_firm_age nber_vx_cat flowVCfund l_cum_VC_fund cum_VC_fund_zero state state_FE l_cite_stock year b_fail b_active t_q1_to_q1_b_ipo t_q1_to_q4_b_ipo t_q1_to_q8_b_ipo t_q1_to_q12_b_ipo t_q1_to_q16_b_ipo t_q1_to_q20_b_ipo t_q1_to_q1_b_acq t_q1_to_q4_b_acq t_q1_to_q8_b_acq t_q1_to_q12_b_acq t_q1_to_q16_b_acq t_q1_to_q20_b_acq scope_stock num_claims_stock adj_generality_2017PView_stock
	
		lab var first_qtr                      "Founding date (QTR)"
		lab var vc_fund_qtr                    "First VC funding date (QTR)"
		lab var l_firm_age                     "Log(1+firm_age)"
		lab var l_pats_last_20qtr              "Log(1+pnum_count_last_20_qtr)"
		lab var noPatsLast5yrs                 "No PatApps in 5 years"
		lab var firm_age_qtr    	           "Firm Age (QTRs), Starts at 0"		
		lab var retech_stock                   "RETech"
		lab var retech_estab_stock             "RETech(Established)"
		lab var retech_new_stock               "RETech(New)"
		lab var tech_breadth_stock             "Tech Breadth"
		lab var sim_li_stock                   "LI Similarity"
		lab var sim_priv_stock                 "Private Similarity"
		lab var sim_foreign_stock              "Foreign Similarity"
		lab var scope_stock                    "Scope"
		lab var num_claims_stock               "NumClaims" 
		lab var l_cite_stock		           "Log(1+Cites)"
		lab var adj_originality_nber_stock     "Originality"
		lab var q4 					           "Q4"
		lab var L2_l_mtb1			           "Log(MTB) (q-2)"
		lab var l_pats_last_20qtr 	           "Log(1+PatApps[q-1,q-20])"
		lab var pastMTKreturn_asdeci           "MKT Return [q-2,q-1]"
		lab var l_firm_age  		           "Log(1+Firm Age)"
		lab var noPatsLast5 		           "No PatApps[q-1,q-20]"
		lab var cum_VC_fund_zero			   "No Funding"
		lab var l_cum_VC_fund                  "Log(1+Cumulative VC funds)"
		lab var year                           "Year"
		*lab var latestLead_vc_index            "Index of lead VC on most recent round"
		*lab var myVCsMktshare                  "VC market share"
			
		compress
		
	save startup_qtr_panel, 	
}	
