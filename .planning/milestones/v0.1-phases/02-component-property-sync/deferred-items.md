
## Plan 02-03 Deferred Items

### sync_spawn_handler.gd CN_SyncEntity reference

- **File:** `addons/gecs_network/sync_spawn_handler.gd:285`
- **Issue:** References `CN_SyncEntity` which was deleted in plan 02-01 (`chore(02-02): strip sync_config to stub; delete sync_component and cn_sync_entity`)
- **Impact:** Running `runtest.cmd -a "res://addons/gecs_network/tests"` triggers a Godot debugger breakpoint (parser error). Individual test files run fine.
- **Resolution needed:** Plan 04 (NetworkSync wiring) should delete or update `sync_spawn_handler.gd` to remove the stale reference.
