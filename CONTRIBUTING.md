# Workflow

Exvane is a single-developer project. The workflow below keeps it reviewable and reproducible anyway.

## Branches and pull requests

1. Create a branch from `main`: `feature/<short-name>` or `study/<short-name>`.
2. Keep each pull request to one change: one EA fix, one study, one module.
3. A study PR includes its pre-registration in `docs/` *before* the results commit.
4. Tests must pass (`pytest`) before merging.
5. Every PR gets an independent review pass (a separate Claude Code session that has not seen the implementation checks the logic against the spec), then a final check against the checklist below.

## Review checklist

- [ ] No look-ahead: signals use only data available at decision time
- [ ] Costs modelled (spread, commission, slippage where relevant)
- [ ] No price data, credentials or account numbers committed
- [ ] New parameters justified; structural parameters not swept
- [ ] Results reproducible from the committed code
- [ ] Verdict written in `docs/`, including negative results

## Commit messages

Short imperative subject (`Fix trail ladder step unit in S1 EA`), with a body explaining why when it is not obvious.
