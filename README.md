# closure_drift with release tools: three examples

Each job builds a small repository and asks [closure_drift](https://github.com/luizfnsilva/closure_drift)
whether the tag names the version its commit declares. The jobs are in `.github/workflows/examples.yml`.

| Scenario | What happens | Exit |
|---|---|---|
| `release` | bump and tag on the same commit, as python-semantic-release and release-please do | 0 |
| `tag-before-bump` | a tag made by hand before the bump landed | 1: stop the release |
| `insufficient` | nothing declares a version | 2: nothing determined, which is not a pass |

## When it adds nothing

In the normal flow of python-semantic-release and release-please, the bump and the tag land on one
commit, so this check only confirms what the tool already did. It catches what happens around them:
a tag made or moved by hand, a bump push that failed after the tag, or a version file the release
tool does not update (a Cargo workspace member, a `__init__.py`).

With semantic-release, where `package.json` keeps `0.0.0-development` and the tag is the version,
there is nothing to compare: `--tag` reports a mismatch there. Do not use it in that setup.

## In a real workflow

```yaml
- uses: luizfnsilva/closure_drift@v1.5.1   # on a tag push, checks the pushed tag
```
