function [adf, adfresid, df, dfresid] = unitroot (series)
%UNITROOT (Augmented) Dickey-Fuller and Phillips-Perron tests of the unit-root hypothesis
%
% [ADF, ADFRESID, DF, DFRESID] = UNITROOT (SERIES) tests the null hypothesis of the
%    existence of a unit root in SERIES and returns
%
%    - matrix ADF with the results for the Augmented Dickey-Fuller regression with the
%      highest number of augmented terms (dlags), if any, significant at the 5% level,
%    - vector ADFRESID with the residuals of the ADF regression,
%    - matrix DF with the results for the Dickey-Fuller regression, and
%    - vector DFRESID with the residuals of the DF regression.
%
% REQUIRES the MATLAB Statistics Toolbox (function files NORMCDF.M and TCDF.M) and
% the author's function files ADFREG.M, DFCRIT.M, DURBINH.M, DWATSON.M, and PHILLIPS.M.
%
% The general form of the regressions is:
%
% dseries = beta_0 + beta_1*series(-1) {+ beta_2*dseries(-1) + beta_3*dseries(-2) + ...}
%                                                                                 + resid;
% The matrices returned are structured as follows:
%
%    {a}df = [ sigma    dw       beta_0   beta_1   {beta_2  ... }
%              tpp      dh       t_0      t_1      {t_2     ... }
%              tppsig   dhsig    NaN      tsig_1   {tsig_2  ... } ]
%
% where sigma = the estimated standard error of the residuals
%          dw = the Durbin-Watson statistics of the residuals
%          dh = the Durbin h statistic of the residuals
%       dhsig = the level of significance at which the (two-sided) null hypothesis
%               of no (first-order) autocorrelation in the residuals is rejected
%
% beta_0, beta_1 {,beta_2,...} = the estimated values of the coefficients (as above)
%
% t_0,    t_1    {,t_2,   ...} = the (uncorrected) t-ratios on the coefficients
%         tpp                  = the Phillips-Perron corrected t-ratio on beta_1
%
%         tsig_1,
%         tppsig               = the levels at which tsig_1 and tpp are statistically
%                                significantly, using Dickey-Fuller critical values
%                 {tsig_2, ... = the level at which t_2,... are statistically significant,
%                                using t-table critical values}
%
% So, reject a unit root,
%   - if t_1 in the ADF regression is statistically significant, e.g. tsig_1 <= 0.1,
%     AND the residuals are not correlated (otherwise the test statistic is inefficient),
%   - or if tpp (in any regression) is statistically significant (- or both).
% (Reject random walk, if unit root is rejected, or some dlags are significant, or both.)
%
% See also the NOTE section at the bottom of the script and all the files by the same
% author called by this script.
%
% The author assumes no responsibility for errors or damage resulting from usage. All
% rights reserved. Usage of the programme in applications and alterations of the code
% should be referenced. This script may be redistributed if nothing has been added or
% removed and nothing is charged. Positive or negative feedback would be appreciated.

%                     Copyright (c) 17 March 1998 by Ludwig Kanzler
%                     Department of Economics, University of Oxford
%                     Postal: Christ Church,  Oxford OX1 1DP,  U.K.
%                     E-mail: ludwig.kanzler@economics.oxford.ac.uk
%                     Homepage:      http://users.ox.ac.uk/~econlrk
%                     $ Revision: 1.33 $$ Date: 10 September 1998 $

obs = length(series);

% First add dlags/augterms one by one as long as they are significant at the 5% level;
% as soon as the dlag added last is found not to be significant, stop the procedure and
% save the previous lag order (see ADFREG.M for details).
for augterms = 1 : obs-3
   [beta, se, t, tsig] = adfreg (series, augterms);
   if tsig(2+augterms) > 0.05
      augterms = augterms - 1;
      break
   end
end

% Then run and evaluate the Dickey-Fuller and Augmented Dickey Fuller regressions (this is
% done by the below sub-function):
[adf, adfresid]  = evaluate (series, obs, augterms);
if nargout > 2 & augterms
   [df, dfresid] = evaluate (series, obs, 0);
elseif nargout > 2
   df      = adf;
   dfresid = adfresid;
end

% End of main function.

function [results, resid] = evaluate (timeseries, nobs, dlags)

% THE (AUGMENTED) DICKEY-FULLER REGRESSION (see ADFREG.M for the details):
[beta, se, t, tsig, resid, rss, sigma] = adfreg (timeseries, dlags);

% Compute the DURBIN-WATSON d STATISTIC to check for first-order serial correlation in the
% residuals. Adding a sufficient number of dlags, as done in the above procedure, should
% produce "correlation-free" residuals so that the ADF regression estimators become
% unbiased; the Durbin-Watson statistic offers one means of checking this.
%    NOTE that the DW statistic is biased towards 2.00 (indicating zero autocorrelation)
% when differenced lags are present, but can nevertheless be used to gauge the degree
% of autocorrelation (see DWATSON.M for details).
[dw, dwsigup, dwsiglow] = dwatson(resid);

% The Durbin-h statistic is robust to the inclusion of any lagged terms and is here
% evaluated in a two-sided test, i.e. against the alternative hypothesis of positive OR
% negative autocorrelation (see DWATSON.M for details):
[dh, dhsig] = durbinh (dw, se(2), nobs-dlags-1, 2);

% An alternative method to the above approach of finding the best-specification ADF
% regression and evaluating the unit-root hypothesis only on that regression is to follow
% Phillips (1987) and Phillips & Perron (1988) and compute the PHILLIPS-PERRON T-RATIO
% "corrected" for potential autocorrelation and/or heteroskedasticity (see PHILLIPS.M for
% details).
[tpp, tppsig] = phillips (se(2), t(2), resid, rss, sigma, nobs);

% COLLECT ALL RELEVANT STATISTICS in a matrix:
results  = [ sigma    dw       beta'
             tpp      dh       t'
             tppsig   dhsig    tsig'  ];

% End of sub-function.


% A NOTE ON EXTENDED USAGE:
%
% The above d and h statistics are designed to capture only first-order autocorrelations,
% but of course there may be serial correlation of higher orders. It is thus recommended
% to check also the existence serial correlation at higher orders. To do this, perform
% the BOX-PIERCE (1970) Q TEST (the most popular portmanteau, or "hat-stand", test),
% using Ljung & Box's (1978) finite-sample correction (see the author's QSTAT.M function
% file for details). Ideally, the DF/ADF model should be so well specified that no serial
% correlation is left in the residuals, so one should fail to reject the null hypothesis
% of no correlation at ANY lag order. In practice, this is unrealistic, because even the
% best fitting ADF model found through the author's above procedure is of insufficient lag
% order to whiten the residuals at high lag orders.
%    While the above tests are all concerned with autocorrelation in means, i.e. what is
% usually just called "serial correlation", it is also a good idea to check for serial
% correlation in variances, i.e. heteroskedasticity. Recall that the objective of
% including augmented terms in the Dickey-Fuller regression is to improve model
% specification to the extent that hypothesis testing on the coefficients of the
% regression model becomes valid and as efficient as possible. Ideally, the ADF model
% should be specified well enough to make the residuals free of serial correlation -
% otherwise the coefficient estimates are biased - and also of heteroskedasticity -
% otherwise the coefficient estimates will be inefficient, which poses a problem to
% hypothesis testing on the ADF model. (But note that zero correlation and
% homoskedasticity are not required for the Phillips-Perron approach also pursued above).
% There are many potential ways of checking for heteroskedasticity, but given the
% prevalence of Auto-Regressive Conditional Heteroskedasticity in financial time series,
% Engle's ARCH test with finite-sample correction is generally a very good choice, and it
% can be performed using the author's ARCHTEST.M function (see the file for more details).


% REFERENCES can be found in the reference sections of the author's function files called
% by this script.


% End of file.