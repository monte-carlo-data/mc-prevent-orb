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

That's it. MC Prevent will run on every pull request and report a pass/warn/fail verdict.

> **Note:** CircleCI orbs are versioned and published to the [CircleCI Orb Registry](https://circleci.com/developer/orbs). Use `@1` to track the latest stable release. Specific versions (e.g., `@1.0.0`) are also supported.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `api-url` | string | `https://api.getmontecarlo.com/ci/assess` | Monte Carlo MC Prevent API URL |
| `poll-interval` | integer | `30` | Seconds between poll attempts when waiting for assessment |
| `max-wait` | integer | `300` | Maximum seconds to wait for assessment before giving up |
| `fail-on-error` | boolean | `true` | Fail the job if the verdict is "fail" |

### Example with custom parameters

```yaml
- mc-prevent/assess:
    api-url: "https://api.eu.getmontecarlo.com/ci/assess"
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
5. Reports the verdict: **pass**, **warn**, or **fail**

### Verdicts

| Verdict | Meaning |
|---|---|
| **pass** | No significant risk detected. Safe to merge. |
| **warn** | Risk detected. Review the PR agent's assessment before merging. |
| **fail** | High risk. Merge is blocked (if `fail-on-error` is `true`). |

## Override

Add the `mc-override` label to your pull request to bypass MC Prevent. The verdict returns `pass` with a note that the override is active. All overrides are logged for audit.

## Gate Modes

Configured per account in Monte Carlo (not in the orb):

| Mode | Behavior |
|---|---|
| `warn_only` (default) | High-risk changes show as warnings but never block. |
| `fail_on_high_risk` | High-risk changes return "fail" and block merge. |

## Troubleshooting

**MC Prevent times out with no assessment:**
The PR agent posts its assessment when a PR is opened or marked ready for review. If you push additional commits, MC Prevent reuses the cached verdict from the initial assessment. If no assessment exists after `max-wait` seconds, the job exits without blocking.

**Authentication errors (401):**
Verify that `MCD_DEFAULT_API_ID` and `MCD_DEFAULT_API_TOKEN` are set correctly in your CircleCI context. Ensure the context is referenced in your workflow job.

## Resources

- [Monte Carlo Documentation](https://docs.getmontecarlo.com)
- [MC Prevent Overview](https://docs.getmontecarlo.com/docs/copy-of-github)
- [Source Code](https://github.com/monte-carlo-data/mc-prevent-orb)
