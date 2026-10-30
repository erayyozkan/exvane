# Exvane

**A systematic trading research and execution platform.** Exvane turns trading ideas into testable hypotheses, tests them against realistic costs and long history, and lets only the survivors reach a live account.

Most ideas do not survive. That is the point: the platform is built to kill bad strategies cheaply and early, before they cost real money.

## What is in this repository

| Area | What it does | Stack |
|---|---|---|
| `mql5/` | Expert Advisors for MetaTrader 5 (FX, gold, indices) with built-in CSV research logging | MQL5 |
| `research/` | Python labs that rebuild tick data into bid/ask minute bars, replicate each EA trade by trade, and run the statistical studies | Python, pandas, numpy, LightGBM |
| `live/s4live/` | Live trading package for a 41-market trend and carry futures portfolio on Interactive Brokers | Python, IB API |
| `src/exvane/` | Shared Python library: DSR ensemble signal (reference implementation of the EA) and research statistics (Sharpe, probabilistic and deflated Sharpe) | Python, numpy |
| `tests/` | Unit and behavioural tests: breakout rules, no look-ahead, random-walk null, trending-series response, deflated Sharpe checked against simulation | pytest |
| `docs/` | Methodology, pre-registrations and the verdict of every study | Markdown |

## Strategy lines

| Line | Idea | Status |
|---|---|---|
| **S1** | One-sided range break on a higher timeframe, limit entry on the pullback, 2R target plus trailing leg | Retired. No edge after real spreads and commission on any of 2,010 configuration x instrument cells |
| **S3 / DSR** | Donchian stop-and-reverse ensemble (20/40/80/160) with volatility-targeted sizing; zero fitted parameters | Benchmark and signal core for S4 |
| **S4** | DSR trend plus carry across 41 futures markets, inverse-vol sizing, 15% portfolio vol target | Passed its pre-registered tests (net Sharpe 0.85 full sample). Next: 12-month paper trading on Interactive Brokers |
| **S5** | Crypto: cross-sectional momentum on perpetuals, intraday and order-flow studies | Daily signal viable; intraday ideas killed by costs; one rare-event idea under test |
| **Beyond** | Opening-range breaks, London-open breaks, close momentum and other public ideas | Tested; none survives costs over long history |

## How a strategy moves through Exvane

1. **Specify.** Rules are written down, including the parameters that define the hypothesis.
2. **Pre-register.** Variants, data splits and kill criteria are fixed in `docs/` before any result is computed. Holdout data stays sealed.
3. **Replicate.** A Python engine reproduces the EA trade by trade, checked against tick replay and hand-annotated example trades.
4. **Test against costs and nulls.** Real spreads and commissions from day one; every signal is compared with a random-entry null using the same exits.
5. **Correct for multiple testing.** Every variant is logged in an experiment ledger, and results are judged with the deflated Sharpe ratio.
6. **Verify independently.** A second implementation, written only from the spec, must reproduce the headline numbers.
7. **Paper trade, then live.** Live code is tested offline against a fake broker gateway, then run on paper with written stop rules.

Details: [`docs/METHODOLOGY.md`](docs/METHODOLOGY.md).

## Selected numbers

- **S1:** 67 configurations x 30 instruments (28 FX pairs, gold, silver), Dukascopy ticks 2007 to 2022 plus 2023 to 2026 broker holdout. Tick replay agrees with the minute engine on 98.6 to 100% of trades.
- **S4:** 41 futures markets; shift-null p < 0.005; deflated Sharpe 0.69 after 19 trials; costs about 25% of gross. 36 offline tests for the live package; an independent code review found 5 critical and 7 major issues, all fixed.
- **S5 intraday:** 9 synthetic controls pass; an independent re-implementation reproduced every headline result to the decimal.

## Run the tests

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest
```

CI runs the same tests on every push.

## Roadmap

See [`ROADMAP.md`](ROADMAP.md).

## Data

Price data is not stored or redistributed in this repository. Data sources, credits for published methods, and third-party notices are listed in [`ACKNOWLEDGEMENTS.md`](ACKNOWLEDGEMENTS.md).

## Development

Built with [Claude Code](https://claude.com/claude-code) as an AI pair programmer for EA development, research pipelines, test suites and independent verification passes. Contribution workflow: [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Disclaimer

This is research software for my own trading. Nothing here is investment advice, and backtest results do not guarantee future returns.
