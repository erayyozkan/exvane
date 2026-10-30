"""Donchian stop-and-reverse (DSR) ensemble signal.

Python reference implementation of the logic in mql5/dsr/DSR_Ensemble_v6.mq5,
used to cross-check the EA and as the trend signal in the S4 research.

Rules for one channel length n, evaluated on bar t:
    upper = max(high[t-n .. t-1]), lower = min(low[t-n .. t-1])
    the channel EXCLUDES bar t itself
    close mode:   +1 if close[t] > upper, -1 if close[t] < lower
    extreme mode: +1 if high[t] > upper,  -1 if low[t] < lower;
                  if both, follow the bar's own direction (close >= open -> +1)
    otherwise the previous state is kept (stop and reverse; starts flat at 0)

The ensemble signal is the mean of the states over all channel lengths.
"""

from __future__ import annotations

from typing import Sequence

import numpy as np

DEFAULT_LENGTHS = (20, 40, 80, 160)


def channel_states(
    close: Sequence[float],
    n: int,
    high: Sequence[float] | None = None,
    low: Sequence[float] | None = None,
    open_: Sequence[float] | None = None,
    mode: str = "close",
) -> np.ndarray:
    """State (-1, 0, +1) after each bar for one channel length.

    If high/low are omitted, closes are used for the channel (as in the
    daily futures research, where only closes are available).
    """
    if n < 2:
        raise ValueError("channel length must be at least 2")
    if mode not in ("close", "extreme"):
        raise ValueError("mode must be 'close' or 'extreme'")

    c = np.asarray(close, dtype=float)
    h = c if high is None else np.asarray(high, dtype=float)
    lo = c if low is None else np.asarray(low, dtype=float)
    o = c if open_ is None else np.asarray(open_, dtype=float)
    if not (len(c) == len(h) == len(lo) == len(o)):
        raise ValueError("all price series must have the same length")
    if mode == "extreme" and (high is None or low is None):
        raise ValueError("extreme mode needs high and low series")

    states = np.zeros(len(c), dtype=int)
    state = 0
    for t in range(len(c)):
        if t >= n:
            upper = h[t - n:t].max()
            lower = lo[t - n:t].min()
            if mode == "close":
                up, dn = c[t] > upper, c[t] < lower
            else:
                up, dn = h[t] > upper, lo[t] < lower
            if up and dn:
                state = 1 if c[t] >= o[t] else -1
            elif up:
                state = 1
            elif dn:
                state = -1
        states[t] = state
    return states


def ensemble_signal(
    close: Sequence[float],
    lengths: Sequence[int] = DEFAULT_LENGTHS,
    **kwargs,
) -> np.ndarray:
    """Mean state across channel lengths, in [-1, 1]."""
    if len(lengths) == 0:
        raise ValueError("need at least one channel length")
    stacked = np.vstack([channel_states(close, n, **kwargs) for n in lengths])
    return stacked.mean(axis=0)
