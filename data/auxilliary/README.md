Note: vxfirm_id is a startup-level identifier we constructed to uniquely index startups in VentureExpert.

=========================================================================

aggregate_series_year_qtr.dta

	We restrict the full SDC sample of mergers to completed US-US deals where the acquirer takes 50% or more control; we ignore privatizations, acquisitions of partial or remaining interest, buybacks, recaps, exchange offers, spinoffs. From these, we count the number of deals in a quarter based on the public status of the acq/tar (does SDC have a ticker for the firm). The volume of IPOs comes from Jay Ritter, and "ipo_gross_gdp" normalizes the quarterly amount with lagged real GDP.
	
gdp_year_qtr.dta

	Real GDP from FRED. 

kellytable.dta

	Table A.6 from Kelly, Papanikolaou, Seru and Taddy. Measuring technological innovation over the long run. American Economic Review, Insights, Forthcoming.
	
qtrs_of_bank_fin.dta

	We matched our startups to DealScan using a fuzzy name match score, and then had RAs manually verify matches. This dataset contains the quarter, amount of finance, and sales of the startup for any bank financing deals for startups.

bankfinancing_firstdealdate.dta

	The first qtr a startup gets bank financing. 

RETech_fixedDelta_1960.dta

	Used in Figure IA.2. Counterfactual patent-level RETech is computed by keeping, for each year t, 492,240 randomly drawn words from year t's Delta vector. This ensures that the size of the wordspace after 1960 on remains constant. Then, a patent's counterfactual RETech is computed using ONLY this subset of words. Finally, we compute startup-quarterly stocks as before. 

RETech_tilde_stock.dta

	A startup-quarter dataset computed from the patent-level data for Table IA.2. See subroutines/RETech_tilde_stock.do for the code used to create it. 

tar_acq_matched_sample.dta

	Subset of SDC mergers where the target was a startup in our sample and the acquirer was a public firm. We merge in the startup's RETech and patent stock for the announcement quarter. Finally, we create quarterly patent stocks for public firms from the patent-level data using the same stocking function and merge in their stocks for the announcement quarter.

vxfirm_id finbuyer.dta

	List of acquired startups matched to the SDC merger data, where the acquisition technique was listed as "Financial Acquiror".

vxfirm_id small_sellout.dta

	Contains a list of vxfirm_id we could match to sell-out valuations. small_sellout equals one for those under $25m in 2009 dollars, and zero else. 

qtr vc_ipo_frac vc_acq_frac.dta

	Constructed in bfh_analysis.do from VentureExpert data. 
