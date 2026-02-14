After a PR has been merged on the remote, adopt the merge and prepare jj for the next task.

Steps:

1. Run `jj git fetch` to pull the merged commit from remote.
2. Detect any bookmarks on the current revision or its parent (excluding `main`). These are the feature bookmarks to clean up.
3. Delete each detected feature bookmark with `jj bookmark delete <name>`.
4. Run `jj rebase -d main` to rebase the working copy onto the updated main branch.
5. Run `jj log --limit 3` and show the result to confirm the new state.
