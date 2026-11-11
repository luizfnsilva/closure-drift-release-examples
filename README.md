# closure_drift with release tools: examples

A demonstration, separate from the tool. Each job in `.github/workflows/examples.yml` builds a small
repository, makes one release operation and asks
[closure_drift](https://github.com/luizfnsilva/closure_drift) (pinned by hash) whether the tag names
the version its commit declares. Every run writes, per scenario: the initial state, the operation, the
tag's commit, the expected and the observed exit code, and keeps `report.json` as an artifact.

All scenarios start the same way: `v1.0.0` on a commit declaring `1.0.0`.

| Scenario | Operation | Expected |
|---|---|---|
| `normal` | bump to 1.1.0 and tag `v1.1.0` on the same commit | 0: pass |
| `tag-before-bump` | `v1.1.0` tagged by hand before the bump commit | 1: the tagged commit still declares 1.0.0 |
| `tag-moved` | `v1.1.0` recreated on a later commit with other code | 0: see below |
| `other-file` | pyproject.toml bumped, `src/demo/__init__.py` left at 1.0.0 | 1: the file checked disagrees |
| `insufficient` | no file declares a version | 2: nothing determined |

**A moved tag alone is not drift.** In `tag-moved` the new commit declares 1.1.0, so the check passes:
what it examines is whether the tag names the version its commit declares, and that holds. That the
same tag once named other code is visible only while the old tag is somewhere in the history examined
(another tag, a `--published` list). Here it is gone, so nothing can be said about it.

**Inconclusive is not a pass.** Exit 2 means there was not enough to decide. The workflow fails on it,
as the closure_drift Action does by default (`allow-undetermined: false`).

## What it adds to a release tool

| Situation | Release tool | closure_drift |
|---|---|---|
| Normal flow, correctly configured | already keeps them consistent | independent confirmation |
| Tag made by hand before the bump | can escape the automated flow | finds the mismatch |
| Tag changed later | depends on the history available | can find it only if the old state is still in the history examined |
| Version declared in another file | depends on configuration | a second check, on the file you name |
| Not enough data | does not necessarily decide | says so: exit 2 |

Where the version is written from the tag at publish time (semantic-release keeping
`0.0.0-development`, or a publish job running `uv version "${GITHUB_REF_NAME#v}"`), the file at the
tag is stale on purpose and the published package is right. There is nothing to compare, and `--tag`
reports a mismatch. Do not use it in that setup.

## In a real workflow

```yaml
- uses: luizfnsilva/closure_drift@v1.7.0   # on a tag push, checks the pushed tag
```

## Observed

Run [43048572732](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/43048572732)
on commit `fd1500c`, closure_drift 1.7.0: all five scenarios left at the expected exit code. Each
job's summary and artifact hold the commit and the report. The runs before, on 1.6.0
([42904574239](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/42904574239))
and 1.5.1 ([42896425424](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/42896425424)),
gave the same codes.

## Gate: a publish job behind the check

[`gate.yml`](.github/workflows/gate.yml) puts a publish job behind the check with `needs:`, for three
scenarios. It runs the 1.8.0 candidate as a user gets it: the Action from a pinned ref.

| scenario | check | verdict | publish |
|---|---|---|---|
| A, correct release | passes | `tag_matches` | runs |
| B, tag cut before the bump | fails | `tag_mismatch` | does not run |
| C, version written at publish time | fails | `incomplete` | does not run |

B and C make the run red on purpose. The `verify` job is the test: it is green only when all three
behave as above. Run [43099981292](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/43099981292).
In A, the check only confirms what a release tool that bumps and tags in one commit already ensures.
