# Monte Carlo CI Gate — CircleCI Orb

Assess data pipeline risk before merge. This orb calls the Monte Carlo CI Gate API to evaluate pull request changes against your data observability signals (alerts, lineage, monitor coverage) and returns a pass/warn/fail verdict.

## Usage

```yaml
version: 2.1

orbs:
  mc-gate: monte-carlo/mcd-ci-gate@1.0.0

workflows:
  main:
    jobs:
      - mc-gate/assess:
          context:
            - monte-carlo  # Must contain MCD_DEFAULT_API_ID and MCD_DEFAULT_API_TOKEN
          filters:
            branches:
              ignore:
                - main
                - master
```

## Prerequisites

1. A Monte Carlo account with API keys
2. A CircleCI context containing:
   - `MCD_DEFAULT_API_ID` — your Monte Carlo API key ID
   - `MCD_DEFAULT_API_TOKEN` — your Monte Carlo API key token

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `api-url` | string | `https://api.getmontecarlo.com/ci/assess` | Monte Carlo CI Gate API URL |
| `poll-interval` | integer | `30` | Seconds between poll attempts |
| `max-wait` | integer | `300` | Maximum seconds to wait for assessment |
| `fail-on-error` | boolean | `true` | Fail the job if the gate returns "fail" |

## How it works

1. The orb detects the pull request from CircleCI environment variables
2. Calls the Monte Carlo CI Gate API (`/ci/assess`) with the repo, PR number, and commit SHA
3. If no assessment is available yet, polls every `poll-interval` seconds up to `max-wait`
4. Reports the verdict: pass, warn, or fail
5. Optionally fails the job if the verdict is "fail" (controlled by `fail-on-error`)

## Override

Add the `mc-override` label to your pull request to bypass the gate.

## Resources

- [Monte Carlo Documentation](https://docs.getmontecarlo.com)
- [Source Code](https://github.com/monte-carlo-data/mcd-ci-gate-orb)
