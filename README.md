# MC Prevent — CircleCI Orb

Assess data pipeline risk before merge. This orb calls the Monte Carlo MC Prevent API to evaluate pull request changes against your data observability signals (alerts, lineage, monitor coverage) and returns a pass/warn/fail verdict.

## Quick Start

### 1. Create Monte Carlo API keys

Go to **Monte Carlo → Settings → API Keys → Create Key**. Save the key ID and token.

### 2. Create a CircleCI context

Go to **CircleCI → Organization Settings → Contexts → Create Context** (e.g., `monte-carlo`). Add two environment variables:

| Variable | Value |
|---|---|
| `MCD_DEFAULT_API_ID` | Your Monte Carlo API key ID |
| `MCD_DEFAULT_API_TOKEN` | Your Monte Carlo API key token |

### 3. Add to your CircleCI config

```yaml
version: 2.1

orbs:
  mc-prevent: monte-carlo/mc-prevent-orb@1

workflows:
  main:
    jobs:
      - mc-prevent/assess:
          context:
            - monte-carlo
          filters:
            branches:
              ignore:
                - main
                - master
```

That's it. MC Prevent runs on every pull request and reports a verdict.

> **Note:** Use `@1` to track the latest stable release. Specific versions (e.g., `@1.0.0`) are also supported.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `api-url` | string | `https://api.getmontecarlo.com/ci/assess` | Monte Carlo MC Prevent API URL |
| `poll-interval` | integer | `30` | Seconds between poll attempts when waiting for assessment |
| `max-wait` | integer | `300` | Maximum seconds to wait for assessment before giving up |
| `fail-on-error` | boolean | `true` | Whether warn/fail verdicts cause the CI job to exit non-zero |

### Example with custom parameters

```yaml
- mc-prevent/assess:
    poll-interval: 15
    max-wait: 120
    fail-on-error: false
    context:
      - monte-carlo
```

## How it works

1. MC Prevent detects the pull request from CircleCI environment variables
2. Calls the Monte Carlo MC Prevent API with the repo, PR number, and commit SHA
3. If no assessment is available yet (the PR agent may still be analyzing), waits up to `max-wait` seconds
4. If a cached verdict from a previous commit exists, reuses it immediately
5. Displays the verdict and a human-readable summary explaining the risk
6. Raw API response available in a separate collapsed step ("Raw API response")

### Verdicts

MC Prevent returns one of three verdicts based on the risk assessment:

| Verdict | What it means | CI job behavior (`fail-on-error: true`) | Check run on PR |
|---|---|---|---|
| **pass** | No significant risk detected | Job passes (green) | Green |
| **warn** | Risk detected — review recommended | Job fails (red), step auto-expands | Grey (neutral) |
| **fail** | High risk — merge not recommended | Job fails (red), step auto-expands | Red |

**Note on CI job vs check run:** The CI job can only show green or red. The "MC Prevent CI Gate Result" check run posted on the PR shows the actual severity — green for pass, grey for warn, red for fail. If you configure branch protection, require the check run (not the CI job) for accurate gating.

### How the verdict is calculated

MC Prevent receives a risk assessment from the MC PR Agent for each data asset affected by the PR. It evaluates each asset against a decision matrix and takes the worst verdict across all assets.

**Decision matrix** — rules are evaluated top-to-bottom, first match wins:

| # | Condition | Verdict |
|---|-----------|---------|
| 1 | Breaking change AND downstream key assets depend on it | **fail** |
| 2 | Active alerts highly correlated with the change | **fail** |
| 3 | Breaking change AND no key assets downstream | **warn** |
| 4 | Active alerts exist but low/no correlation with the change | **warn** |
| 5 | No monitor coverage AND key assets downstream | **warn** |
| 6 | Additive change, no active alerts | **pass** |
| 7 | No qualifying data assets identified | **pass** |

**Signals used per asset** — provided by the PR agent:

| Signal | Description |
|--------|-------------|
| `change_type` | How the asset is affected: `breaking` or `additive` |
| `alert_correlation` | Whether active alerts are related to the change: `high`, `low`, or `none` |
| `active_alerts` | Number of unresolved alerts on the asset |
| `downstream_key_assets` | Key assets (dashboards, critical tables) that depend on this asset |
| `monitor_coverage_gaps` | Columns or aspects of the asset that have no monitor coverage |

**Multi-asset PRs:** When a PR affects multiple data assets, each is evaluated independently. The final verdict is the **worst** across all assets — if one asset is `fail` and another is `pass`, the PR verdict is `fail`.

### What `fail-on-error` controls

| Setting | Behavior |
|---|---|
| `fail-on-error: true` (default) | Warn and fail both cause the CI job to exit non-zero (red). This draws attention to risks — the failed step auto-expands in CircleCI so the summary is immediately visible. |
| `fail-on-error: false` | The CI job always passes (green). The verdict is only visible in the job output and the check run on the PR. Use this for a silent, non-blocking setup. |

### Missing credentials

If `MCD_DEFAULT_API_ID` or `MCD_DEFAULT_API_TOKEN` are not set, MC Prevent skips silently (job passes). This means adding the orb to your config before configuring credentials won't break your CI.

## Override

Add the `mc-override` label to your pull request to bypass MC Prevent.

- The verdict returns **pass** regardless of risk
- The "MC Prevent CI Gate Result" check run on the PR immediately flips to green — no commit or CI re-run needed
- All overrides are logged for audit

## Troubleshooting

**MC Prevent times out with no assessment:**
The PR agent posts its assessment when a PR is opened or marked ready for review. If you push additional commits, MC Prevent reuses the cached verdict from the initial assessment. If no assessment exists after `max-wait` seconds, the job exits without blocking.

**Authentication errors (401):**
Verify that `MCD_DEFAULT_API_ID` and `MCD_DEFAULT_API_TOKEN` are set correctly in your CircleCI context. Ensure the context is referenced in your workflow job.

**CI job shows red but the change is low risk:**
Check the step output — if the verdict is `warn` (not `fail`), this is expected when `fail-on-error: true`. The check run on the PR will show grey (neutral), not red. Set `fail-on-error: false` if you don't want warnings to fail the CI job.

## Resources

- [Monte Carlo Documentation](https://docs.getmontecarlo.com)
- [MC Prevent Overview](https://docs.getmontecarlo.com/docs/github)
- [Source Code](https://github.com/monte-carlo-data/mc-prevent-orb)
