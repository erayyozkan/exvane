# Live trading

## s4live

Python package that runs the S4 trend and carry portfolio on Interactive Brokers.

| Command | What it does |
|---|---|
| `update` | Fetch closes to yesterday from IB, maintain the roll calendar |
| `check` | Qualify contracts, check roll-to-expiry and margins |
| `orders` | Compute target positions and orders (dry run unless `--submit`; paper account only unless `--allow-live`) |
| `fills` | Reconcile fills against orders |
| `paper` | Track the model books for comparison with paper results |

Safety: stale-data and partial-bar guards, one submission per day, live trading blocked by default.

Tests run offline against a fake gateway: `pytest live/`.

Credentials and account IDs come from a local config file that is git-ignored. Never commit them.
