"""Research statistics: Sharpe ratio, probabilistic and deflated Sharpe ratio.

Deflated Sharpe ratio follows Bailey and Lopez de Prado, "The Deflated Sharpe
Ratio: Correcting for Selection Bias, Backtest Overfitting and Non-Normality"
(2014). All Sharpe ratios here are per period (not annualised) unless stated.
"""

from __future__ import annotations

import math
from statistics import NormalDist
from typing import Sequence

import numpy as np

EULER_GAMMA = 0.5772156649015329
_N = NormalDist()


def sharpe(returns: Sequence[float]) -> float:
    """Per-period Sharpe ratio (mean / sample standard deviation)."""
    r = np.asarray(returns, dtype=float)
    if len(r) < 2:
        raise ValueError("need at least two returns")
    sd = r.std(ddof=1)
    if sd == 0:
        raise ValueError("returns have zero variance")
    return float(r.mean() / sd)


def annualised_sharpe(returns: Sequence[float], periods_per_year: int = 256) -> float:
    return sharpe(returns) * math.sqrt(periods_per_year)


def _moments(r: np.ndarray) -> tuple[float, float]:
    """Sample skewness and (non-excess) kurtosis."""
    d = r - r.mean()
    m2 = (d ** 2).mean()
    skew = (d ** 3).mean() / m2 ** 1.5
    kurt = (d ** 4).mean() / m2 ** 2
    return float(skew), float(kurt)


def probabilistic_sharpe(returns: Sequence[float], benchmark_sr: float = 0.0) -> float:
    """Probability that the true per-period Sharpe exceeds benchmark_sr,
    adjusting for sample length, skewness and kurtosis."""
    r = np.asarray(returns, dtype=float)
    t = len(r)
    sr = sharpe(r)
    skew, kurt = _moments(r)
    denom = 1.0 - skew * sr + (kurt - 1.0) / 4.0 * sr ** 2
    if denom <= 0:
        raise ValueError("non-positive variance term; check the return series")
    z = (sr - benchmark_sr) * math.sqrt(t - 1) / math.sqrt(denom)
    return _N.cdf(z)


def expected_max_sharpe(n_trials: int, sr_variance: float) -> float:
    """Expected maximum per-period Sharpe among n_trials skill-less trials,
    given the variance of the Sharpe ratios across those trials."""
    if n_trials < 1:
        raise ValueError("n_trials must be at least 1")
    if n_trials == 1:
        return 0.0
    sd = math.sqrt(sr_variance)
    return sd * (
        (1.0 - EULER_GAMMA) * _N.inv_cdf(1.0 - 1.0 / n_trials)
        + EULER_GAMMA * _N.inv_cdf(1.0 - 1.0 / (n_trials * math.e))
    )


def deflated_sharpe(returns: Sequence[float], n_trials: int, sr_variance: float) -> float:
    """Deflated Sharpe ratio: the probabilistic Sharpe of the selected strategy
    against the Sharpe expected from the best of n_trials by luck alone."""
    return probabilistic_sharpe(returns, expected_max_sharpe(n_trials, sr_variance))
