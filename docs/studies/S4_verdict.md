# S4 v1: DSR trend + carry on futures (2026-10-07)

Rules: [`S4_preregistration.md`](S4_preregistration.md) (Parts 1-3, Amendments 2 and 3). Code: research scripts in `research/s4/`, live package in `live/s4live/` (no price data).

Live route: futures through Interactive Brokers via Python, account under USD 250k, out-of-sample test = 12 months of live paper trading (broker data from April 2024 onward is not yet in the study).

## Rules

DSR Donchian stop-and-reverse ensemble 20/40/80/160 on closes (forecast = mean state x 10 / 0.6446 frozen scalar, cap 20) plus carry (annualised roll / price vol, EWMA 30, x30, cap 20), averaged 50/50 for bonds, FX, metals and energy; trend only for equities and agriculturals. Inverse-vol sizing at 20% per instrument, equal asset-class risk, portfolio scaled to 15% vol (60-day realised, cap 4x), 10% no-trade band, whole contracts, decide on the close and trade the next session. 41 markets (micro RBOB excluded by the 0.01 Sharpe round-trip cost rule); signals from main contracts, trades in micro and mini contracts.

## Results (daily futures data to March 2024, net, unrounded; full / first half / second half / from 2010 / from 2020)

- S4-T, DSR only: 0.75 / 1.08 / 0.41 / 0.17 / 0.25 (unproven)
- **S4-TC, trend + carry: 0.85 / 1.15 / 0.55 / 0.24 / 0.20 (pass, registered primary).** Carry adds value by rule (+0.07 first half, +0.13 second half, +0.07 from 2010; -0.05 from 2020).
- S4-TCall: 0.80 / 0.98 / 0.63 / 0.29 / 0.17 (pass)
- S4-EW (EWMAC + carry): 0.88 / 1.08 / 0.68 / 0.42 / 0.34 (pass)
- Post-hoc: without micro RBOB, S4-TC 1.00 full / 0.37 from 2010; BLEND (Donchian + EWMAC trend, plus carry) 1.03 / 0.47 from 2010 / 0.35 from 2020.
- Costs 25% of gross as registered (micro RBOB alone 2.1% of capital a year); 14% without it. Shift null p < 0.005. Deflated Sharpe (19 trials) 0.69 empirical / 1.00 theoretical.

## Capital (whole contracts, net Sharpe from 2010)

- All 41 markets: S4-TC -0.08 at 50k (kill), 0.20 at 100k, 0.22 at 150k, 0.32 at 250k (pass at 100k and above); BLEND 0.08 / 0.13 / 0.29 / 0.46.
- Registered small-account rule (drop markets until each holds at least 1 contract): S4-TC-small never passed (0.04 to 0.15 from 2010). Amendment 2: live uses all 41 markets with rounding.
- At 150k (S4-TC, all 41): about 2.9% a year above cash since 2010, 12.9% realised vol, worst drawdown since 2000 43% of capital, about 890 contracts traded a year, 37% of markets can hold a full contract at forecast 10.

## Live system (s4live)

Commands: `update` (closes to yesterday from IB, roll calendar), `check` (qualify contracts, roll-to-expiry margins), `orders` (dry run unless `--submit`; paper account only unless `--allow-live`), `fills`, `paper` (model books TC and BLEND).

Independent code review: 5 critical and 7 major issues found and fixed (position-month mapping from IB contract details; Brent, Nikkei, FX, Treasury, platinum and Eurex roll timing; stale-data and partial-bar guards; one submission per day; data cleaning identical to research). 36 offline tests pass (17 library, 19 live with a fake gateway). Not yet connected to a real IB Gateway.

## Next

1. IB paper account and market data subscriptions (CME, CBOT, NYMEX, COMEX, ICE US, ICE Europe, Eurex, OSE); seed with `update --lookback 700`; run `check`.
2. Paper trade TC (BLEND tracked) for 12 months. Pass: P&L within 2% of capital of the model, costs within 2x, no unexplained errors. Stop if drawdown exceeds 1.5x the worst backtest since 2000, or costs exceed 3x for 3 months.
3. Decide live size in October 2027.
