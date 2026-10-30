# S1 research verdict (2026-10-07)

## Verdict

S1 (two-period one-sided break on the bias timeframe, entry at the extreme M15 body of the trade period, stop at the trade-period extreme, TP 2R plus a trail leg) has no edge. After real spreads and prop-firm commission ($5 per lot on FX, 0.0014% of notional on metals, none on indices), none of 2,010 configuration x instrument cells (67 configurations x 30 instruments: 28 FX pairs, gold, silver) is positive in both 2007-2016 and 2017-2022. It should not be run live, and further optimisation of S1 is not worth doing.

## Key numbers (R per unit of total risk, after costs, trade-weighted)

- Original EA, 4h bias / 15m entries: -0.60R in 2007-2016, -0.56R in 2017-2022, -0.34R on 13 broker series in 2023-2026; about 384 filled setups per year per pair.
- Original EA, 1h / 5m: -0.74R, -0.68R, -0.43R.
- Least-bad family (mitigation entry + stop at the bias-period extreme): 4h -0.14 / -0.15 / -0.06; 8h bias with 30m entries -0.09 / -0.10 / -0.02.
- By bias timeframe, original / least-bad, 2007-2022: 30m -0.78/-0.30, 1h -0.73/-0.24, 2h -0.65/-0.18, 3h -0.60/-0.15, 4h -0.60/-0.15, 6h -0.50/-0.10, 8h -0.49/-0.09. Lower timeframes lose more because the stop shrinks while costs stay fixed.
- Every knob at 4h: only stop-widening variants move the result (-0.13 to -0.29R); targets, trail rules, breakeven, filters, offsets, order life and direction all land between -0.54 and -0.63R.
- Cause: the stop is about 0.09 of the 4h average range (median 3 pips on EURUSD); spread plus commission cost about 0.65R per trade at 4h and 0.78R at 1h against a gross edge of about +0.05R.
- Null test at mid prices without costs: S1 break +0.05R, every-bar setups +0.06 / +0.07, opposite break +0.07 / +0.08. S1 beats every-bar setups on only 7 of 30 instruments at 1h and 8 of 30 at 4h.
- Forward drift after a break, pooled over 30 instruments, next 4h in the break direction: -0.011 (long) and -0.005 (short) of the average 4h range. No continuation.
- Real but untradable finding: after a strong 1h close, price gives back about 0.04 of the 1h range within the hour (rank IC -0.05, t -26, negative in 83 of 84 pair-years); 0.5 to 1 pip, below retail costs.
- EURUSD lost every year 2007-2022. The top 1% of legs carry 20% of gross profit on EURUSD and up to 63% on silver.
- Data caveat: Dukascopy mirror data end in mid-2018 for every pair except EURUSD (mid-2022), so "2017-2022" is mostly 2017 to mid-2018.

## EA v3 fixes

- Magic-number filter: the old EA closed every position and deleted every pending order on the account (other EAs and manual trades included) at end of life or 23:45.
- Long marubozu rescan refused last-candle setups even with `LastCandleNoTrade` off.
- `SHORT_MAX` as a starting value broke longs on instruments priced above 32,767.
- Trail ladder stepped in R + 4 ticks instead of R (`LadderUnitIsRisk = true` follows the spec).
- New inputs: `EntryTimeframe`, `SL_Mode`, `SizingBalance`; EarlyTrade once per period; hedging-account guard; CSV log of setups and deals.

## Recommendations

1. Do not run S1 live.
2. Stop optimising S1: widening the stop only shrinks the loss toward zero; every other knob moves the result by less than 0.06R.
3. Keep the mean-reversion finding as an entry-timing rule (wait, or use a limit, after a strong 1h close).
4. Lower-timeframe edges need a cost advantage (maker fills, futures commissions) or information the chart does not show (order flow).

## Data and method

- Dukascopy ticks rebuilt into minute bid/ask bars in New-York-close server time with a high-before-low flag.
- Broker history 2023-2026 read from MT5 history files.
- Validation: tick replay of EURUSD 2018 agrees with the minute engine on 98.6 to 100% of trades. An independent rebuild of the EA matched EURUSD fill counts within 0.2% and mean R within about 0.01R. The replica reproduces hand-annotated walkthrough trades.
- Discipline: 67 configurations fixed before running; judged on 2007-2016, then checked on 2017-2022 and the 2023-2026 holdout.
