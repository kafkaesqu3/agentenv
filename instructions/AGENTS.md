# Task completion

When the current working directory is inside a Git repository, automatically
commit your completed task changes after the relevant verification passes, before
reporting completion. Do not ask for separate commit confirmation.

Commit only changes belonging to the task; leave unrelated user changes untouched.
If there are no task changes, do not create an empty commit. Report the commit hash,
or explain any blocker that prevents committing. Do not push unless requested.

Outside a Git repository, complete the task without creating a repository just to
make a commit.
