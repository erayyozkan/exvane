# Acknowledgements, data sources and third-party notices

All code in this repository was written for Exvane and is released under the MIT License (see `LICENSE`). No third-party code is included.

No third-party price data is included or redistributed. The studies were run on local copies obtained from the sources below, each used under its own terms. To reproduce a study, obtain the data from the original source.

## Data sources

| Data | Source | Used in |
|---|---|---|
| Daily futures prices, roll and instrument configuration (to March 2024) | Public data in the [`pysystemtrade`](https://github.com/robcarver17/pysystemtrade) repository (GPL-3.0) | S4, Beyond |
| FX and metals tick data | Dukascopy historical data, via public GitHub mirrors | S1, Beyond |
| Broker price history | Exported from MetaTrader 5 broker accounts for personal research | S1 |
| Crypto prices | Binance public market data | S5 |

## Methods and prior work

Several rules follow published methods. They are credited here; the implementations are original.

- Forecast scaling (average absolute forecast 10, cap 20), the EWMAC trend rule, the carry rule and volatility-targeted position sizing follow Robert Carver, *Systematic Trading* (2015) and *Advanced Futures Trading Strategies* (2023).
- The Donchian channel breakout is a long-established public trading rule (Richard Donchian).
- The deflated Sharpe ratio follows Bailey and López de Prado, "The Deflated Sharpe Ratio" (2014).
- The information-ratio framing (IR ≈ IC x √breadth) follows Grinold and Kahn, *Active Portfolio Management*.
- Intraday crypto reference: "The Quarter-Hour Effect: Periodic Algorithmic Trading and Return Predictability in Cryptocurrency Futures", arXiv 2607.09426.

## Tools

- MetaTrader 5 and MQL5 are products of MetaQuotes Ltd. Interactive Brokers, Binance, Dukascopy and Databento are named only as data or broker sources. Exvane is not affiliated with or endorsed by any of them.
- Development used Claude Code (Anthropic) as an AI coding assistant.

## Disclaimer

Research software for personal trading. Not investment advice. Past and simulated results do not guarantee future returns.
