# MQL5 Expert Advisors

| File | EA | Notes |
|---|---|---|
| `s1/S1_v3.mq5` | S1 range break, v3 | Magic-number filter, hedging-account guard, `SL_Mode` and `EntryTimeframe` research switches, CSV log of setups and deals in `Common\Files` |
| `dsr/DSR_Ensemble_v6.mq5` | Donchian stop-and-reverse ensemble, v6 | Four channel lengths (20/40/80/160) at equal risk, volatility-targeted sizing, restart-safe state rebuild, per-rung research CSV net of spread, commission and swap |

Both EAs use only the standard MQL5 library. No third-party includes are needed.

## Build

Copy a folder into `MQL5/Experts/Exvane/` in the MetaTrader 5 data folder and compile in MetaEditor. Compiled `.ex5` files are not committed.

## Tester settings used in the studies

Every tick based on real ticks. For S1, `SizingBalance` fixes the risk per trade so Expected Payoff reads directly in R. See each study in `docs/studies/`.
