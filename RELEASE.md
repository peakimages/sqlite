# Releases

Every release is tagged `v<sqlite version>-v<image version>`, such as `v3.54.1-v1.4.0-beta.1`.

> [!IMPORTANT]
> A push that changes `release.json` or `src/upstream.json` publishes every release of it whose tag does not exist yet. Check what a push publishes with `scripts/plan-version.sh` first.

## Rules

| Branch         | Takes                                                      | Releases                               |
| -------------- | ---------------------------------------------------------- | -------------------------------------- |
| `main`         | fixes, and `next` or a release branch for a new version    | stable versions                        |
| `next`         | features                                                   | prereleases of the next minor or major |
| `release/v1.4` | the minor 1.4, split off `next` so `next` can go on to 1.5 | prereleases of `1.4.0`                 |
| `release/v2.0` | the next major, cut from `next`                            | prereleases of `2.0.0`                 |
| `v1.x`         | backports, once `main` is on v2                            | stable `1.x` versions                  |
| `v1.2.x`       | backports and hotfixes, cut from the newest tag of v1.2    | stable `1.2.x` versions                |

- `main` takes fixes only. A new minor or major reaches it as a merge of `next` or a release branch
- `next` and the release branches publish prereleases only, their stable versions are released on `main`
- Name a branch after what it changes: `fix/<topic>`, `feat/<topic>`, and `fix/<topic>-v1.2.2` for a backport, after the version that releases it
- Squash merge pull requests from contributors and pull requests with a single change, such as SQLite updates
- Merge everything else with a merge commit: team pull requests with several commits, backports, `next`, the release branches and `v1.3.x` into `main`
- The merge forward workflow merges `main` into `release/v1.4` and `next`, and `release/v1.4` into `next`
- While `main` is on 1.3, `v1.1.x` and `v1.2.x` are never merged into another branch
- Delete `release/v1.4` once `main` has released `1.4.0`
- Delete `v1.3.x` once it is merged into `main`
- Delete `v1.1.x` and `v1.2.x` once their release is published, the next backport cuts them again from the newest tag

> [!CAUTION]
> Never squash merge `next` or a release branch. Their commits stay unmerged and come back as conflicts in every later merge.

## Create a release

> [!NOTE]
> `next` publishes prereleases only. For its stable version, merge `next` into `main` with a merge commit and create the release on `main`.

1. Describe the changes under `## [Unreleased]` in `CHANGELOG.md`, they become the release notes
2. Check what the branch releases:

   ```sh
   scripts/plan-version.sh
   ```

3. Select the stage and the version, the script commits them and asks to push:

   ```sh
   scripts/release.sh
   ```

4. The pushed commit changes `release.json`, so it runs the release workflow, which builds, tests and publishes the release and moves its tags

> [!TIP]
> To take the release commit back before the push:
>
> ```sh
> scripts/undo-release.sh
> ```

## Backport a fix

`main` is on 1.3, and 1.1 and 1.2 still get fixes. A fix reaches each of them through a patch branch and a pull request of its own:

1. Cut the patch branch from the newest tag of the minor, unless it exists:

   ```sh
   git switch -c v1.2.x v3.54.1-v1.2.1 && git push -u origin v1.2.x
   ```

2. Put the fix on a branch named after the version that releases it, cherry-picked from `main` when it is there already:

   ```sh
   git switch -c fix/<topic>-v1.2.2 origin/v1.2.x && git cherry-pick -x <commit>
   ```

3. Merge a pull request from `fix/<topic>-v1.2.2` into `v1.2.x` with a merge commit
4. Create the release on your checkout of `v1.2.x`:

   ```sh
   git switch v1.2.x && git pull && scripts/release.sh
   ```

5. Repeat with `v1.1.x` and `fix/<topic>-v1.1.4`. 1.0 gets no backports

> [!IMPORTANT]
> A hotfix for 1.3 while `main` holds unreleased changes goes through `v1.3.x` the same way. Merge `v1.3.x` into `main` with a merge commit afterwards and delete it. `v1.1.x` and `v1.2.x` are never merged, their fixes come from `main`.

## Add an older SQLite line

1. Pin the line on a branch from `main`:

   ```sh
   git switch -c feat/sqlite-3.53 origin/main && scripts/check-upstream.sh 3.53
   ```

2. Squash merge a pull request as `feat(release): add the SQLite 3.53 line`, the push publishes `v3.53.4-v1.3.0`
3. To stop the line, remove `3.53` from `src/upstream.json`, its tags stay where they are

## Release a major version

1. Cut `release/v2.0` from `next` and create its prereleases there with `scripts/release.sh`:

   ```sh
   git switch -c release/v2.0 origin/next && git push -u origin release/v2.0
   ```

2. Merge `main` into `release/v2.0`, so v2 has every fix of v1 and the pull request into `main` has no conflicts:

   ```sh
   git switch release/v2.0 && git pull && git merge origin/main && git push
   ```

3. Keep v1 on a branch of its own:

   ```sh
   git switch -c v1.x origin/main && git push -u origin v1.x
   ```

4. Merge a pull request from `release/v2.0` into `main` with a merge commit
5. Create the release on `main` and select `2.0.0`:

   ```sh
   git switch main && git pull && scripts/release.sh
   ```

6. Delete `release/v2.0`

> [!IMPORTANT]
> Cut `v1.x` from `main`, or bring an existing one up to date with `main`, before `release/v2.0` is merged into `main`. Afterwards `main` is v2 and v1 lives on `v1.x` alone.

## Pull requests

The pull request workflow builds every pull request and publishes the image of the line `latest` of one from a branch of this repository as `ghcr.io/peakimages/sqlite:pr-<number>`, versioned `<base>-pr.<number>`: pull request 1234 into `next` is `1.4.0-beta.1-pr.1234` after `1.4.0-beta.1` and `1.5.0-alpha.0-pr.1234` before the first alpha of 1.5.0, into `main` `1.3.4-pr.1234`. PHP's `version_compare` sorts it after its base and before the next prerelease or release.

- Pull requests from forks and Dependabot are built, not published
- Pull requests from `main`, `next`, a release branch or a patch branch are not built, the release workflow builds their commits
- ghcr.io only, no git tag and no GitHub release, the clean manifests workflow keeps the image while the pull request is open

## Tags

| Tag                             | Points at                                                                               |
| ------------------------------- | --------------------------------------------------------------------------------------- |
| `3.54.1-v1.3.0`                 | one release, it never moves                                                             |
| `latest`, `3.54.1`, `3.54`, `3` | `3.54.1-v1.3.0`, the newest SQLite version of the newest stable image version           |
| `3.53.4`, `3.53`                | the newest stable image version released with SQLite 3.53, also once the line stops     |
| `preview`                       | the newest prerelease of the lowest version in prerelease above `latest`, else `latest` |
| `pr-123`                        | the image of the newest push to an open pull request, on ghcr.io only                   |
