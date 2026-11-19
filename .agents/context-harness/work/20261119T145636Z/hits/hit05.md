Local workflow
## Local workflow

1. Read the files the request concerns, plus the applicable `llms.txt` chain.
2. When `ainish-rag` is present, make one `ainish-rag context --task "<request>"` call — its `orientation` section already carries branch, worktree, tree state, today's COMMS, and the newest task record. Otherwise use `bin/context-packet.sh --task "<request>"` for a bounded non-RAG summary.
3. Create or update one task record; declare `compat:` and `budget:` when applicable. When the work
   was designed through `question-me`, the task record carries a `plan:` line pointing at
   `.agents/plans/{date}-{HH}-{slug}.md` and does not restate the plan.
4. Use one writer per shared boundary; append coordination entries rather than rewriting them.
5. Verify the changed surface, then close COMMS, task, memory, and suggestions.