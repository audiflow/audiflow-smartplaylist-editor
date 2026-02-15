Create a GitHub PR for the current jj revision using the jj + gh workflow.

Steps:

1. Run `jj log --limit 3` to see the current revision, its description, and bookmark.
2. If no bookmark exists on the current revision, ask the user for a bookmark name (suggest one based on the description).
3. Push the bookmark: `jj git push --bookmark <name>`.
4. Gather the diff for the PR body: `jj diff -r @`.
5. Draft the PR title (under 70 chars) and body from the revision description and diff. Use this format:
   ```
   ## Summary
   <1-3 bullet points>

   ## Test plan
   <bulleted checklist>
   ```
6. Create the PR: `gh pr create --base main --head <bookmark> --title "<title>" --body "<body>"`.
7. Print the PR URL.
