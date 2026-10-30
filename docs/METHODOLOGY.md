# Research methodology

The goal is systematic edge discovery and deployment, with statistical validity, few parameters and real out-of-sample robustness.

## Principles

**Breadth beats refinement.** By Grinold's law (IR ≈ IC x √breadth), trading a weak signal across many instruments and horizons adds more than polishing one instrument. Single-instrument M15 studies are underpowered for realistic edge sizes (IC around 0.05).

**Parameters cost twice.** Once in lost diversification, once in Sharpe deflation. The answer is aggregation across instruments and horizons, not selection among parameter sets.

**Structural parameters are not optimisation targets.** Parameters that define the hypothesis (for example swing geometry) are set by logic and checked for a plateau. They are not swept in walk-forward optimisation.

**Costs from day one.** Spread, commission and slippage are modelled before any edge is claimed. At short horizons costs often exceed the gross edge.

**Manual validation before statistics.** An EA must reproduce hand-annotated example trades before its backtests are trusted.

**Environment bugs are the dangerous ones.** Bugs that hide in the strategy tester but act live (position cache reads, timer throttles, netting vs hedging accounts) are hunted explicitly.

**Pre-registration.** Variants, data splits and kill criteria are written before running. Holdout data stays sealed until the final check.

## Process

1. **Spec.** Write the rules, including what would falsify the idea.
2. **Pre-register** in `docs/`: variants, periods, pass and kill criteria.
3. **Replicate** the EA in Python, trade by trade; validate the minute-bar engine against tick replay.
4. **Null tests.** Compare against random entries with the same exits, shift nulls and synthetic controls (noise must give nothing; planted effects must be found).
5. **Ledger.** Every variant is a trial. Results are judged with the deflated Sharpe ratio for the number of trials run.
6. **Independent re-implementation** from the written spec reproduces the headline numbers.
7. **Adversarial code review.** Successive review passes, each hunting one bug class (input handling, CSV alignment, stale identifiers, division guards, account-mode behaviour).
8. **Deploy** with stop rules written in advance.

## Optimisation tiers (when optimisation is justified)

- **Tier 1:** joint optimisation of the primary parameters only.
- **Tier 2:** one-at-a-time passes on exit parameters.
- **Tier 2b:** A/B tests on filters.
- **Tier 3:** confirm flatness on microstructure parameters.

Walk-forward optimisation uses fixed in-sample/out-of-sample windows, and walk-forward efficiency and correlation are reported next to the in-sample/out-of-sample ratio.

## Tooling

- MetaTrader 5 / MQL5 for execution and strategy-tester runs (real ticks).
- Python harnesses per EA: look-ahead checks, random-walk nulls, sign response to autocorrelated series.
- Hybrid logger EAs: live and tester runs also write setup, order and result CSVs for research.
- Data: Dukascopy ticks, broker history exported from MT5, daily futures history, Binance public data, Databento CME data (planned).
