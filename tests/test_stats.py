import math

import numpy as np
import pytest

from exvane.stats import (
    annualised_sharpe,
    deflated_sharpe,
    expected_max_sharpe,
    probabilistic_sharpe,
    sharpe,
)


def test_sharpe_known_value():
    r = [0.01, -0.01, 0.02, 0.0]
    assert sharpe(r) == pytest.approx(np.mean(r) / np.std(r, ddof=1))


def test_annualised_sharpe_scales_with_sqrt_periods():
    r = np.random.default_rng(0).normal(0.001, 0.01, 500)
    assert annualised_sharpe(r, 256) == pytest.approx(sharpe(r) * 16)


def test_zero_variance_raises():
    with pytest.raises(ValueError):
        sharpe([0.01, 0.01, 0.01])


def test_psr_is_half_when_sharpe_equals_benchmark():
    r = np.random.default_rng(1).normal(0.0005, 0.01, 1000)
    assert probabilistic_sharpe(r, sharpe(r)) == pytest.approx(0.5)


def test_psr_rises_with_more_data():
    rng = np.random.default_rng(2)
    short = rng.normal(0.0005, 0.01, 250)
    long = np.tile(short, 8)              # same Sharpe, more observations
    assert probabilistic_sharpe(long) > probabilistic_sharpe(short)


def test_one_trial_has_no_deflation():
    r = np.random.default_rng(3).normal(0.0005, 0.01, 1000)
    assert expected_max_sharpe(1, 0.01) == 0.0
    assert deflated_sharpe(r, 1, 0.01) == pytest.approx(probabilistic_sharpe(r))


def test_more_trials_deflate_more():
    r = np.random.default_rng(4).normal(0.0008, 0.01, 2000)
    d = [deflated_sharpe(r, n, 0.0004) for n in (1, 10, 100, 1000)]
    assert all(a > b for a, b in zip(d, d[1:]))


def test_expected_max_sharpe_matches_simulation():
    rng = np.random.default_rng(5)
    n_trials, sd = 50, 0.05
    sims = rng.normal(0.0, sd, (20_000, n_trials)).max(axis=1)
    assert expected_max_sharpe(n_trials, sd ** 2) == pytest.approx(sims.mean(), rel=0.03)
