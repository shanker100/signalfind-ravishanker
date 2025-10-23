# Ops

- **Dashboards**: p95 latency, 5xx, ECS CPU/Mem, queue lag, index backlog.
- **Alerts**: Paging on SLO burn rate (99.9%), p95>300ms sustained, 5xx>1%, DLQ>0, snapshot failures.
- **On-call**: Primary/secondary rotation; weekly handoff notes.
- **Playbooks**: cache flush, shard reallocation, blue/green deploy rollback.
