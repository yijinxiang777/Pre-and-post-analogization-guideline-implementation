
/****Gain the propensity score*/
%CALC_PS(DATASET=analytic,
         TRTGRP =cohort_cat,
         MODEL=&c_var &n_var,  CVAR=&c_var, 
         SUBID =MRN, OUTDATA = CALPS, DOC=T, 
         OUTPATH= &dir  , FNAME = PS.1 - PS overlap for table 1, DEBUG=F);


/* the number of patient in two groups are                                 
                                             The FREQ Procedure

                                                               Cumulative    Cumulative
              Cohort                  Frequency     Percent     Frequency      Percent
              1. Pre                       127       48.66           127        48.66
              2. Post                      134       51.34           261       100.00
********/


/***Prepare the dataset for std_diff function***/

%STD_DIFF(DATASET=analytic, 
	      TRTGRP=cohort_cat, 
          CLIST =  Sex NewRace Ethnicity NewInsurance Sedation_level Death_C, 
          NLIST= Gestational_Age CountSurg NICU_LOS , 
          OUTDATA=ASD, 
          OUTPATH=&dir, 
          REFASD =0.2,
          FNAME=Table 1 - UVA pre versus post standard difference, 
	    ORIENTATION= PORTRAIT, DEBUG=F); 

PROC CONTENTS DATA= CALPS;
RUN;
/*Gain a dataset using ATE_w(gain the averaged treatment effect), work better than ate_sw*/
 %STD_DIFF(DATASET=CALPS, 
	    TRTGRP=cohort_cat, 
          CLIST =&c_var, 
          NLIST=&n_var logit_ps ,
          WEIGHT = ATE_W,
          OUTPATH=&dir, 
          REFASD =0.2,
          FNAME=PS.1 - Assess Balance (ATE_W), 
	      ORIENTATION= PORTRAIT, DEBUG=F); 
/*Gain a dataset using ATE_SW(help to reduce extreme weight), perserves the sample size, not work well*/
 %STD_DIFF(DATASET=CALPS, 
	    TRTGRP=cohort_cat, 
          CLIST =&c_var, 
          NLIST=&n_var logit_ps ,
          WEIGHT = ATE_SW,
          OUTPATH=&dir, 
          REFASD =0.2,
          FNAME=PS.1 - Assess Balance (ATE_SW), 
	      ORIENTATION= PORTRAIT, DEBUG=F); 

/*Gain a dataset using ATO_W(concentrate on weighting for the overlapped sample)*/
 %STD_DIFF(DATASET=CALPS, 
	    TRTGRP=cohort_cat, 
          CLIST =&c_var, 
          NLIST=&n_var logit_ps ,
          WEIGHT = ATO_W,
          OUTPATH=&dir, 
          REFASD =0.2,
          FNAME=PS.1 - Assess Balance (ATO_W), 
	      ORIENTATION= PORTRAIT, DEBUG=F); 
*Show a better balance compared to ate_sw, however the sample size dropped a lot;
/*Table 1 winship*/
%let c_var =  Sex NewRace Ethnicity NewInsurance Sedation_level Death_C;
%let n_var = Gestational_Age CountSurg NICU_LOS ;
TITLE 'Table 1 Univariate Association with cohort after weight';
%UNI_CAT(dataset = ps_data_trim, 
	outcome = cohort, 
	clist = &c_var, 
	nlist = &n_var, 
	nonpar = F,
	rowpercent = F,
	orientation = portrait,
	outpath = &outpath, 
	fname = Table 1 Univariate Association with cohort after weight);
TITLE;

/*Table 2*/
ods html;
PROC FREQ data = ps_data_trim;
table Any_Dex * cohort_cat
Any_Fentanyl * cohort_cat
Any_Lorazepam * cohort_cat
Any_Midazolam * cohort_cat
Any_Morphine * cohort_cat
Any_Methadone * cohort_cat
Any_Toradol * cohort_cat
Any_Tylenol * cohort_cat
Death_C * cohort_cat;
weight siptw;
run;

/****Gain odds ratio based on the ate and ato_sw weighting stratage*/

proc surveyfreq data = CALPS VARMETHOD=JACKKNIFE; *Table 2;
WEIGHT ATO_W;
tables (Any_Dex
Any_Fentanyl
Any_Lorazepam
Any_Midazolam
Any_Morphine
Any_Methadone
Any_Toradol
Any_Tylenol
)*cohort_cat / chisq;
title 'Table 2 Weighted Odds ratio';
run;

proc surveylogistic data=CALPS;
class cohort_cat (param=ref ref="Post");
model Any_Fentanyl = cohort_cat;
weight ATO_W;
ods select CumulativeModelTest OddsRatios;
run;

proc freq data=CALPS;
table Any_Dex* cohort_cat;
weight ATO_W;
run;
 Proc logistic data=CALPS DESCENDING;
	class cohort_cat/param=glm ;
	model Any_Fentanyl = cohort_cat; 
	weight ATO_W;
    estimate "Any_Fentanyl" cohort_cat 1 -1 / exp cl;
run;
/****Try different PS calculation code**********/
%stddiff(inds = analytic, 
                        groupvar = cohort_num, 
                        numvars = Gestational_Age CountSurg  ,
                        charvars = Sex_num NewRace_num Ethnicity_num NewInsurance_num Sedation_level_num,
                        wtvar = ,
                        stdfmt = 8.4,
                        outds = stddiff_result );
%stddiff(inds = ps_data, 
                        groupvar = cohort_num, 
                        numvars = Gestational_Age CountSurg  ,
                        charvars = Sex_num NewRace_num Ethnicity_num NewInsurance_num Sedation_level_num,
                        wtvar = siptw,
                        stdfmt = 8.4,
                        outds = stddiff_result );

%stddiff(inds = ps_data_trim, 
                        groupvar = cohort_num, 
                        numvars =  CountofSurg GA ,
                        charvars = Sex_num NewRace_num Ethnicity_num NewInsurance_num Sedation_level_num ,
                        wtvar = siptw,
                        stdfmt = 8.4,
                        outds = stddiff_result );
proc contents data=analytic;
run;
proc freq data= analytic;
table cohort_num/missing;
run;

/************Not used code*******************/

/***************Matching didn't work well for the dataset. My guess: the id is not unique
 %PSMatching(DATASET = CALPS, 
   TRTGRP = cohort_cat, 
   CASELEVEL = "Pre", CONTROLLEVEL = "Post" , SUBID= MRN, 
   PS=logit_ps, METHOD=nn, NUMBEROFCONTROLS=1, 
   REPLACEMENT=no, OUTDATA=formatch_nn, OUTPATH=&dir, DEBUG =F);
 proc freq data=formatch_nn;table race;where MATCH_ID ~=.;run;


*accessing the standard difference of formatch_nn;
%STD_DIFF(DATASET=formatch_nn, 
	      TRTGRP=cohort_cat, 
          CLIST =&c_var, 
          NLIST=&n_var logit_ps , 
          MATCH_ID= MATCH_ID,  
          OUTDATA=ASD, 
          OUTPATH=&dir, 
          REFASD =0.1,
          FNAME=PS.2 - Assess Balance by PS NN matching, 
	    ORIENTATION= PORTRAIT, DEBUG=F); 
***********************/


/****Conduct regression*****/
/*Any_Dex
Any_Fentanyl
Any_Lorazepam
Any_Midazolam
Any_Morphine
Any_Methadone
Any_Toradol
Any_Tylenol*/
/*** YES/No ****/
ODS HTML;

Proc logistic data=ps_data_trim DESCENDING;
    CLASS cohort_cat; 
	model Any_Fentanyl = cohort_cat; 
	weight siptw ; 
    estimate "Any_Fentanyl" cohort_cat 1 / exp cl;
run;

Proc logistic data=ps_data_trim DESCENDING;
    CLASS cohort_cat; 
	model Any_Lorazepam = cohort_cat; 
	weight siptw; 
	 estimate "Any_Lorazepam" cohort_cat 1 / exp cl;
run;
Proc logistic data=ps_data_trim DESCENDING;
    CLASS cohort_cat; 
	model Any_Midazolam = cohort_cat; 
	weight siptw; 
	 estimate "Any_Midazolam" cohort_cat 1 / exp cl;
run;
Proc logistic data=ps_data_trim DESCENDING;
    CLASS cohort_cat; 
	model Any_Morphine = cohort_cat; 
	weight siptw; 
	 estimate "Any_Morphine" cohort_cat 1 / exp cl;
run;
Proc logistic data=ps_data_trim DESCENDING;
    CLASS cohort_cat; 
	model Any_Methadone = cohort_cat; 
	weight siptw; 
	 estimate "Any_Methadone" cohort_cat 1 / exp cl;
run;
Proc logistic data=ps_data_trim DESCENDING;
    CLASS cohort_cat; 
	model Any_Toradol = cohort_cat; 
	weight siptw; 
	 estimate "Any_Toradol" cohort_cat 1 / exp cl;
run;
Proc logistic data=ps_data_trim DESCENDING;
    CLASS cohort_cat; 
	model Any_Tylenol = cohort_cat; 
	weight siptw ;
	 estimate "Any_Tylenol" cohort_cat 1 / exp cl;
run;

Proc logistic data=ps_data_trim DESCENDING;
    CLASS cohort_cat; 
	model Death_C = cohort_cat; 
	weight siptw ;
	 estimate "Death_C" cohort_cat 1 / exp cl;
run;
/*Unweighted*/
Proc logistic data=analytic DESCENDING;
    CLASS cohort_cat; 
	model Any_Fentanyl = cohort_cat; 
    estimate "Any_Fentanyl" cohort_cat 1 / exp cl;
run;

Proc logistic data=analytic DESCENDING;
    CLASS cohort_cat; 
	model Any_Lorazepam = cohort_cat; 
	 estimate "Any_Lorazepam" cohort_cat 1 / exp cl;
run;
Proc logistic data=analytic DESCENDING;
    CLASS cohort_cat; 
	model Any_Midazolam = cohort_cat; 
	 estimate "Any_Midazolam" cohort_cat 1 / exp cl;
run;
Proc logistic data=analytic DESCENDING;
    CLASS cohort_cat; 
	model Any_Morphine = cohort_cat; 
	 estimate "Any_Morphine" cohort_cat 1 / exp cl;
run;
Proc logistic data=analytic DESCENDING;
    CLASS cohort_cat; 
	model Any_Methadone = cohort_cat; 
	 estimate "Any_Methadone" cohort_cat 1 / exp cl;
run;
Proc logistic data=analytic DESCENDING;
    CLASS cohort_cat; 
	model Any_Toradol = cohort_cat; 
	 estimate "Any_Toradol" cohort_cat 1 / exp cl;
run;
Proc logistic data=analytic DESCENDING;
    CLASS cohort_cat; 
	model Any_Tylenol = cohort_cat; 
	 estimate "Any_Tylenol" cohort_cat 1 / exp cl;
run;

Proc logistic data=analytic DESCENDING;
    CLASS cohort_cat; 
	model Death_C = cohort_cat; 
	 estimate "Death_C" cohort_cat 1 / exp cl;
run;
/*adjusted*/
Proc logistic data=analytic DESCENDING;
    class NewInsurance;
	model Any_Fentanyl = cohort_num NewInsurance CountofSurg; 
run;
Proc logistic data=analytic DESCENDING;
    class NewInsurance;
	model Any_Lorazepam = cohort_num NewInsurance CountofSurg; 
run;
Proc logistic data=analytic DESCENDING;
    class NewInsurance;
	model Any_Midazolam = cohort_num NewInsurance CountofSurg; 
run;
Proc logistic data=analytic DESCENDING;
    class NewInsurance;
	model Any_Morphine = cohort_num NewInsurance CountofSurg; 
run;
Proc logistic data=analytic DESCENDING;
    class NewInsurance;
	model Any_Methadone = cohort_num NewInsurance CountofSurg; 
run;
Proc logistic data=analytic DESCENDING;
    class NewInsurance;
	model Any_Toradol = cohort_num NewInsurance CountofSurg; 
run;
Proc logistic data=analytic DESCENDING;
    class NewInsurance;
	model Any_Tylenol = cohort_num NewInsurance CountofSurg; 
run;




proc univariate data = analytic normal;
	var
Dexmedetomidine_Admin_Days
Dexmedetomidine_Per_Kilo_Per_Da1
Fentanyl_Admin_Days
Fentanyl_Per_Kilo_Per_Day_Days
Lorazepam_Admin_Days
Lorazepam_Per_Kilo_Per_Day_Days
Midazolam_Admin_Days
Midazolam_Per_Kilo_Per_Day_Days
Morphine_Admin_Days
Morphine_Per_Kilo_Per_Day_Days
Methadone_Admin_Days
Methadone_Per_Kilo_Per_Day_Days
Toradol_Admin_Days
Toradol_Per_Kilo_Per_Day_Days
Tylenol_Admin_Days
Tylenol_Per_Kilo_Per_Day_Days
dex_admin_days_log 
dex_per_kilo_per_dal_log 
fentanyl_admin_days_log 
fentanyl_per_kilo_per_dal_log
Lorazepam_admin_days_log 
Lorazepam_per_kilo_per_dal_log 
Midazolam_admin_days_log
Midazolam_per_kilo_per_dal_log 
orphine_admin_days_log
orphine_per_kilo_per_dal_log 
Methadone_admin_days_log 
Methadone_per_kilo_per_dal_log 
Toradol_admin_days_log 
Toradol_per_kilo_per_dal_log 
Tylenol_admin_days_log 
Tylenol_per_kilo_per_dal_log
los
;
	histogram 
Dexmedetomidine_Admin_Days
Dexmedetomidine_Per_Kilo_Per_Da1
Fentanyl_Admin_Days
Fentanyl_Per_Kilo_Per_Day_Days
Lorazepam_Admin_Days
Lorazepam_Per_Kilo_Per_Day_Days
Midazolam_Admin_Days
Midazolam_Per_Kilo_Per_Day_Days
Morphine_Admin_Days
Morphine_Per_Kilo_Per_Day_Days
Methadone_Admin_Days
Methadone_Per_Kilo_Per_Day_Days
Toradol_Admin_Days
Toradol_Per_Kilo_Per_Day_Days
Tylenol_Admin_Days
Tylenol_Per_Kilo_Per_Day_Days
dex_admin_days_log 
dex_per_kilo_per_dal_log 
fentanyl_admin_days_log 
fentanyl_per_kilo_per_dal_log
Lorazepam_admin_days_log 
Lorazepam_per_kilo_per_dal_log 
Midazolam_admin_days_log
Midazolam_per_kilo_per_dal_log 
orphine_admin_days_log
orphine_per_kilo_per_dal_log 
Methadone_admin_days_log 
Methadone_per_kilo_per_dal_log 
Toradol_admin_days_log 
Toradol_per_kilo_per_dal_log 
Tylenol_admin_days_log 
Tylenol_per_kilo_per_dal_log
los_log
;
run;
proc ttest data=ps_data_trim;
class cohort_num;
var dex_admin_days_log  fentanyl_admin_days_log Lorazepam_admin_days_log Midazolam_admin_days_log orphine_admin_days_log Methadone_admin_days_log
Toradol_admin_days_log Tylenol_admin_days_log los_log;
weight siptw;
run;
proc means  data=ps_data_trim mean cl;
var dex_admin_days_log  fentanyl_admin_days_log Lorazepam_admin_days_log Midazolam_admin_days_log orphine_admin_days_log Methadone_admin_days_log
Toradol_admin_days_log Tylenol_admin_days_log los_log;
weight siptw;
run;

proc ttest data=ps_data_trim;
class cohort_cat;
var dex_admin_days_log  fentanyl_admin_days_log Lorazepam_admin_days_log Midazolam_admin_days_log orphine_admin_days_log Methadone_admin_days_log
Toradol_admin_days_log Tylenol_admin_days_log los_log;
weight siptw;
run;

proc ttest data=ps_data_trim;
class cohort_cat;
var dex_per_kilo_per_dal_log  
fentanyl_per_kilo_per_dal_log 
Lorazepam_per_kilo_per_dal_log 
Midazolam_per_kilo_per_dal_log 
orphine_per_kilo_per_dal_log  
Methadone_per_kilo_per_dal_log  
Toradol_per_kilo_per_dal_log  
Tylenol_per_kilo_per_dal_log;
weight siptw;
run;
proc ttest data=ps_data_trim;
var dex_per_kilo_per_dal_log  
fentanyl_per_kilo_per_dal_log 
Lorazepam_per_kilo_per_dal_log 
Midazolam_per_kilo_per_dal_log 
orphine_per_kilo_per_dal_log  
Methadone_per_kilo_per_dal_log  
Toradol_per_kilo_per_dal_log  
Tylenol_per_kilo_per_dal_log;
weight siptw;
run;
proc means  data=ps_data_trim mean cl;
var dex_per_kilo_per_dal_log  
fentanyl_per_kilo_per_dal_log 
Lorazepam_per_kilo_per_dal_log 
Midazolam_per_kilo_per_dal_log 
orphine_per_kilo_per_dal_log  
Methadone_per_kilo_per_dal_log  
Toradol_per_kilo_per_dal_log  
Tylenol_per_kilo_per_dal_log;
weight siptw;
run;
proc means  data=ps_data_trim mean cl;
class cohort_cat;
var dex_per_kilo_per_dal_log  
fentanyl_per_kilo_per_dal_log 
Lorazepam_per_kilo_per_dal_log 
Midazolam_per_kilo_per_dal_log 
orphine_per_kilo_per_dal_log  
Methadone_per_kilo_per_dal_log  
Toradol_per_kilo_per_dal_log  
Tylenol_per_kilo_per_dal_log;
weight siptw;
run;


proc Reg data=ps_data_trim;
	title " linear regression-fentanyl_per_kilo_per_dal_log ";
	model fentanyl_per_kilo_per_dal_log = cohort_num; 
	weight siptw; 
	run;
 
proc Reg data=ps_data_trim;
	title " linear regression-Lorazepam_admin_days_log ";
	model Lorazepam_admin_days_log = cohort_num; 
	weight siptw; 
	run;
proc Reg data=ps_data_trim;
	title " linear regression-Lorazepam_per_kilo_per_dal_log ";
	model Lorazepam_per_kilo_per_dal_log = cohort_num; 
	weight siptw; 
	run;
 

proc Reg data=ps_data_trim;
	title " linear regression-Midazolam_admin_days_log ";
	model Midazolam_admin_days_log = cohort_num; 
	weight siptw; 
	run;
proc Reg data=ps_data_trim;
	title " linear regression-Midazolam_per_kilo_per_dal_log ";
	model Midazolam_per_kilo_per_dal_log = cohort_num; 
	weight siptw; 
	run;
 

proc Reg data=ps_data_trim;
	title " linear regression-orphine_admin_days_log ";
	model orphine_admin_days_log = cohort_num; 
	weight siptw; 
	run;
proc Reg data=ps_data_trim;
	title " linear regression-orphine_per_kilo_per_dal_log ";
	model orphine_per_kilo_per_dal_log = cohort_num; 
	weight siptw; 
	run;
 
 
proc Reg data=ps_data_trim;
	title " linear regression-Methadone_admin_days_log ";
	model Methadone_admin_days_log = cohort_num; 
	weight siptw; 
	run;
proc Reg data=ps_data_trim;
	title " linear regression-Methadone_per_kilo_per_dal_log ";
	model Methadone_per_kilo_per_dal_log = cohort_num; 
	weight siptw; 
	run;
 
 
proc Reg data=ps_data_trim;
	title " linear regression-Toradol_admin_days_log ";
	model Toradol_admin_days_log = cohort_num; 
	weight siptw; 
	run;
proc Reg data=ps_data_trim;
	title " linear regression-Toradol_per_kilo_per_dal_log ";
	model Toradol_per_kilo_per_dal_log = cohort_num; 
	weight siptw; 
	run;
 
 
proc Reg data=ps_data_trim;
	title " linear regression-Tylenol_admin_days_log ";
	model Tylenol_admin_days_log = cohort_num; 
	weight siptw; 
	run;
proc Reg data=ps_data_trim;
	title " linear regression-Tylenol_per_kilo_per_dal_log ";
	model Tylenol_per_kilo_per_dal_log = cohort_num; 
	weight siptw; 
	run;

	
proc mixed data=ps_data_trim covtest plots=(residualpanel pearsonpanel studentpanel);
      class MRN cohort_cat;
      model dex_admin_days_log = cohort_cat / s ddfm=sat;
      repeated / subject=MRN group=cohort_cat;
run;


/*Controlled for **/

proc glm  data=analytic;
	title " linear regression-fentanyl_admin_days_log ";
    class NewInsurance;
    model fentanyl_admin_days_log = cohort_num NewInsurance CountofSurg; 
	run;
proc Reg data=analytic;
	title " linear regression-fentanyl_per_kilo_per_dal_log ";
	run;
 
proc Reg data=analytic;
	title " linear regression-Lorazepam_admin_days_log ";
	model Lorazepam_admin_days_log = cohort_num NewInsurance CountofSurg; 
	run;
proc Reg data=analytic;
	title " linear regression-Lorazepam_per_kilo_per_dal_log ";
	model Lorazepam_per_kilo_per_dal_log = cohort_num NewInsurance CountofSurg; 
	run;
 

proc Reg data=analytic;
	title " linear regression-Midazolam_admin_days_log ";
	model Midazolam_admin_days_log = cohort_num NewInsurance CountofSurg; 
	run;
proc Reg data=analytic;
	title " linear regression-Midazolam_per_kilo_per_dal_log ";
	model Midazolam_per_kilo_per_dal_log = cohort_num NewInsurance CountofSurg;  
	run;
 

proc Reg data=analytic;
	title " linear regression-orphine_admin_days_log ";
	model orphine_admin_days_log = cohort_num NewInsurance CountofSurg; 
	run;
proc Reg data=analytic;
	title " linear regression-orphine_per_kilo_per_dal_log ";
	model orphine_per_kilo_per_dal_log = cohort_num NewInsurance CountofSurg; 
	run;
 
 
proc Reg data=analytic;
	title " linear regression-Methadone_admin_days_log ";
	model Methadone_admin_days_log = cohort_num NewInsurance CountofSurg; 
	run;
proc Reg data=analytic;
	title " linear regression-Methadone_per_kilo_per_dal_log ";
	model Methadone_per_kilo_per_dal_log = cohort_num NewInsurance CountofSurg;
	run;
 
 
proc Reg data=analytic;
	title " linear regression-Toradol_admin_days_log ";
	model Toradol_admin_days_log = cohort_num NewInsurance CountofSurg;
	run;
proc Reg data=analytic;
	title " linear regression-Toradol_per_kilo_per_dal_log ";
	model Toradol_per_kilo_per_dal_log = cohort_num NewInsurance CountofSurg;
	run;
 
 
proc Reg data=analytic;
	title " linear regression-Tylenol_admin_days_log ";
	model Tylenol_admin_days_log = cohort_num NewInsurance CountofSurg; 
	run;
proc Reg data=analytic;
	title " linear regression-Tylenol_per_kilo_per_dal_log ";
	model Tylenol_per_kilo_per_dal_log = cohort_num NewInsurance CountofSurg;
	run;
