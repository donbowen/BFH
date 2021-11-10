* this is here to show how we built RETech_tilde_stock.dta 
		
	////////////////////////////////
	// prep lawyer data - first lawyer per pat, only util 
	////////////////////////////////

		// rawlawyer.tsv is from patentsview 
	
	/*
		import delim rawlawyer.tsv, clear varn(1)
		keep if seq == 0                 // first lawyer per pat (seq starts at 0)
		drop if regexm(pat,"[A-Za-z]")   // util pats only
		keep patent_id lawyer_id         // a few cleaning steps...
		destring pat, replace
		rename pat pnum
		save "temp/pat_lawyer", replace
	*/
	
	////////////////////////////////
	// remove lawyer FE from patent-level RETech
	////////////////////////////////
	
		use data/pat_lv, clear
		merge 1:1 pnum using  "temp/pat_lawyer", keep(1 3)
		keep if ayear >= 1976
		
		////////////////////////////
		replace lawyer_id = "FILL_IN_LEVEL_DROP" if lawyer_id == "" // treat all non-lawyer patents equallty
		////////////////////////////
		
		reghdfe retech , absorb(lawyer_id) resid(e_retech_lawyer)
		
		// to get from this residual to a startup-quarter variable, we will take stocks
		// but the resid is mean zero with half of patents having negative value
		// so the logic of depreciating stocks won't work. solution: add back the mean
		
		qui sum retech, meanonly
		local sflu_mean `r(mean)'
		qui sum e_retech_lawyer, meanonly
		local e_mean `r(mean)'
		
		g e_retech_meanadj = e_retech_lawyer - `e_mean' + `sflu_mean' 
		
		global stats_to_stock e_retech_meanadj 
		
		drop if ayear < 1970 // not needed for firm qtr traits!
		drop if ayear > 2010 // not needed for firm qtr traits!
		drop if vxfirm_id == .

		// this remaining code is copy-paste:	
					
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
		
		drop if year(dofq(qtr)) < 1970 // keep the 1970-1980 years for early sample prediction modelling
		
		// there are many observations in the input panel that need to be added
		// the stock vars are 0 for these
		
		merge 1:1 vxfirm_id qtr using data/startup_qtr_panel, keepusing(q4 ) keep(2 3) // expand the panel
		foreach v of varlist *_stock {
			replace `v' = 0 if _m == 2 
		}
		drop _m q4
		foreach v of varlist *_stock {
			replace `v' = 0 if pnum_count_last_20_qtrs == 0
		}
		
		// and patent vars must be blank after 2010
		
		sum if year(dofq(qtr)) > 2010	
		foreach v of varlist pnum_count_last_20_qtrs *stock {
			replace `v' = . if year(dofq(qtr)) > 2010
		}		
		
		keep qtr vxf e_* 
		save data/auxiliarry/RETech_tilde_stock, replace
