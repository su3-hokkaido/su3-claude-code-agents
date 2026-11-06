# Release checklist

Releases are made by the Commander. Claude Code does not commit, push, tag or publish in this repository: it prepares the files and lists the commands.

Each plugin is released on its own. A plugin gets a new version only when its files changed. Its `version` must be raised by hand, because an unchanged `version` means installed users get no update.

## 1. Decide the version

For each plugin that changed, pick the next SemVer version:

- **Patch** (`0.1.0` to `0.1.1`): wording fixes, bug fixes in a hook, no behavior change for users.
- **Minor** (`0.1.0` to `0.2.0`): a new agent, skill, command or option; a changed behavior that users can adapt to.
- **Major** (`0.x` to `1.0.0`, or `1.x` to `2.0.0`): a rename or removal of an agent, skill, command or option; a stricter guard that blocks something that used to work.

Never rename a published plugin. Renames need a `renames` entry in `marketplace.json`.

## 2. Prepare the files

1. Set `version` in `plugins/<plugin>/.claude-plugin/plugin.json`. Do not add a `version` to `marketplace.json`.
2. In `CHANGELOG.md`, add or edit the heading `## <plugin> <version> (unreleased)` with what changed (Added, Changed, Fixed, Removed). Move anything from `Unreleased` that belongs to it.
3. Update the plugin's `README.md` and, if the change is user-facing, the root `README.md`. (`README.ja.md` is a local, unpublished file and is not part of a release.)
4. Run the checks and fix everything they report:

   ```sh
   sh scripts/validate.sh
   claude plugin validate . --strict
   ```

5. Install from the local marketplace and try the plugin in a scratch directory. Remove the marketplace afterwards.

   ```sh
   claude plugin marketplace add ./
   claude plugin install <plugin>@scrum-ai-ecosystem
   # try it in a session, then
   claude plugin marketplace remove scrum-ai-ecosystem
   ```

## 3. Commit and push (run by the Commander)

1. Replace `(unreleased)` in the CHANGELOG headings with the release date, `(YYYY-MM-DD)`.
2. Review the changes: `git status` and `git diff`.
3. Commit and push to `main` through your usual flow. Check that the `Validate` workflow passes on GitHub.

## 4. Tag (run by the Commander)

Tag each released plugin on the commit that carries its new `version`. Run this from the plugin's directory, one plugin at a time. The tag is named `<plugin>--v<version>`, for example `developer-set--v0.1.0`.

Choose **one** of these two ways. Do not run both for the same plugin: `claude plugin tag --push` fails with "Tag ... already exists locally" if the tag was already created.

```sh
cd plugins/<plugin>

# Way A: create the tag and push it in one step
claude plugin tag --push

# Way B: create it locally first, check it, then push it yourself
claude plugin tag
git push origin refs/tags/<plugin>--v<version>
```

If the tag exists locally but was not pushed (for example `--push` failed), push it with the `git push` line from Way B. Do not use `--force`: it would move a tag that others may already have.

Only tags are used. GitHub Releases are not created.

## 5. Verify the published release

In a clean environment (a different machine, or after removing the marketplace):

```sh
claude plugin marketplace add su3-hokkaido/su3-claude-code-agents
claude plugin install <plugin>@scrum-ai-ecosystem
claude plugin list        # shows the new version
```

For an existing install: `claude plugin update <plugin>@scrum-ai-ecosystem`. If it prints `already at the latest version`, the `version` was not raised.

## 6. Afterwards

- Open a new `## Unreleased` section in `CHANGELOG.md` if it is gone.
- If a guard hook changed, say so in the CHANGELOG, because it changes what agents are allowed to do.
