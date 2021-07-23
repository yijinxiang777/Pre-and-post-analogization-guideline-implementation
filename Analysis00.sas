/*---------------------------------------------------

Program: 01_Data Prep
Date: 8/3/20
By: Yijin Xiang (data cleaning was conducted by martha, found in C:\Users\yxian33\Box\Ocampo_Claudia\Analysis)
Requester: Claudia Ocampo

---------------------------------------------------*/
/************Set up library and get dataset****************/
%let root = C:\Users\yxian33\OneDrive - Emory University\Projects_Yijin_Xiang\Ocampo_Claudia;
%let dir = C:\Users\yxian33\OneDrive - Emory University\Projects_Yijin_Xiang\Ocampo_Claudia\Output;
%let outpath = &root.\output;
libname in  "&root.\Analysis\Out Data";
/************load macro*********************************/
%include "C:\Users\yxian33\OneDrive - Emory University\Projects_Yijin_Xiang\Winship_Macro\CALC_PS V10.2.sas";
%include "C:\Users\yxian33\OneDrive - Emory University\Projects_Yijin_Xiang\Winship_Macro\STD_DIFF V6.2.sas"; *calculate standard difference;
%include "C:\Users\yxian33\OneDrive - Emory University\Projects_Yijin_Xiang\Winship_Macro\PSMATCHING V2.sas"; *calculate ps matching;
/* Load macros */
%include "C:\Users\yxian33\OneDrive - Emory University\Projects_Yijin_Xiang\Hematology_Oncology\Brown_Megan\VWF\Analysis\Descriptives Macro_Custom.sas";
%include "C:\Users\yxian33\OneDrive - Emory University\Projects_Yijin_Xiang\Winship_Macro\UNI_CAT V30.sas";
%include "C:\Users\yxian33\OneDrive - Emory University\Projects_Yijin_Xiang\Winship_Macro\DESCRIPTIVE V15.sas";

/*---------------------------------------------------
					Import Data
---------------------------------------------------*/

/*---- 	Pre Protocol Files 	-----*/
proc import datafile = "&inpath.\Biostatistics pre data.xlsx" out = pre_patients_co
	dbms = xlsx replace;
	sheet = "Patients";
run;

proc contents data=pre_patients_co varnum;
run;
proc import datafile = "&inpath.\Original pre NICU Protocol.xlsx" out = pre_los_orig
	dbms = xlsx replace;
	sheet = "LENGTH OF STAY and READMISSIONS";
run;

proc import datafile = "&inpath.\Biostatistics pre data.xlsx" out = pre_surg_co
	dbms = xlsx replace;
	sheet = "SURGICAL PROCEDURES";
run;

proc import datafile = "&inpath.\Biostatistics pre data.xlsx" out = pre_sed_co
	dbms = xlsx replace;
	sheet = "Sedation med administrations";
run;


/* From the original data, get the surgical procedures */
proc import datafile = "&inpath.\Original pre NICU protocol.xlsx" out = pre_surg_orig
	dbms = xlsx replace;
	sheet = "SURGICAL PROCEDURES";
run;




/*---- 	Post Period Files 	-----*/
/* From Claudia's manipulated data */
proc import datafile = "&inpath.\Biostatistics post data.xlsx" out = post_patients_co
	dbms = xlsx replace;
	sheet = "Patients";
run;

proc import datafile = "&inpath.\Biostatistics post data_LOS.csv" out = post_los_co
	dbms = csv replace;

run;


proc import datafile = "&inpath.\Biostatistics post data.xlsx" out = post_surg_co
	dbms = xlsx replace;
	sheet = "Surgical Procedures";
run;


proc import datafile = "&inpath.\Biostatistics post data.xlsx" out = post_sed_co
	dbms = xlsx replace;
	sheet = "Sedation med administrations";
run;


/*---- 	Post Period Files phase 2 	-----*/
/* From Claudia's manipulated data */
proc import datafile = "&inpath.\Phase 2 sedation protocol data.xlsx" out = post_patients_p2
	dbms = xlsx replace;
	sheet = "Patients";
run;


Data post_patients_p2 (drop = Patient_Name);
     set post_patients_p2;
     /*Reformat the feeding variable*/
     Date_of_Death= datepart(Date_of_Death);
     format Date_of_Death mmddyy10.;
run;


proc import datafile = "&inpath.\Phase 2 sedation protocol data.xlsx" out = post_los_co_p2
	dbms = xlsx replace;
    sheet = "LENGTH OF STAY and READMISSIONS";
run;
proc contents data=post_los_co_p2 varnum;
run;

/*Prepare the procedure variable */
proc import datafile = "&inpath.\Phase 2 sedation protocol data.xlsx" out = post_surg_p2
	dbms = xlsx replace;
	sheet = "Surgical Procedures";
run;

proc sql;
create table Number_of_procedures_list as 
select distinct MRN, count(*) as Number_of_procedures
from post_surg_p2
group by MRN;
quit;


proc sort data=post_surg_p2;
by MRN;
run;
Data post_surg_co_p2;
     merge post_surg_p2 Number_of_procedures_list;
	 by MRN;
     /*Reformat the feeding variable*/
     First_Post_Op_Feeding= datepart(First_Post_Op_Feeding);
     format First_Post_Op_Feeding mmddyy10.;
      Days_to_feed = max(First_Post_Op_Feeding - Surgery_Date,0);
      if not first.MRN then Number_of_procedures=.;
run;
proc contents data=post_surg_co_p2 varnum;
run;

/*Prepare sedationlevel for paient dataset*/
proc import datafile = "&inpath.\Copy of Classify_sedation_level part2.xlsx" out = sedation_level
	dbms = xlsx replace;
	sheet = "Sheet1";
run;
proc contents data=sedation_level varnum;
run;
proc sql;
create table sedation_list_pre as 
SELECT *
FROM post_surg_p2
INNER JOIN sedation_level ON post_surg_p2.Surgical_Procedure=sedation_level.Surgical_Procedure;
quit;
proc sql;
create table sedation_list as 
select distinct MRN, 
case 
when count(distinct Sedation_level) > 1 then "both  " 
else Sedation_level 
end as Sedation_level
from sedation_list_pre
group by MRN;
quit;
proc sort data=post_patients_p2;
by MRN;
run;

proc sort data=sedation_list;
by MRN;
run;
data post_patients_co_p2;
merge post_patients_p2  sedation_list;
by MRN;
label sedation_list= "Sedation level";
run;

/*Sedation drug use*/
proc import datafile = "&inpath.\Phase 2 sedation protocol data.xlsx" out = post_sed_co_p2
	dbms = xlsx replace;
	sheet = "Sedation Med Adminstrations";
run;
proc contents data=post_sed_co_p2 varnum;
run;
Data post_sed_co_p2;
     set post_sed_co_p2 ;
     /*Reformat the feeding variable*/
     Dexmedetomidine_Earliest_Admin= datepart(Dexmedetomidine_Earliest_Admin);
	 Dexmedetomidine_Latest_Admin= datepart(Dexmedetomidine_Latest_Admin);
	 Fentanyl_Earliest_Admin= datepart(Fentanyl_Earliest_Admin);
	 Fentanyl_Latest_Admin= datepart(Fentanyl_Latest_Admin);
	 Lorazepam_Earliest_Admin= datepart(Lorazepam_Earliest_Admin);
	 Lorazepam_Latest_Admin= datepart(Lorazepam_Latest_Admin);
	 Midazolam_Earliest_Admin= datepart(Midazolam_Earliest_Admin);
	 Midazolam_Latest_Admin= datepart(Midazolam_Latest_Admin);
	 Morphine_Earliest_Admin= datepart(Morphine_Earliest_Admin);
	 Morphine_Latest_Admin= datepart(Morphine_Latest_Admin);
	 Methadone_Earliest_Admin= datepart(Methadone_Earliest_Admin);
	 Methadone_Latest_Admin= datepart(Methadone_Latest_Admin);
	 Toradol_Earliest_Admin= datepart(Toradol_Earliest_Admin);
	 Toradol_Latest_Admin= datepart(Toradol_Latest_Admin);
	 Tylenol_Earliest_Admin= datepart(Tylenol_Earliest_Admin);
	 Tylenol_Latest_Admin= datepart(Tylenol_Latest_Admin);
     format Dexmedetomidine_Earliest_Admin Dexmedetomidine_Latest_Admin Fentanyl_Earliest_Admin Fentanyl_Latest_Admin
            Lorazepam_Earliest_Admin Lorazepam_Latest_Admin Midazolam_Earliest_Admin Midazolam_Latest_Admin
            Morphine_Earliest_Admin Morphine_Latest_Admin Methadone_Earliest_Admin Methadone_Latest_Admin
            Toradol_Earliest_Admin Toradol_Latest_Admin Tylenol_Earliest_Admin Tylenol_Latest_Admin  mmddyy10.;
run;
proc contents data=post_sed_co_p2 varnum;
run;
/* From the original data, get the surgical procedures */
proc import datafile = "&inpath.\Original post NICU protocol.xlsx" out = post_surg_orig
	dbms = xlsx replace;
	sheet = "SURGICAL PROCEDURES";
run;


/*---------------------------------------------------
					Clean Data
---------------------------------------------------*/

/* Get NICU LOS files from NICU stay level to hospital stay level */
/* Collapse LOS and get first NICU admit date */

data pre_los_orig2 (drop = Entered_NICU Exited_NICU rename= (Entered_NICU2=Entered_NICU Exited_NICU2=Exited_NICU));
	set pre_los_orig;
	Entered_NICU2 = datepart(Entered_NICU);
	Exited_NICU2 = datepart(Exited_NICU);
	format Entered_NICU2 Exited_NICU2 MMDDYY10.;
run;


data los;
	format Cohort $20. ;
	set pre_los_orig2 (in=a drop = Patient_Name Readmission_Date Readmission_Dx)
		post_los_co (in=b drop = Readmission_Date Readmission_Dx Total_NICU_LOS )
        post_los_co_p2 (in=c drop = Patient_Name Readmission_Date Readmission_Dx );
	where not missing(MRN);
	if a then Cohort = "1. Pre"; 
		else if b or c then Cohort = "2. Post";
	if a then Cohort1 = "Pre  ";
	else if b then Cohort1 = "Post1";
	else if c then Cohort1 = "Post2";
	Hospital_LOS_MW = Hosp_Discharge - Hosp_Admission;
	if not missing(Hospital_LOS) then Compare = (Hospital_LOS_MW ne Hospital_LOS);
	format Impute_Discharge MMDDYY10.;
	if missing(Hosp_Discharge) and a then Impute_Discharge = "21MAR2019"d ;
		else if missing(Hosp_Discharge) and a then Impute_Discharge = "04Jan2020"d;
		else Impute_Discharge = Hosp_Discharge;
run;

proc means data = los noprint nway;
	output out = los2
	sum(NICU_LOS) =
	min(Entered_NICU)=First_NICU_Admit;
	class mrn Hosp_Admission;
	id Cohort Hosp_Discharge Readmit_Within_7_Days Readmit_Within_30_Days Hospital_LOS_MW Impute_Discharge;
run; 

/* Combine sedation data sets */
data allsed;
	set pre_sed_co (in=a drop = dexmed: )
		post_sed_co (in=b )
        post_sed_co_p2 (in=c drop= PATIENT_NAME BS BT BU); 
	if a then Cohort = "1. Pre  ";
		else if b or c then Cohort = "2. Post";
    if a then Cohort1 = "Pre  ";
	  else if b then Cohort1 = "Post1";
	  else if c then Cohort1 = "Post2";
	/* idk what's wrong with this SAS date but this is necessary for a subsequent merge */
	informat Hosp_Admission MMDDYY10.;
	Hosp_Admission = floor(Hosp_Admission);
run;
proc contents data=allsed varnum;
run;

/* Collapse surgeries at hospitalization level */
/* First, determine which hospitalization the surgery happened during */
data allsurg ;
	set pre_surg_co (in=a)
		post_surg_co (in=b)
        post_surg_co_p2 (in=c drop= Patient_Name ); 
	if a then Cohort = "1. Pre  ";
		else if b or c then Cohort = "2. Post";
	if a then Cohort1 = "Pre  ";
	  else if b then Cohort1 = "Post1";
	  else if c then Cohort1 = "Post2";
	where not missing(MRN);
run;

/* Attach hospitalization dates to surgeries */
proc sql noprint;
	create table allsurg2 as
	select b.*, a.Surgery_Date, a.Number_of_procedures, a.MRN as Surg_MRN,
		case when (b.cohort = "1. Pre" and "01Jan2018"d <= Surgery_Date <= "01Jul2018"d) or 
			(b.Cohort = "2. Post" and "01Jul2019"d <= Surgery_Date) then 1 else 0 end as CountSurg
	from allsurg a right join los2 (drop = _TYPE_ _FREQ_) b
	on a.mrn = b.mrn and Hosp_Admission  <= Surgery_Date and Surgery_Date <= Impute_Discharge;
quit;

/* Count surgeries by hospital admission */
proc means data = allsurg2 noprint nway missing;
	output out = surg_byhosp
	sum(CountSurg)= 
	max(Number_of_procedures)=;
	class MRN Cohort Hosp_Admission Hosp_Discharge;
	id Readmit: Hospital_LOS_MW NICU_LOS First_NICU_Admit;
run;

		
/* Merge with sedation at hospitalization level */
proc sort data = allsed;
	by mrn Hosp_Admission;
run;
proc contents data=allsed varnum;
run;
/* Merge with sedation at hospitalization level */
proc sort data = surg_byhosp;
	by mrn Hosp_Admission;
run;
proc contents data=surg_byhosp varnum;
run;

data HospLevel (drop = _TYPE_ _FREQ_) 
	checkit;
	merge surg_byhosp (in=a drop= Cohort )
		allsed (in=b drop=Hosp_Discharge);
	by MRN  Hosp_Admission;
	if b and not a then output checkit;
	if a then output HospLevel;

run;


/* Check against Claudia's counts - looks like most discrepancies are with patients who had multiple hospitalizations*/
data test;
	set hosplevel;
	if CountSurg ne Number_of_procedures;
	if CountSurg = 0 and Number_of_procedures = . then delete;
run;

/* Merge clinical data with patient data at patient level */
/* Stack patient-level files */
data allpat;
	set pre_patients_co (in=a)
		post_patients_co (in=b)
        post_patients_co_p2(in=c);
	if a then Cohort = "1. Pre  ";
		else if b or c then Cohort = "2. Post";
    if a then Cohort1 = "Pre  ";
	  else if b then Cohort1 = "Post1";
	  else if c then Cohort1 = "Post2";
	where not missing(MRN);
run;

proc sort data = allpat;
	by cohort mrn;
run;

proc sort data = hosplevel;
	by cohort mrn;
run;

/* Final file */
data out.analytic1 ;
	merge allpat (in=a) hosplevel (in=b);
	by  cohort MRN;
	if a and b ;
	
	Death = (not missing(Date_of_Death));
	if not missing(Death) then Death_C = put(Death, yn.);

	/* Collapse Race categories */
	format NewRace NewInsurance $30.;
	if Race = "Black or African American" then NewRace = "1. Black or African American";
		else if Race = "White" then NewRace = "2. White";
		else if Race in ("Asian", "Native Hawaiian or Other") then NewRace = "3. Other";
		else if Race in ("Declined", "Unknown", "") then NewRace = "";

	/* Collapse insurance categories */
/*	if Financial_Class in ("Self-pay", "Shared Service") then NewInsurance = "4. Other";*/
/*		else if Financial_Class = "CMO Medicaid" then NewInsurance = "3. CMO Medicaid";*/
/*		else if Financial_Class = "Managed Care" then NewInsurance = "1. Managed Care";*/
/*		else if Financial_Class = "Medicaid" then NewInsurance = "2. Medicaid";*/

	if Financial_Class in ("Self-pay", "Shared Service", "Managed Care") then NewInsurance = "1. Non-governmental";
		else if Financial_Class = "CMO Medicaid" then NewInsurance = "3. CMO Medicaid";
		else if Financial_Class = "Medicaid" then NewInsurance = "2. Medicaid";

	if "01Jan2018"d <= Hosp_Discharge <= "01Jul2018"d or 
		"01Jul2019"d <= Hosp_Discharge  then Usable_LOS = Hospital_LOS_MW;

	/* For stddiff macro */
	if not missing(sex) then Female = (sex="Female");
	if not missing(Ethnicity) then Hispanic = (Ethnicity = "Hispanic or Latino");
	Cohort_Post = (Cohort = "2. Post");

	/* Prep the medication data */
	array days (*) Dexmedetomidine_Admin_Days
		Fentanyl_Admin_Days
		Lorazepam_Admin_Days
		Midazolam_Admin_Days
		Morphine_Admin_Days
		Methadone_Admin_Days
		Toradol_Admin_Days
		Tylenol_Admin_Days;

	array any (*) $	Any_Dex
		Any_Fentanyl
		Any_Lorazepam
		Any_Midazolam
		Any_Morphine
		Any_Methadone
		Any_Toradol
		Any_Tylenol;

	array days0 (*) Dexmedetomidine_Admin_Days0
		Fentanyl_Admin_Days0
		Lorazepam_Admin_Days0
		Midazolam_Admin_Days0
		Morphine_Admin_Days0
		Methadone_Admin_Days0
		Toradol_Admin_Days0
		Tylenol_Admin_Days0;

	do i = 1 to hbound(days);
		if missing(days(i)) then do;
			any(i) = "No";
			days0(i) = 0;
		end;
		else if days(i) > 0 then do;
			any(i) = "Yes";
			days0(i) = days(i);
		end;
	end;

run;



/**/

proc contents data=in.analytic;
run;
proc freq data=in.analytic1;
table Sex NewRace*Race Ethnicity NewInsurance Sedation_level Death_C;
run;
proc univariate data = analytic;
var Gestational_Age CountofSurg NICU_LOS ;
histogram Gestational_Age CountofSurg NICU_LOS ;
run;
data analytic;
set in.analytic1;
/****recode variable to meet the requirement of the sas macro*/
if cohort = "1. Pre" then do 
   cohort_cat = "Pre ";
   cohort_num = 0;
   end;
else do;
   cohort_cat = "Post";
   cohort_num = 1;
   end;
*sex;
if sex = "Female" then sex_num = 0;
else sex_num = 1;
*race;
if NewRace = "1. Black or African American  " then NewRace_num = 0;
if NewRace = "2. White " then NewRace_num = 1;
if NewRace = "3. Other " then NewRace_num = 2;
*Ethnicity;
if Ethnicity = "Hispanic or Latino" then Ethnicity_num = 1;
else Ethnicity_num = 0;
*NewInsurance;
if NewInsurance = "1. Non-governmental " then NewInsurance_num = 0;
if NewInsurance = "2. Medicaid " then NewInsurance_num = 1;
if NewInsurance = "3. CMO Medicaid " then NewInsurance_num = 2;
*Sedation_level ;
if Sedation_level  = "moderate" then Sedation_level_num = 2;
if Sedation_level  = "light" then Sedation_level_num = 1;
if Sedation_level  = "both " then Sedation_level_num = 0;
*Death_C;
if Death_C = "No" then Death_C_num = 0;
else Death_C_num = 1;
GA = Gestational_Age;
los = NICU_LOS;
CountofSurg = CountSurg;
*log transformation;
dex_admin_days_log = log(Dexmedetomidine_Admin_Days);
dex_per_kilo_per_dal_log = log(Dexmedetomidine_Per_Kilo_Per_Da1);
fentanyl_admin_days_log = log(Fentanyl_Admin_Days);
fentanyl_per_kilo_per_dal_log = log(Fentanyl_Per_Kilo_Per_Day_Days);
Lorazepam_admin_days_log = log(Lorazepam_Admin_Days);
Lorazepam_per_kilo_per_dal_log = log(Lorazepam_Per_Kilo_Per_Day_Days);
Midazolam_admin_days_log = log(Midazolam_Admin_Days);
Midazolam_per_kilo_per_dal_log = log(Midazolam_Per_Kilo_Per_Day_Days);
orphine_admin_days_log = log(Morphine_Admin_Days);
orphine_per_kilo_per_dal_log = log(Morphine_Per_Kilo_Per_Day_Days);
Methadone_admin_days_log = log(Methadone_Admin_Days);
Methadone_per_kilo_per_dal_log = log(Methadone_Per_Kilo_Per_Day_Days);
Toradol_admin_days_log = log(Toradol_Admin_Days);
Toradol_per_kilo_per_dal_log = log(Toradol_Per_Kilo_Per_Day_Days);
Tylenol_admin_days_log = log(Tylenol_Admin_Days);
Tylenol_per_kilo_per_dal_log = log(Tylenol_Per_Kilo_Per_Day_Days);
los_log = log(los);
label Sex ="Sex"
      NewRace = "Race" 
      Ethnicity = "Ethnicity" 
      NewInsurance = "NewInsurance"  
      Sedation_level = "Sedation level" 
      Death_C = "Death"
      los = "NICU LOS"
      CountofSurg = "Surgery Count"
      GA = "Gestational Age";
run;
proc export 
  data=analytic
  dbms=xlsx 
  outfile="&root.\Analysis\Out Data\analytic.xlsx" 
  replace;
run;
proc 
proc contents data=analytic;
run;
proc freq data=analytic;
table cohort*cohort_num Sex*Sex_num NewRace*NewRace_num Ethnicity*Ethnicity_num NewInsurance*NewInsurance_num Sedation_level*Sedation_level_num Death_C*Death_C_num;
run;
ods html;
proc means data =analytic median q1 q3 n NMISS;
var Gestational_Age NICU_LOS CountSurg;
class cohort;
run;
proc corr data= analytic;
var Sex_num NewRace_num Ethnicity_num NewInsurance_num Sedation_level_num Death_C_num Gestational_Age NICU_LOS CountSurg;; 
run;

/*Table 1 winship*/
%let c_var =  Sex NewRace Ethnicity NewInsurance Sedation_level Death_C;
%let n_var = Gestational_Age CountSurg NICU_LOS ;
TITLE 'Table 1 Univariate Association with cohort';
%UNI_CAT(dataset = analytic, 
	outcome = cohort, 
	clist = &c_var, 
	nlist = &n_var, 
	nonpar = F,
	rowpercent = F,
	orientation = portrait,
	outpath = &outpath, 
	fname = Table 1 Univariate Association with cohort);
TITLE;

TITLE 'Table 1 Univariate Association_overall';
%DESCRIPTIVE(dataset = analytic, 
	clist = Sex NewRace Ethnicity NewInsurance Sedation_level Death_C, 
	nlist = Gestational_Age CountSurg NICU_LOS , 
	dictionary = F,
	outpath = &outpath,
	fname = Table 1 Univariate Association);
TITLE;
