
/* put your citation pair data here. 

	our sample includes all citations made by Dec 31 2013 from one US utility 
	patent to another, and the variables are named:
		
		gives_cite_pnum   - pnum giving the citation
		gets_cite_pnum    - pnum getting the citation
*/	

	global all_cites_dta        "D:\data\Google Patent Grants\All Cites- US UTIL ONLY"

*======================================================================
* an XTILE function that doesn't die with big samples 
*======================================================================
	
	cap prog drop myxtile 
	prog def myxtile 
	syntax, val(varname) bygroup(varlist) Nquants(int) gen(name)
	/* CHANGES THE SORT ORDER */
	/* REPORTS AN XTILE EVEN IF ANY VARS IN "BYGROUP" ARE BLANK!  */
	qui {
		confirm new var `gen'
		tempvar N nless pctile

		sort `bygroup' `val'	/* CHANGES THE SORT ORDER */
			
		by `bygroup' (`val'): egen `N' = count(`val')
		by `bygroup' (`val'): g `nless' = (_n - 1) if (`val' != `val'[_n-1]) & `val' != .
		by `bygroup' (`val'): replace `nless' = `nless'[_n-1] if `nless' == . & `val' != .
		g `pctile' = `nless'/`N' + 0.000001* (mod(`nless'/`N',1/`nquants') == 0) // second term fixes beginning of bins: 0 perc -> bin 1, 50 perc -> bin 3 if quartiles
		g `gen' = ceil(`pctile'/(1/`nquants'))
		noi di as error "WARNING: myxtile changes the sort order!"
	}
	end	
	
*======================================================================
* get high and lo RETech patents (by app year, which is when they are scored)
* add a reference group of the middle deciles
*======================================================================
	
	use pnum ayear gyear retech using data/pat_lv, clear
	myxtile, val(retech) gen(dec_retech)   bygroup(ayear) n(10)
	tab dec // good
	keep if dec == 1 | dec == 10 | dec == 5 | dec == 6
	
	////////////////////////////////////////
	// the reference group is dec 5 AND 6 //
	////////////////////////////////////////
	
	replace dec = 5 if dec == 6
	
	keep if gyear >= 1930 & gyear <= 2000 // we have ten years of cites on both sides of that
	keep pnum dec
	save "temp/sample_focal_patents", replace
	
/*======================================================================
PART ONE

Build dataset whose observation level is a focal-future unit:

	focal_pnum 		- the sample of these is defined above
	future_pnum 	- cites either the focal or any backcite
	
with variables:

	dec_retech      - of focal patent
	event_time      = future_ayear - focal_gyear
	cites_b 		- boolean: does future cite ANY backcite patent
	cites_f 		- boolean: does future cite the focal patent
	only_cites_b
	only_cites_f
	subs            = {1 if only_cites_f, 0 if only_cites_b, -1 if cites both
	
----------------------------
	
PART TWO

collapse that into a dataset whose unit is decile-event_year unit:
	
	dec_retech
	event_time      = future_ayear - focal_gyear
	
with variables	
	
	cites_back      = fraction of future patents that cite the backcite patent
	cites_focal     = fraction of future patents that cite the focal patent
	only_cites_b    = fraction of future patents that only cite the backcite patent
	only_cites_f    = fraction of future patents that only cite the focal patent
	subs            = avg(subs) across the future patents
	
*=====================================================================*/
	
*======================================================================
* PART ONE
*======================================================================
{	
	use "$all_cites_dta", clear

	rename gives_cite_* focal_*
	rename gets_cite_* backcite_*
	
	* reduce to sample patents // save memory + speed
	
	rename focal_pnum pnum
	merge m:1 pnum using "temp/sample_focal_patents", keep(3) nogen 
	rename pnum focal_pnum

	drop dec_retech // save memory

	* find all patents that cited the focal patent
	
	preserve

		rename focal_pnum gets_cite_pnum
		merge m:m         gets_cite_pnum using "$all_cites_dta", keep(3) nogen keepusing(gives_cite_pnum)
		rename            gets_cite_pnum focal_pnum
		
		rename gives_cite_pnum future_pnum
		g cites_focal = 1
		
		*li 
		
		tempfile focal_back_future_cites
		save `focal_back_future_cites', replace
	
	restore
	
	* find all patents that cited the backcite patent (which includes the focal!)
	
	rename backcite_pnum gets_cite_pnum
	merge m:m            gets_cite_pnum using "$all_cites_dta", keep(3) nogen keepusing(gives_cite_pnum)
	rename               gets_cite_pnum backcite_pnum
	
	rename gives_cite_pnum future_pnum
	drop if future_pnum == focal_pnum 
	g cites_back = 1
		
	* combine with the patents that cited the focal patent
	
	append using `focal_back_future_cites', force
	
	order focal_pnum future_pnum  backcite_pnum
	sort focal_pnum future_pnum  backcite_pnum    // take a look...
	
	* for each focal  (collapse to focal)
	* sum over each future (so collapse to focal-future)

	collapse (sum) cites_*, by(focal_pnum future_pnum)
	replace cites_back  = 1 if cites_back > 1
	replace cites_focal = 1 if cites_focal > 1
		
	g only_cites_b  =   cites_back &  !cites_focal
	g only_cites_f  =  !cites_back &   cites_focal
	g subs          = -2*cites_back*cites_focal + cites_focal	
	
	* add in other needed variables
	
	// decile
	
	rename focal_pnum pnum
	merge m:1 pnum using "temp/sample_focal_patents", keep(3) nogen 
	rename pnum focal_pnum
	
	// use this to create diff splits below (optional)
	
*save "temp/partway", replace	

	// event_time = future_gyear - focal_gyear (when it goes public and can impact others) 

*use "temp/partway", replace	
	
	rename focal_pnum pnum
	merge m:1 pnum using data/pat_lv, keep(3) nogen keepusing(gyear)
	rename pnum focal_pnum
	rename gyear focal_gyear
	
	rename future_pnum pnum
	merge m:1 pnum using data/pat_lv, keep(3) nogen keepusing(gyear)
	// we loss 0.01% of future patents which aren't in the bfh data
	rename pnum future_pnum
	rename gyear future_gyear
	
	g event_time = future_gyear - focal_gyear
	drop focal_gyear future_gyear
	drop if event_time < -1 | event_time > 10 // before -1, all patents are to back only by definition
	tab event_time
	mdesc	
	
	// might as well have this 
	
	g cites_both    =   cites_back &   cites_focal	
	
	// checks 
	
	tab cites_back cites_focal
	tab only_cites_b
	tab only_cites_f
	tab cites_both
	tab only_cites_b subs
	tab only_cites_f subs
	tab cites_both subs
	
	/* perfect */
	
*======================================================================
* PART TWO
*======================================================================
	
	collapse (mean) cites_back cites_focal only_cites_b only_cites_f subs cites_both  ///
		, by(dec_retech event_time)
	
	save "temp/plotme", replace
}	

	li 
	tab dec
	
*======================================================================
* make the plot
*======================================================================
	
	use "temp/plotme", clear

	drop if event <= 0
	
	keep d e cites_both only_cites_f
	rename cites_both cites_both
	rename only_cites_f only_cites_f
	reshape wide cites_both only_cites_f, i(event) j(dec)
	
	g relative_comp_hiret_all =  cites_both10 / cites_both5 - 1
	g relative_sub_hiret_all  =  only_cites_f10 / only_cites_f5 - 1

	g relative_comp_loret_all =  cites_both1 / cites_both5 - 1
	g relative_sub_loret_all  =  only_cites_f1 / only_cites_f5 - 1
	
	merge 1:1 e using `bothbacks'
	
	keep e rel*
	
	line  relative_sub_hiret_all     relative_sub_loret_all  event, ///
		 lc(red black)	lp(solid solid -  - ) ///
		graphregion(color(white) lwidth(medium))  ///
		xlabel(1(1)10, labsize(*1.1))  ///
		yscale(range(-.12 .32)) ///
		xtitle("Years since focal patent's grant", margin(t=4) size(medlarge)) ///	
		ylabel( -.1 "-10" 0 "0" .1 "10" .2 "20" .3 "+30%" , labsize(*1.1) angle(horizontal) glcolor(p2%10) ) ///
		ytitle("Relative to middle decile patents", margin(r=4) size(medlarge)) ///
		legend(off) ///
		text(.24 7 "Top RETech decile", size(*1.1) color(red)) ///
		text(-.05 7 "Bottom RETech decile", size(*1.1)) 
	graph display , ysize(4) xsize(7)
	graph export "output/RETech-subs.png", replace	
	
	line  relative_comp_hiret_all     relative_comp_loret_all  event, ///
		 lc(red black)	lp(solid solid -  - ) ///
		graphregion(color(white) lwidth(medium))  ///
		xlabel(1(1)10, labsize(*1.1))  ///
		yscale(range(-.32 .32)) ///
		xtitle("Years since focal patent's grant", margin(t=4) size(medlarge)) ///	
		ylabel( -.3 "-30" -.2 "-20" -.1 "-10" 0 "0" .1 "10" .2 "20" .3 "+30%" , labsize(*1.1) angle(horizontal) glcolor(p2%10) ) ///
		ytitle("Relative to middle decile patents", margin(r=4) size(medlarge)) ///
		legend(off) ///
		text(-.25 7 "Top RETech decile", size(*1.1) color(red)) ///
		text(.25 7 "Bottom RETech decile", size(*1.1)) 
	graph display , ysize(4) xsize(7)
	graph export "output/RETech-comp.png", replace	
	
