# RETech is "Rapidly Evolving Technology"

This folder produces a replication of Rapidly Evolving Technologies and Startup Exits ([SSRN link](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3245839)) by [Donald Bowen](https://bowen.finance), [Gerard Hoberg](http://www-bcf.usc.edu/~hoberg/), and [Laurent Fresard](https://people.lu.usi.ch/fresal/), which is forthcoming in Management Science. _Please cite that study when using or referring to any data or code in this repository._ 

---

<p align="center"> :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star:  
	<br> <br> 
	<b> Most visitors of this page just want a patent-level dataset with RETech. </b>
	<br><br>   <a href="https://github.com/donbowen/Patent-Text-Variables"><b>If so, follow this link, which covers patents granted through last year!</b></a>
	<br> <br> :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star: :star:   
</p>

---

Please see the paper for details on the construction of the samples and measures. Questions can be directed to Donald Bowen, and pointers to errors or omissions, and corrections are welcome. 	

	
## Replication, plus data on patents and startups  

Replication requires three principle files:	
1. Stata code (`bfh_analysis.do`) to reproduce all tables and figures in the paper. 
	- This uses the two key datasets described next plus some less important datasets in the "auxilliary" data subfolder and code in the subroutines folder. Results are stored in the output folder. [Click me to download everything you need to replicate the paper!](https://github.com/donbowen/BFH/archive/refs/heads/main.zip) 
	- All estimation results are stored in one excel file (`output/bfh-tables.xlsx`) via a hacky (but useful!) Stata command. Doing it this way reduces file clutter and lets us quickly change formatting choices while writing the paper. A nice trick!
2. Patent-level data with patents applied for between 1930 and 2010 and granted by 2013 **with many variables of interest, including a link to the startup**. 
	- _This is not the raw data:_ All patent level variables are winsorized at the 1/99% level annually. The citation and KPSS variables are winsorized by grant year, and the remaining variables are winsorized by application year. If you are interested in raw data, please follow the big link above to the updated patent data files. 
	- Because `pat_lv.dta` is **1.3GB**, it's not stored here. You can download it by (A) [Clicking this link](https://www.dropbox.com/s/xvr09mqayfz7akd/pat_lv.dta?dl=1) or (B) [Downloading this folder to your computer](https://github.com/donbowen/BFH/archive/refs/heads/main.zip) and running `bfh_analysis.do`, which starts by downloading what you need.
3. A startup-quarter panel (`startup_qtr_panel.dta`) for 1980-2010 with time-varying information on startups that receive at least one patent during the sample period. Please note that observations up through 2017 are in the dataset because our dependent variables were forward looking relative to our independent variables and available after 2010. This file is not included here, as it contains licensed data but email us if your institution has a license for VenturExpert, SDC, and Dealscan. 

We also include **`aggregate_measures.do`, which contains a Stata function to convert patent-level variables into group-time variables (e.g. firm-year, state-year, MSA-quarter).** We include the stocking function from our paper, which gets the group's average patent stats over the prior five years, after applying a 20% rate of depreciation. 

	
## Updated patent-text measures and code to build them from Google Patents 

**A companion repository ([`Patent-Text-Variables`](https://github.com/donbowen/Patent-Text-Variables)) is available containing patent level RETech and Tech Breadth for patents granted through last year**, and will be updated annually. The componanion repo also includes code to 
- Download all google patent pages 
- Parse the patent text in those webpages into (cleaned) "bags of words" 
- Construct textual variables at the patent-level from word bags 
- Convert patent level variables into group-time variables (e.g. firm-year, state-year, MSA-quarter)

