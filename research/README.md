# Research labs

| Folder | Contents |
|---|---|
| `s1/` | S1 Python replica, minute and tick engines, configuration grid, result CSVs |
| `s4/` | Trend and carry research on daily futures, cost model, capital study |
| `s5/` | Crypto studies: cross-sectional momentum, intraday tests, order-flow decay |
| `beyond/` | Tests of public strategy ideas (opening-range and London-open breaks, close momentum) |

## Data

No price data is committed. Sources:

- **FX and metals ticks:** Dukascopy, via the FX-Data GitHub mirrors, rebuilt into minute bid/ask bars in New-York-close server time.
- **Broker history:** exported from MetaTrader 5.
- **Daily futures:** the public `pysystemtrade` data repository.
- **Crypto:** Binance public data (klines, aggTrades).

Each lab expects its data under a local `data/` folder, which is git-ignored.

## Run

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest
```
