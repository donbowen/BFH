cap prog drop esttab_to_excel_sheet
prog def esttab_to_excel_sheet
syntax using, sheet_name(string) esttab_options(string) temp_csv(string) [notes(string)]
/*
DESCRIPTION: 
A wrapper for esttab that will put the results into a sheet of an
Excel file. 

For some reason I'm not spending the time to discover, esttab's option
addnotes("Note 1" "Note 2" "Note 3") doesn't work properly. Thus, I coded 
additional functionality (the notes option) to allow the user to add notes. 

CHANGE LOG:

	v2 allows for notes longer than the table.

USAGE:
	[run pre- esttab commands]
	esttab_to_excel_sheet using "hey.xlsx", ///
		sheet_name("sheet1") ///
		temp_csv_filename("temp12345.csv") ///
		esttab_options( star(* 0.10 ** 0.05 *** 0.01 ) label ) ///	
		notes(`""Note 1" "Note 2""')
	
INPUT NOTES:
	using            Must end in ".xlsx"
	sheet_name       String name valid for Excel sheet name
	esttab_options   Any valid esttab options. Do not use addnotes() - weird behavior
	temp_csv         File name. Must end in ".csv". 
	notes            Optional notes. To get multiple notes, encase each in 
	                 quotes, and the whole set of notes in compound quotes.
					 For example: `""Note 1" "Note 2""'
*/
qui {
	noi esttab, `esttab_options' // show the user the results

	cap erase "`temp_csv'"
	esttab using "`temp_csv'", `esttab_options' // save a temp file

	preserve 
		import delimited using "`temp_csv'" /// open the temp file
		, clear delim(",=",collapse) bindq(strict) stripq(yes)
		
		// these lines add notes in column 1 (which is blank), 
		// because esttab in this setting handles multiple notes weirdly
		tostring v1, replace
		replace v1 = ""
		replace v1 = "NOTES:" in 1
		local i = 2
		foreach part in `notes' {
			if _N < `i' set obs `i' // add extra rows if 
			replace v1 = "`part'" in `i'
			local i = `i' + 1			
		}		

		cap export excel `using', sheet("`sheet_name'") sheetreplace // save to excel sheet 
	restore
	
	erase "`temp_csv'" // delete temp file
}
end
