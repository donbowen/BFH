
capture program drop winsorby
program define winsorby
	syntax varlist(min=1 numeric) ,  [ by(varlist)  p(real 0.01) ]
	* Examples:
	*
	* winsorby varlist
	* winsorby varlist, by(year)
	* winsorby varlist, p(0.05)
	* winsorby varlist, by(year) p(0.05)
	*
	* If by() is not specified, winsorizes over all observations.
	* This winsorizes by percentile tails (for now).
	*
	* If p() not specified, 1% tails assumed. P must strictly be between 0 and 0.5
	*
	* AUTOMATICALLY GENERATES NEW WINSORIZED VERSION, NAMED WITH "w_" IN FRONT!!!!!!!!!
	* 		E.g. CALLING winsor return YIELDS A NEW VARIABLE called "w_return".
	*
	****************************************************************************
	****************************************************************************
	*
	*	IMPORTANT IMPORTANT IMPORTANT IMPORTANT IMPORTANT IMPORTANT IMPORTANT
	*
	* NOTE: Winsor requires there to be enough non-missing observations to fully
	* ascribe percentile cutoffs. E.g. if 1%, it requires 100 obs, 2% -> 50 obs,
	* 5% -> 20 obs.
	*
	* If a group has fewer non-missing observations than winsor requires, the
	* UNALTERED observations are returned!!!!!
	*
	****************************************************************************
	****************************************************************************
	
	display "varlist now contains |`varlist'|"
	display "byvars now contains |`by'|"
	display "p now contains |`p'|"
	if `p' < 0 | `p' > .5 {
		display "ERROR: p() must be between 0 and 0.5"
		ERROR
	}
	
	tempvar group
	egen `group' = group(`by')
	foreach v of varlist `varlist' {
		gen w_`v' = .
		qui su `group', meanonly
		di "Winsoring `v' across `r(max)' groups"
		forval i  = 1/`r(max)' {
			capture { 
				winsor `v' if `group' == `i', gen(temp) p(`p')		
				replace w_`v' = temp if `group' == `i'
				drop temp
			}
			if _rc != 0 {
				/* If winsor is asked to winsor at 1%, it wants 100 obs, else
				it errors. If 2%, it wants 50 obs. If 5%, it wants 20 obs. Get it?
				Anyways, if a group is too small for winsor - we'll just return the group.
				*/
				replace w_`v' = `v' if `group' == `i'
			}
		}
	}

end







