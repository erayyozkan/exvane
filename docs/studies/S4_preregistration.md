# S4 v1 pre-registration (written 2026-10-07, before any S4 result was computed)

Context: the Beyond study (tests of public strategy families) found that diversified futures trend plus carry is the only family that clears 50 years at today's costs, with an EWMAC trend signal on 90 markets. S4 is the planned portfolio layer over DSR. This test asks: does the carry finding hold with the DSR signal itself (Donchian stop-and-reverse ensemble) on an S4-sized universe traded in the smallest available contracts, and how much capital does S4 need?

Honesty note: this uses the same daily futures dataset (public `pysystemtrade` data, to March 2024; see `ACKNOWLEDGEMENTS.md`) as the Beyond study, and two choices below (no carry on equity indices or ags; the 10% no-trade band) were informed by that study. So this is a transfer test, not an out-of-sample test. The out-of-sample test is April 2024 to today on broker data (separate).

## Universe (42 markets, fixed now; price series from the main contract, size and costs from the smallest contract in the dataset's instrument config)

- Equity (7): SP500 (SP500_micro), NASDAQ (NASDAQ_micro), RUSSELL_mini (RUSSELL micro), EUROSTX, DAX, NIKKEI, FTSE100
- Bond and rates (10): US2 US5 US10 US20 BUND BOBL SHATZ BTP OAT SOFR
- FX (8): EUR (EUR_micro), JPY (JPY_mini), GBP (GBP_micro), AUD (AUD_micro), CAD (CAD_micro), CHF (CHF_micro), MXP, NZD
- Metals (4): GOLD (GOLD_micro), SILVER, COPPER (COPPER-micro), PLAT
- Energy (5): CRUDE_W (CRUDE_W_micro), BRENT_W, HEATOIL, GASOILINE (GASOILINE_micro), GAS_US (GAS_US_mini)
- Ags (8): CORN (CORN_mini), WHEAT (WHEAT_mini), SOYBEAN (SOYBEAN_mini), SOYMEAL, SOYOIL, SUGAR11, LIVECOW, LEANHOG

## Signals

- Trend (DSR): for N = 20, 40, 80, 160, state = +1 after a close above the highest close of the prior N days, -1 after a close below the lowest close of the prior N days, else unchanged (stop and reverse, starts flat). Raw = mean of the four states. Forecast = raw x 10 / (expanding pooled mean of |raw| across all live markets up to the previous day), capped +-20. Closes only (the dataset has no highs or lows).
- Carry: as in the Beyond study (annualised roll / annualised price vol, EWMA span 30, x30, capped +-20).
- Combination (S4-TC): Bond, FX, Metals, Energy: average of trend and carry forecasts, capped +-20. Equity and Ags: trend only.

## Portfolio and execution

- Base position (fraction of capital) = forecast / 10 x 0.20 / instrument vol x asset-class weight (classes equal, equal within class), as in the Beyond engine (vol = EWMA span 35, floored at half its 504-day median; live after 256 days).
- Portfolio vol target 15%: scale k_t = 0.15 / (EWMA span 60 realised vol of the unscaled base book's daily P&L, lagged one day), capped at 4.
- No-trade band: hold the current position while it is within +-10% of the forecast-10 position around the target; otherwise trade to the nearest edge.
- Decide at close t, trade at close t+1. Costs per traded notional = (smallest contract's SpreadCost + PerBlock / Pointsize) / price + Percentage; two trades per roll.

## Cells

- S4-T: trend only.
- S4-TC: trend + carry as above. PRIMARY.
- S4-TCall: carry also on Equity and Ags (sensitivity: the exclusion came from the Beyond data).
- S4-EW: EWMAC trend (Beyond test B rules) + carry as in S4-TC, same universe (signal-choice control).
- Rounding: S4-TC with whole contracts (smallest contract, converted to USD with the dataset's FX rates) at capital USD 100k, 250k, 500k, 1M, 2M. Band applied in contracts: trade only when the rounded target leaves the band, to the nearest whole contract inside it.

## Rules

- S4-TC PASS: net Sharpe >= 0.3 in both halves, >= 0.2 from 2010, t >= 2.5. KILL below 0.1 overall or negative from 2010.
- Carry adds value if S4-TC net Sharpe exceeds S4-T in both halves AND from 2010. Otherwise S4 ships trend-only (DSR as is).
- Minimum capital = the smallest level where the rounded full-sample Sharpe is >= 90% of the unrounded one AND at least 80% of live markets can hold at least one contract at forecast 10 (median over days since 2010).
- Also reported (not rules): from 2020, 2x costs, shift null (200 draws), deflated Sharpe with the trial count now 15 + 4 = 19, realised vol vs 15% target, worst drawdown.

## Part 2: small account (added 2026-10-07 after choosing a futures broker via Python with under USD 250k; written before any small-account result)

Inputs carried from Part 1 results (stated openly): the Beyond cost rule (round-trip cost above 0.01 Sharpe units -> not traded) removes the micro RBOB contract, leaving 41 markets; both S4-TC and the post-hoc blend (trend = average of Donchian and EWMAC forecasts) go forward.

- Market selection for capital C (uses contract specs, prices and volatility on the last date only, never returns): u_i = forecast-10 position in contracts = k_med x 0.20 x class weight_i x C / (price x point size x FX x vol), where k_med is the median portfolio scale of the Part 1 S4-TC run. Repeatedly drop the market with the smallest u_i until every remaining market has u_i >= 1, recomputing class weights each time (a class with no market left is dropped).
- Cells for C = 50k, 100k, 150k, 250k: S4-TC-small and Blend-small, whole contracts at C, same band, costs, delay and vol target. Reported next to the same rounding on all 41 markets.
- Same pass rule as Part 1 (each half >= 0.3, from 2010 >= 0.2, t >= 2.5). Smallest C that passes for S4-TC-small = the recommended minimum.

## Part 3: live paper trading as the out-of-sample test (pre-registered now, before it starts)

- Books tracked from the first live day: S4-TC and Blend, on the small-account universe for the account's capital, orders generated daily by the S4 code, fills recorded.
- 12-month checks (implementation, not edge; a one-year Sharpe of a 0.4-Sharpe system has a standard error of about 1): paper P&L tracks the model P&L on the same prices within 2% of capital per year; realised costs within 2x the model; no order or roll error left unexplained.
- Stop rules: drawdown deeper than 1.5x the worst backtest drawdown since 2000 at the same vol target; or realised costs above 3x model for 3 months.
- Edge verdict needs 3+ years of live or broker data; until then live size stays small.

## Outcome of Part 2 and Amendment 2 (2026-10-07, before the first live or paper day)

- Part 2 rule outcome: S4-TC-small did not pass at any capital (UNPROVEN at 50k, 100k, 150k, 250k), so the rule gives no minimum capital. Dropping markets to fit the account removed breadth and cost more than whole-contract rounding.
- Reported alongside (not a registered decision cell): all 41 markets with whole-contract rounding passed for S4-TC at 100k (0.85; 0.20 from 2010), 150k (0.93; 0.22) and 250k (0.98; 0.32), and failed at 50k.
- Amendment 2: the live and paper books use all 41 markets with whole-contract rounding at the account's capital; a market whose forecast-10 position is below one contract holds 0 or 1 contracts as the band allows. The live account trades book TC (registered primary); book BLEND is tracked on paper next to it. Part 3 checks and stop rules apply unchanged.
- Amendment 3 (implementation, after an independent code review): roll offsets changed so that every traded contract is left at least 3 business days before its exit deadline (Brent and Nikkei expiry offsets, CME FX, US Treasuries, Eurex bonds and platinum roll offsets; the list of changed offsets ships with `live/s4live`). This moves which month the live data series follows on some days; it does not change any rule. Live costs are modelled with the traded contract's roll calendar.
