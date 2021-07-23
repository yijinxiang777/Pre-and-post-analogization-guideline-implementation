*SUPPLEMENTAL MATERIAL:
Example SAS code;
/********************************************************************************/
/* This code demonstrates estimating a propensity score, calculating weights, 	*/
/* evaluating the distribution of the propensity score by treatment group, and 	*/
/* evaluating treatment effect heterogeneity over the distribution of the     	*/
/* propensity score.                              								*/
/*                                        										*/
/* This program written in SAS 9.2 TM, February 2013              				*/
/*                                        										*/
/* Prepared by Bradley Layton, PhD at the University of North Carolina at    	*/
/* Chapel Hill                                  								*/
/********************************************************************************/
/********************************************************************************/
/* Variable Definitions:                            							*/
/*                                        										*/
/* x = binary [0,1] treatment variable                      					*/
/* y = binary [0,1] outcome variable                      						*/
/* c1 - c5 = binary [0,1] covariates 											*/
/* y_dur = time until censoring for event y                   					*/
/********************************************************************************/

/********************************************/
/* Estimating a propensity score       		*/
/********************************************/

/* Modeling treatment = 1 given covariates and outputting data with the propensity score
 into a new dataset, 'PS_DATA'
 PS = estimated propensity score      */

proc logistic data=analytic noprint;
class Sex NewRace Ethnicity NewInsurance Sedation_level_num/param=glm;
model cohort_cat = Sex NewRace Ethnicity NewInsurance Gestational_Age CountSurg Sedation_level_num;roc;
OUTPUT OUT=ps_data PROB=ps;
TITLE "Estimation of the propensity score from measured covariates";
run;

/********************************************/
/* Evaluating the PS distribution       */
/********************************************/
/* Creating PS treatment groups for plotting */

DATA ps_data;
SET ps_data;
IF cohort_cat = "Post" THEN Post_ps = ps;
    ELSE Post_ps = .;
IF cohort_cat = "Pre " THEN Pre_ps = ps;
    ELSE Pre_ps = .;
RUN;

/* Plot the overlap of the PS distributions by treatment group
 Turn on ODS output to get high quality graphics saved as an image file
 PLOTS=ALL gives you multiple plots. If you only want the overlay plot,
 use PLOTS=DENSITYOVERLAY */

ODS GRAPHICS ON;
PROC KDE DATA=ps_data;
UNIVAR Pre_ps Post_ps / PLOTS=densityoverlay;
TITLE "Propensity score distributions by treatment group";
RUN;
ODS GRAPHICS OFF;

/********************************************/
/* Calculating PS weights          */
/********************************************/
/* Calculating the marginal probability of treatment for the stabilized IPTW */

PROC MEANS DATA=ps_data(keep=ps) NOPRINT;
VAR ps;
OUTPUT OUT=ps_mean MEAN=marg_prob;
RUN;
DATA _NULL_;
SET ps_mean;
CALL SYMPUT("marg_prob",marg_prob);
RUN;

/* Calculating weights from the propensity score */
DATA ps_data;
SET ps_data;
*Calculating IPTW;
IF cohort_cat = "Post" THEN iptw = 1/ps;
    ELSE IF cohort_cat = "Pre " then iptw = 1/(1-ps);
*Calculating stabilized IPTW;
IF cohort_cat = "Post" THEN siptw = &marg_prob/ps;
    ELSE IF cohort_cat = "Pre " THEN siptw = (1-&marg_prob)/(1-ps);
*Calculating SMRW;
IF cohort_cat = "Post" THEN smrw = 1;
    ELSE IF cohort_cat = "Pre " THEN smrw = ps/(1-ps);
LABEL ps = "Propensity Score"
    iptw = "Inverse Probability of Treatment Weight"
    siptw = "Stabilized Inverse Probability of Treatment Weight"
    smrw = "Standardized Mortality Ratio Weight";
RUN;

/********************************************/
/* Evaluating the weights and preparing for */
/* trimming if necessary          */
/********************************************/
/* Performing univariate analysis on the weight variables by treatment status
 to check for extreme weights */
ods pdf file="Evaluating weights by treatment group.pdf";
PROC UNIVARIATE DATA=ps_data;
*CLASS studyType;
VAR iptw siptw smrw;
HISTOGRAM iptw siptw smrw;
TITLE "Evaluating weights by treatment group";
RUN;
ods pdf close;
/* Identifying percentiles at the upper and lower extremes of the untreated and treated
PS distributions for trimming, if needed. If other percentiles are needed, they can
be created in the OUTPUT statement either by using a predefined SAS percentile,
or by creating one in PCTLPTS=" */
PROC UNIVARIATE DATA=ps_data NOPRINT;
CLASS cohort_cat;
VAR ps;
OUTPUT OUT=ps_pctl MIN=min MAX=max P1=p1 P99=p99 PCTLPTS=0.5 99.5 PCTLPRE=p;
title "Distribution of Propensity Score for Statin use, by statin use";
RUN;

/* Labeling the percentiles at the lower extremes of the treated in macro variables which can be
called later.
Defining the minimum, 0.5th percentiles, and 1st percentile of the treated */
DATA _NULL_;
SET ps_pctl;
WHERE cohort_cat = "Post";
CALL SYMPUT("post_min",min);
CALL SYMPUT("post_05",p0_5);
CALL SYMPUT("post_1",p1);
RUN;

/* Labeling the percentiles at the upper extremes of the untreated in macro variables
 which can be called later.
 Defining the maximum, 99th, and 99.5th percentile of the untreated. */
DATA _NULL_;
SET ps_pctl;
WHERE cohort_cat = "Pre ";
CALL SYMPUT("pre_max",max);
CALL SYMPUT("pre_99",p99);
CALL SYMPUT("pre_995",p99_5);
RUN;

/* When applying PS weights to analyses, these defined percentiles can be applied to trim areas
 of non-overlap and individuals treated contrary to prediction.
 To trim non-overlapping regions of the PS distribution, include the following statement
 in the modeling procedure: WHERE &post_min <= ps <= &pre_max;
 To trim those treated contrary to prediction, include the following
 statement: WHERE &post_05 <= ps <= &pre_995
 Trimming percentiles can be moved in progressively as far as desired */

data ps_data_trim;
set ps_data;
if &post_min <= ps <= &pre_max;
run;
data ps_data_trim;
set ps_data;
if &post_05 <= ps <= &pre_995;
run;


proc export 
  data=ps_data_trim 
  dbms=xlsx 
  outfile="&root.\Analysis\Out Data\ps_data_trim.xlsx" 
  replace;
run;
