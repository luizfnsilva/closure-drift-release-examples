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

Where the version is written from the tag at publish time, the file at the tag is stale on purpose
and the published package is right. Examples: semantic-release keeping `0.0.0-development`, or a
publish job running `uv version "${GITHUB_REF_NAME#v}"`. Here there is nothing to compare. What `--tag`
answers depends on whether it recognises the mechanism. Since 1.8.0, a version written from the
pushed ref, from `github.event.release.tag_name` or from `git describe --tags` gives `incomplete`
(exit 2), with the workflow file and line, not a mismatch. A version written by `sed`, by a script or
through job outputs is not recognised, and there `--tag` can still answer `tag_mismatch`
([FAILURES.md O14](https://github.com/luizfnsilva/closure_drift/blob/main/docs/FAILURES.md)). In both
cases the check does not fit that setup: it stops the publish without saying anything about the
package.

## In a real workflow

```yaml
- uses: luizfnsilva/closure_drift@v1.8.0   # on a tag push, checks the pushed tag
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
scenarios. It runs closure_drift 1.8.0 as a user gets it: the Action pinned at `@v1.8.0`.

| scenario | check | verdict | publish |
|---|---|---|---|
| A, correct release | passes | `tag_matches` | runs |
| B, tag cut before the bump | fails | `tag_mismatch` | does not run |
| C, version written at publish time | fails | `incomplete` | does not run |

B and C make the run red on purpose. The `verify` job is the test: it is green only when all three
behave as above. Run [43137487122](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/43137487122), on 1.8.0. The earlier run on the frozen candidate, [43099981292](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/43099981292), gave the same results.
In A, the check only confirms what a release tool that bumps and tags in one commit already ensures.

## Two platforms, same gate

closure_drift 1.8.0 on both. On each platform the publish job depends on the check, so it runs only
when the check passes. On GitHub that is `needs: check-x`, in [`gate.yml`](.github/workflows/gate.yml).
On GitLab it is `needs: [closure-drift]`, in the test project's
[`.gitlab-ci.yml`](https://gitlab.com/lfnsilva.invest/closure-drift-test/-/blob/main/.gitlab-ci.yml).
On both, exit 2 fails the check, because `allow-undetermined` is `false` by default.

| platform | how it is called | scenario | check | publish | run |
|---|---|---|---|---|---|
| GitHub Actions | `luizfnsilva/closure_drift@v1.8.0`, `--tag` | A, correct release | `tag_matches`, exit 0 | ran | [130916204984](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/43137487122/job/130916204984) |
| GitHub Actions | same | B, tag cut before the bump | `tag_mismatch`, exit 1 | skipped | [130916204729](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/43137487122/job/130916204729) |
| GitHub Actions | same | C, version written at publish time | `incomplete`, exit 2 | skipped | [130916205033](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/43137487122/job/130916205033) |
| GitLab CI/CD | catalog component `closure-drift@1.8.0`, `would-tag` | correct: 1.2.0, not yet tagged | WOULD BE CLEAN, exit 0 | ran | [3062315091](https://gitlab.com/lfnsilva.invest/closure-drift-test/-/pipelines/3062315091) |
| GitLab CI/CD | same | drift: code changed, still 1.0.0 | WOULD DRIFT, exit 1 | skipped | [3062315272](https://gitlab.com/lfnsilva.invest/closure-drift-test/-/pipelines/3062315272) |
| GitLab CI/CD | same | incomplete: no file in the closure | EMPTY CLOSURE, exit 2 | skipped | [3062315480](https://gitlab.com/lfnsilva.invest/closure-drift-test/-/pipelines/3062315480) |

On GitHub, the `verify` job is green only when all three scenarios behave as above. Its own run, [43137487122](https://github.com/luizfnsilva/closure-drift-release-examples/actions/runs/43137487122), is red on purpose, because of B and C.

The two platforms do not run identical scenarios. On GitHub the check runs on a pushed tag (`--tag`).
On GitLab it runs before tagging (`--would-tag`), and the drift case is code that changed while the
version stayed the same. The rule holds on both: exit 0 lets the publish job run, and exit 1 or 2
stops it.
