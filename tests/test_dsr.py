import numpy as np
import pytest

from exvane.dsr import channel_states, ensemble_signal


def test_flips_long_on_close_above_prior_high():
    close = [10, 11, 10, 11, 12]          # bar 4 closes above max(prior 3) = 11
    s = channel_states(close, n=3)
    assert list(s) == [0, 0, 0, 0, 1]


def test_holds_state_inside_channel_and_reverses_on_break():
    close = [10, 11, 10, 11, 12, 11.5, 11.8, 9]
    s = channel_states(close, n=3)
    # long from bar 4, held inside the channel, reversed when bar 7 breaks the low
    assert list(s) == [0, 0, 0, 0, 1, 1, 1, -1]


def test_channel_excludes_current_bar():
    # a close equal to the prior high is not a break
    close = [10, 11, 10, 11]
    assert channel_states(close, n=3)[-1] == 0


def test_no_look_ahead():
    rng = np.random.default_rng(1)
    close = 100 + rng.standard_normal(600).cumsum()
    base = channel_states(close, n=20)
    changed = close.copy()
    changed[400:] += 50                    # change only the future
    assert np.array_equal(base[:400], channel_states(changed, n=20)[:400])


def test_extreme_mode_outside_bar_follows_bar_direction():
    high = [11, 11, 11, 13]
    low = [9, 9, 9, 8]
    open_ = [10, 10, 10, 9]
    close = [10, 10, 10, 12]               # breaks both sides, closes up
    s = channel_states(close, n=3, high=high, low=low, open_=open_, mode="extreme")
    assert s[-1] == 1


def test_ensemble_is_mean_of_states_and_bounded():
    rng = np.random.default_rng(2)
    close = 100 + rng.standard_normal(1000).cumsum()
    sig = ensemble_signal(close, lengths=(20, 40))
    expected = (channel_states(close, 20) + channel_states(close, 40)) / 2
    assert np.allclose(sig, expected)
    assert sig.min() >= -1 and sig.max() <= 1


def test_trending_series_is_mostly_long():
    t = np.arange(2000)
    close = 100 + 0.05 * t + np.sin(t / 7)
    sig = ensemble_signal(close)
    assert (sig[200:] > 0).mean() > 0.95


def test_random_walk_has_no_edge():
    """On a random walk the signal must not predict the next return."""
    rng = np.random.default_rng(3)
    rets = rng.standard_normal(200_000)
    close = 100 + rets.cumsum()
    sig = ensemble_signal(close)
    pnl = sig[:-1] * rets[1:]
    t_stat = pnl.mean() / (pnl.std(ddof=1) / np.sqrt(len(pnl)))
    assert abs(t_stat) < 3


def test_bad_inputs_raise():
    with pytest.raises(ValueError):
        channel_states([1, 2, 3], n=1)
    with pytest.raises(ValueError):
        channel_states([1, 2, 3], n=2, mode="extreme")
