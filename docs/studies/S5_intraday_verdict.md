# S5 intraday study: verdict (2026-10-07)

Question: can S5 be improved, and is there a crypto strategy that works on minutes or hours?

Short answer: **minutes, no. Hours, nothing that passes; one rare-event idea survives out of sample but is not confirmed. S5 improves through cheaper execution, not a faster clock.**

Data: Binance spot klines, 10 coins (BTC ETH SOL BNB XRP TRX DOGE ZEC ADA BCH), 5m and 1h bars 2019-2025, 1m bars 2025. Spot prices stand in for perps; costs are perp costs. 2026 stays sealed.

## 1. The cost wall

Median coin, 2025. IC needed = forecast correlation needed to break even when re-deciding every bar.

| Horizon | Typical move (bps) | Round-trip cost / typical move | IC needed, taker 6 bps | IC needed, maker 2 bps |
|---|---|---|---|---|
| 1 min | 11.5 | 2.5x | 0.65 | 0.22 |
| 5 min | 25.6 | 1.1x | 0.29 | 0.10 |
| 15 min | 43.9 | 0.6x | 0.17 | 0.06 |
| 1 hour | 85.2 | 0.3x | 0.09 | 0.03 |
| 4 hours | 168.7 | 0.16x | 0.045 | 0.015 |
| 1 day | 406.6 | 0.05x | 0.018 | 0.006 |

A good public-data signal has an IC of 0.01 to 0.05. Below about 4 hours, trading every bar cannot pay.

## 2. Pre-registered tests

| Test | What | Result | Verdict |
|---|---|---|---|
| H1 | Momentum on an hourly vs daily clock | Net Sharpe 0.73 hourly vs **0.87 daily** | Failed: a days signal |
| H2 | BTC leads alts at 5 min | +0.9 bps gross vs 12 bps round trip (251,641 trades) | Dead |
| H3 | Fade volume-confirmed hourly shocks, 4h hold | +3.7 bps gross, **-16.3 bps net**, t -1.22 | Killed |

## 3. Post-hoc diagnostics, re-tested on unseen 2019

Market-wide down shocks revert (forced liquidation); single-coin shocks and pumps continue (news).

| | 2020-2025 (in sample) | 2019 (out of sample) |
|---|---|---|
| R1 crash liquidity: buy after a market-wide volume-confirmed down shock, hold 4h | +62 bps net, t 1.43, 843 trades | **+22.5 bps net, t 0.85**, 108 trades |
| R2 pump continuation | +23 bps net, t 1.32 | **-11.8 bps net**, dead |

R1 is not confirmed: five crash hours produce 91% of its profit, its worst trade is -19%, and the sample is a few dozen independent events. Correlation with the daily S5 book is 0.01.

## 4. How to improve S5

1. Do not speed it up.
2. Cut execution cost with limit-order rebalancing (10 bps per side: Sharpe 0.77; 5 bps: 0.90).
3. Test funding-aware momentum on perp data (pre-registered).

## 5. Verification

- 9 synthetic controls pass (noise gives nothing; planted reversal and lead-lag are found; no look-ahead).
- An independent re-implementation from the written spec reproduced H2, H3 and R1 to the decimal.
- One flaw found and fixed: the shift null shifted each coin separately, which breaks crash clustering. For rare events the clustered t-stat is the statistic to trust.

## Sources

- The Quarter-Hour Effect: Periodic Algorithmic Trading and Return Predictability in Cryptocurrency Futures, arXiv 2607.09426
