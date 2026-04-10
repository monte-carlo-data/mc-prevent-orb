# MC Prevent — CircleCI Orb

Assess data pipeline risk before merge. This orb calls the Monte Carlo MC Prevent API to evaluate pull request changes against your data observability signals (alerts, lineage, monitor coverage) and returns a pass/warn/fail verdict.

This is a [URL orb](https://circleci.com/docs/orbs/author/create-test-and-use-url-orbs/) — referenced by URL in your CircleCI config, not published to the CircleCI Orb Registry.

## Quick Start

### 1. Allow-list the orb (one-time, org admin)

Your CircleCI organization admin must allow the orb URL prefix before any project can use it.

1. Go to **CircleCI → Organization Settings → Orbs**
2. Under **Allowed URL Orb prefixes**, click **Add**
3. Fill in:
   - **Name:** `Monte Carlo MC Prevent`
   - **URL Prefix:** `https://raw.githubusercontent.com/monte-carlo-data/mc-prevent-orb/`
   - **Auth:** `None`
4. Click **Add URL Prefix**

The allow-list can also be managed via the [CircleCI API](https://circleci.com/docs/orbs/use/managing-url-orbs-allow-lists/).

### 2. Create Monte Carlo API keys

Go to **Monte Carlo → Settings → API Keys → Create Key**. Save the key ID and token.

### 3. Create a CircleCI context

Go to **CircleCI → Organization Settings → Contexts → Create Context** (e.g., `monte-carlo`). Add two environment variables:

| Variable | Value |
|---|---|
| `MCD_DEFAULT_API_ID` | Your Monte Carlo API key ID |
| `MCD_DEFAULT_API_TOKEN` | Your Monte Carlo API key token |

### 4. Add to your CircleCI config

```yaml
version: 2.1

orbs:
  mc-prevent: https://raw.githubusercontent.com/monte-carlo-data/mc-prevent-orb/main/orb.yml

workflows:
  main:
    jobs:
      - mc-prevent/assess:
          name: mc-prevent
          context:
            - monte-carlo
          filters:
            branches:
              ignore:
                - main
                - master
```

That's it. MC Prevent runs on every pull request and reports a verdict.

## Versioning

URL orbs do not use semantic versioning. The URL can point to any git ref — a branch, tag, or commit SHA:

```yaml
# Track latest on main (recommended — picks up improvements automatically)
mc-prevent: https://raw.githubusercontent.com/monte-carlo-data/mc-prevent-orb/main/orb.yml

# Pin to a release tag
mc-prevent: https://raw.githubusercontent.com/monte-carlo-data/mc-prevent-orb/v1.0/orb.yml

# Pin to a specific commit (immutable)
mc-prevent: https://raw.githubusercontent.com/monte-carlo-data/mc-prevent-orb/<commit-sha>/orb.yml
```

> **Note:** CircleCI caches URL orb contents for 5 minutes. After a release, pipelines pick up the update within that window.

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
    name: mc-prevent
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

### Behavior by setup stage

MC Prevent is designed for progressive adoption. Once the allow-list is configured, it never blocks your CI due to incomplete setup — you can configure the remaining pieces at your own pace.

| Setup stage | CI result | What you'll see |
|---|---|---|
| Orb referenced, URL not allow-listed | Pipeline will not run | The org admin must add the URL prefix to the allow-list first — see [Step 1](#1-allow-list-the-orb-one-time-org-admin). |
| Allow-list configured, credentials not yet set | Pass (green) | Job skips instantly — no API call is made |
| Credentials configured, PR agent not yet enabled | Pass (green) | Job polls for up to `max-wait` seconds, then passes with no assessment |
| Credentials configured, PR agent enabled | Pass / Warn / Fail | Full risk verdict based on the PR agent's analysis |

**Tip:** To avoid the polling wait in stage three, enable the PR agent in **Monte Carlo → Settings → AI Agents** before (or shortly after) adding your API credentials.

## Override

Add the `mc-override` label to your pull request to bypass MC Prevent.

- The verdict returns **pass** regardless of risk
- The "MC Prevent CI Gate Result" check run on the PR immediately flips to green — no commit or CI re-run needed
- All overrides are logged for audit

## Troubleshooting

**MC Prevent times out with no assessment:**
MC Prevent waits up to `max-wait` seconds (default 300) for the PR agent's analysis to become available. The PR agent runs independently and may take longer depending on the number of affected assets and downstream dependencies. If no assessment is ready within the wait window, the job passes without blocking — this ensures MC Prevent never holds up your CI pipeline. On subsequent commits, MC Prevent reuses the cached verdict from the initial assessment so there is no repeated wait. If you consistently see timeouts, verify that the PR agent is enabled in **Monte Carlo → Settings → AI Agents** — see the [setup stages](#behavior-by-setup-stage) table above.

**Authentication errors (401):**
Verify that `MCD_DEFAULT_API_ID` and `MCD_DEFAULT_API_TOKEN` are set correctly in your CircleCI context. Ensure the context is referenced in your workflow job.

**CI job shows red but the change is low risk:**
Check the step output — if the verdict is `warn` (not `fail`), this is expected when `fail-on-error: true`. The check run on the PR will show grey (neutral), not red. Set `fail-on-error: false` if you don't want warnings to fail the CI job.

**"Orb not allowed" or URL orb error:**
Your CircleCI organization admin needs to add the URL prefix to the allow-list before any project can reference the orb. See [Step 1](#1-allow-list-the-orb-one-time-org-admin) above.

## Development

### Project structure

```
src/
├── @orb.yml           # Orb metadata
├── commands/
│   └── assess.yml     # Main assessment command
├── executors/
│   └── default.yml    # Docker executor
├── examples/
│   ├── basic-usage.yml
│   └── custom-options.yml
└── jobs/
    └── assess.yml     # Job wrapper
orb.yml                # Packed single-file orb (generated)
```

The `src/` directory contains the orb source. The root `orb.yml` is the packed single-file version that customers reference — it is generated from `src/` and must be kept in sync.

### Making changes

```bash
# Edit files in src/, then regenerate the packed orb:
make pack

# Validate the result:
make validate

# Or do both:
make check
```

Always commit both the `src/` changes and the regenerated `orb.yml` together to prevent drift.

## Resources

- [Monte Carlo Documentation](https://docs.getmontecarlo.com)
- [MC Prevent Overview](https://docs.getmontecarlo.com/docs/github)
- [CircleCI URL Orbs](https://circleci.com/docs/orbs/author/create-test-and-use-url-orbs/)
- [Managing URL Orb Allow-Lists](https://circleci.com/docs/orbs/use/managing-url-orbs-allow-lists/)
- [Source Code](https://github.com/monte-carlo-data/mc-prevent-orb)
