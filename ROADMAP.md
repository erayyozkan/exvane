# Roadmap

Planned independent development: about 800 hours.

| # | Work | Hours | Done when |
|---|---|---|---|
| 1 | Consolidate the codebase into this repository: one layout, CI, tests passing, docs per module | 40 | CI green on every push; each folder has a README |
| 2 | Deploy S4 on Interactive Brokers: gateway deployment, daily data update, order generation, fill reconciliation, monitoring and a daily report | 140 | System runs daily without manual steps; live P&L tracked against the model |
| 3 | MT5 broker-data pipeline: export minute history 2019 to 2026 and rerun the FX and metals studies out of sample on broker prices | 70 | Every FX/metals verdict re-checked on broker data |
| 4 | Multi-instrument H1/H4 pullback EA with built-in research logging and a Python verification harness (look-ahead, random-walk null, sign tests) | 130 | EA reproduces annotated examples; harness passes; 25-instrument study run |
| 5 | Crypto perpetuals research: funding-aware momentum, and the crash-liquidity event study with open interest and funding data | 90 | Both pre-registered tests run and written up |
| 6 | S5 daily crypto book execution: limit-order rebalancing engine, cost tracking, tested on the exchange testnet | 110 | Engine runs end to end on testnet; realised costs measured against the 5 bps target |
| 7 | Order-flow pipeline on CME micro futures (MGC, MES, MNQ) with Databento MBO data | 120 | Signal-decay study by horizon, net of costs |
| 8 | Portfolio and risk layer: combine the books, correlation-cluster caps, volatility targeting across books, risk dashboard | 100 | One combined daily risk report across all books |
| | **Total** | **800** | |

## Rules that apply to every item

- Pre-register before running.
- Model costs before claiming an edge.
- Keep the holdout sealed until the final check.
- Every pull request gets an independent review pass against the checklist in CONTRIBUTING.md.
- Write the verdict, including when the answer is "no edge".
