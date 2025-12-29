/* ====================================================================
   Project: The 2008 financial crisis and resilience in the Euro area
   Objective: Assess the impact of the 2008 crisis on Euro area trade flows
              using a structural gravity equation.
   
   Data Source: Gravity_M2IT.dta & Gravity Portal
   
   Repo: https://github.com/jemappelleyesmine/Financial_crisis_and_resilience_in_Euro_area
   
   Structure:
     1. Setup & Directory Management
     2. Data Preparation
     3. Descriptive Statistics & Graphs
	 4. Sample Selection
     5. Main Econometric Estimation (PPML)
     6. Heterogeneity Analysis (By Product Type)
     7. Output Results Table (LaTeX)
   ==================================================================== */
   
   
* --------------------------------------------------------------------
* 1. Setup & Directory Management
* --------------------------------------------------------------------            
clear all              
set more off           
macro drop _all        
capture log close       
   
* Path definition
if "`c(username)'" == "jiang" {
    global root "E:/00 M2 Quantitative Economic Analysis/OC - Quantitative International trade - 3ECTS - 2COEF/Financial_crisis_and_resilience_in_Euro_area"
}
else if "`c(username)'" == "CollaboratorName" {
    global root "/Users/Name/Project"
}
else {
    global root ".."
}

global data "$root/dataset"     
global output "$root/output"
global raw "$root/raw"      

* Initialize Log File
log using "$output/analysis_log.txt", replace text
   
* Load data
use "$data/Gravity_M2IT.dta", clear

* Define graph style (optional, for better aesthetics)
graph set window fontface "Times New Roman"

* --------------------------------------------------------------------
* 2. Data Preparation
* --------------------------------------------------------------------

* 1. Define the Post-Crisis Period
gen post_crisis = (year >= 2009)

* 2. Generate Log GDP
gen ln_gdp_i = ln(gdp_i)
gen ln_gdp_j = ln(gdp_j)

* 3. Define the "Euro Area" (EA)
* Note: The dataset contains 'eu_o' (European Union), but the research question 
* focuses on the Euro Area (Currency Union). 
* We define the Euro Area members of 2008:
* Austria (AUT), Belgium (BEL), Finland (FIN), France (FRA), Germany (DEU), 
* Greece (GRC), Ireland (IRL), Italy (ITA), Luxembourg (LUX), Netherlands (NLD), 
* Portugal (PRT), Spain (ESP), Slovenia (SVN), Cyprus (CYP), Malta (MLT).

gen ea_i = 0
gen ea_j = 0
* List of EA15 countries using ISO3 codes
local ea_list "AUT BEL FIN FRA DEU GRC IRL ITA LUX NLD PRT ESP SVN CYP MLT"

foreach c of local ea_list {
    replace ea_i = 1 if iso3_i == "`c'"
    replace ea_j = 1 if iso3_j == "`c'"
}

* 4 Define two groups: Euro Area (EA) vs. Rest of the World (RoW)
gen region_group = "Rest of the World"
replace region_group = "Euro Area" if ea_i == 1

* 5. Generate Interaction Terms (Difference-in-Differences)
* Export Resilience: Impact on EA exports vs. the rest of the world after the crisis
gen ea_export_shock = ea_i * post_crisis

* Import Resilience: Impact on EA imports vs. the rest of the world after the crisis
gen ea_import_shock = ea_j * post_crisis

* --------------------------------------------------------------------
* 3. Descriptive Statistics & Graphs
* --------------------------------------------------------------------
* Graph 1: Total Exports Trend (Index 2008 = 100)
preserve
    * Exclude Intra-Euro Area trade
    * We exclude trade where both exporter and importer are EA members 
    * to focus on the external resilience/competitiveness of the Euro Area.
    drop if ea_i == 1 & (iso3_j == "AUT" | iso3_j == "BEL" | iso3_j == "FIN" | ///
                         iso3_j == "FRA" | iso3_j == "DEU" | iso3_j == "GRC" | ///
                         iso3_j == "IRL" | iso3_j == "ITA" | iso3_j == "LUX" | ///
                         iso3_j == "NLD" | iso3_j == "PRT" | iso3_j == "ESP" | ///
						 iso3_j == "SVN" | iso3_j == "CYP" | iso3_j == "MLT")

    * Collapse data to aggregate trade by year and region
    collapse (sum) trade, by(year region_group)
    
    * Sort data to ensure the lines are plotted chronologically
    sort region_group year

    * Set 2008 as the base year (Index = 100)
    * Normalize the export volume to allow for relative comparison.
    gen trade_2008_val = trade if year == 2008
    bysort region_group: egen base_2008 = max(trade_2008_val)
    
    * Calculate the export volume index
    gen trade_index = (trade / base_2008) * 100
    
    * Display a subset of data to verify the calculation
    list year region_group trade_index if year >= 2005 & year <= 2010

    * Plot the Line Graph
    twoway (line trade_index year if region_group == "Euro Area", ///
                lcolor(blue) lwidth(thick)) ///
           (line trade_index year if region_group == "Rest of the World", ///
                lcolor(gs10) lpattern(dash)), ///
           title("Evolution of Exports (Index 2008 = 100)") ///
           xtitle("Year") ytitle("Export Volume Index") ///
           legend(label(1 "Euro Area") label(2 "Rest of the World")) ///
           xline(2008, lpattern(dot) lcolor(red)) ///
           note("Source: Gravity_M2IT dataset. Base year 2008 = 100.") ///
           graphregion(color(white)) bgcolor(white)
           
    * Export the graph to a PNG file
    graph export "Graph1_Export_Trend_Fixed.png", replace
restore


* Graph 2: Trade Openness (Exports / GDP Ratio)
preserve
    * We need to aggregate Trade and GDP.
    * Note: GDP (gdp_i) is country-specific. In the bilateral dataset, 
	* gdp_i is repeated for each partner. We must avoid double counting.
    
    * Strategy: First, collapse to the country-year level.
    collapse (sum) trade (mean) gdp_i, by(iso3_i year region_group)
    
    * Then, aggregate to the region-year level.
    collapse (sum) trade gdp_i, by(year region_group)
    
    * Calculate the Trade-to-GDP ratio
    gen trade_gdp_ratio = trade / gdp_i
    
    * Plot the line graph
    twoway (line trade_gdp_ratio year if region_group == "Euro Area", lcolor(blue) lwidth(thick)) ///
           (line trade_gdp_ratio year if region_group == "Rest of the World", lcolor(gs10) lpattern(dash)), ///
           title("Trade Openness (Exports / GDP)") ///
           xtitle("Year") ytitle("Exports to GDP Ratio") ///
           legend(label(1 "Euro Area") label(2 "Rest of the World")) ///
           xline(2008, lpattern(dot) lcolor(red)) 
           
    * Export the graph
    graph export "Graph2_Trade_GDP.png", replace
restore

* Graph 3: Export Composition by Sector (Capital vs. Intermediate vs. Consumption)
preserve
    * 1. Aggregate sectoral trade by region
    * -----------------------------------------------------
    * We sum up the trade values for each sector within the two groups
    collapse (sum) cap inter conso, by(region_group)
    
    * 2. Calculate Shares
    * -----------------------------------------------------
    * Calculate total exports across these three sectors for the denominator
    gen total_sector = cap + inter + conso
    
    * Calculate the percentage share of each sector
    gen share_cap = (cap / total_sector) * 100
    gen share_inter = (inter / total_sector) * 100
    gen share_conso = (conso / total_sector) * 100
    
    * 3. Plot the Graph (Directly using the variables created above)
    * -----------------------------------------------------   
    graph bar share_cap share_inter share_conso, over(region_group) ///
        title("Export Specialization: Euro Area vs. Rest of World") ///
        ytitle("Share of Total Exports (%)") ///
        legend(label(1 "Capital Goods") label(2 "Intermediate Goods") label(3 "Consumption Goods")) ///
        bar(1, color(navy)) bar(2, color(ebblue)) bar(3, color(ltblue)) ///
		ylabel(0(20)65) ///
        blabel(bar, format(%9.1f)) ///
        note("Note: This chart highlights the structural differences in export baskets.") scheme(s1mono)
        
    * 4. Export the graph
    * -----------------------------------------------------
    graph export "Graph3_Composition_Fixed.png", replace
restore

* --------------------------------------------------------------------
* 4. Sample Selection
* --------------------------------------------------------------------

* Objective: Assess the Euro Area's EXTERNAL resilience.
* Strategy: Exclude Intra-Euro Area trade flows to focus on global competitiveness.
* The sample will include:
* 1. EA exports to RoW (Rest of World)
* 2. RoW exports to EA
* 3. RoW exports to RoW (Control group)

drop if ea_i == 1 & ea_j == 1

* Set panel structure (Pair ID and Year)
egen pair_id = group(iso3_i iso3_j)
xtset pair_id year

* --------------------------------------------------------------------
* 5. Main Econometric Estimation (PPML)
* --------------------------------------------------------------------

* We use Poisson Pseudo Maximum Likelihood (PPML) to account for zero trade flows and heteroskedasticity.

* 5.1 Total Trade Resilience
* Specification:
* - absorb(pair_id year): Controls for Pair Fixed Effects (time-invariant factors like distance) 
* and Year Fixed Effects (global shocks).
* - rta: Controls for Regional Trade Agreements.
* - cluster(pair_id): Clusters standard errors at the pair level.

ppmlhdfe trade ea_export_shock ea_import_shock ln_gdp_i ln_gdp_j rta, ///
    absorb(pair_id year) cluster(pair_id)
est store Total_Trade


* --------------------------------------------------------------------
* 6. Heterogeneity Analysis (By Product Type)
* --------------------------------------------------------------------

* Literature (e.g., Bems et al., 2012) suggests the crisis hit "Capital Goods" and "Durable Goods" the hardest. 
* We test if the Euro Area's specialization in these sectors explains its performance.

* 6.1 Capital Goods (Variable: cap)
* Hypothesis: Significant negative impact expected due to investment collapse.
ppmlhdfe cap ea_export_shock ea_import_shock ln_gdp_i ln_gdp_j rta, ///
    absorb(pair_id year) cluster(pair_id)
est store Capital_Goods

* 6.2 Intermediate Goods (Variable: inter)
* Hypothesis: Significant impact expected due to Global Value Chain (GVC) disruptions.
ppmlhdfe inter ea_export_shock ea_import_shock ln_gdp_i ln_gdp_j rta, ///
    absorb(pair_id year) cluster(pair_id)
est store Inter_Goods

* 6.3 Consumption Goods (Variable: conso)
* Hypothesis: Least impact expected as consumption is usually more stable than investment.
ppmlhdfe conso ea_export_shock ea_import_shock ln_gdp_i ln_gdp_j rta, ///
    absorb(pair_id year) cluster(pair_id)
est store Cons_Goods


* --------------------------------------------------------------------
* 7. Output Results Table
* --------------------------------------------------------------------

* Export the regression table to an RTF file (readable by Word).

* 1. Main Results
esttab Total_Trade Capital_Goods Inter_Goods Cons_Goods ///
    using "$output/EuroArea_Results.tex", ///
    replace ///
    booktabs /// 
    label /// 
    se star(* 0.10 ** 0.05 *** 0.01) /// 
    b(%9.3f) se(%9.3f) /// 
    stats(N ll, labels("Observations" "Log Likelihood") fmt(0 2)) /// 
    title("Table 1: Resilience of Euro Area Trade Flows Post-2008 Crisis (PPML Results)") ///
    mtitles("Total Trade" "Capital" "Intermediate" "Consumption") ///
    addnote("Notes: Robust standard errors clustered by country-pair in parentheses. All specifications include pair and year fixed effects.")
	






