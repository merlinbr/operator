# Contract Deadlines Design

## Goal

Make waiting, resting, and contract ordering consequential by enforcing publication-relative deadlines on the existing seven-contract portfolio.

## Approved decisions

The user selected publication-relative timing and hard failure, then approved the rules, initial windows, presentation, and migration policy below. This supersedes the fixed-calendar proposal in `next-features.md`; it does not implement Heat or preparation.

- Publication means the first transition to `is_playable = true`, not acceptance or satisfaction of a standing requirement.
- Every published unfinished job has a fixed deadline. Accepting, opening a panel, and reloading never extend it.
- At the deadline minute (`now >= deadline`), an unaccepted offer becomes `expired`; an active job becomes `failed`.
- Both deadline outcomes publish the successors listed by that contract's existing `abort` choice. They do not execute the abort choice or reuse its narrative.
- Deadline outcomes change no Credits, Heat, standing, or favors. Existing rent settlement still applies when time advances.
- Standing requirements remain unchanged. Publication does not guarantee acceptance; missing opportunities can still prevent earning standing. No recovery jobs or guaranteed portfolio completion are added.
- Only existing game-time actions advance the clock. Reading, choosing, and time spent outside the game do not.

## Initial authored windows

| Contract ID | Minutes after publication | Window |
|---|---:|---|
| `cold_chain_delivery` | 259 | 4h 19m; retains the opening Day 15 04:00 cutoff |
| `data_retrieval` | 360 | 6h |
| `dead_drop_audit` | 480 | 8h |
| `silent_partner` | 720 | 12h |
| `clinic_asset_recovery` | 360 | 6h |
| `dialysis_relay` | 480 | 8h |
| `quarantine_manifest` | 720 | 12h |

These are initial balancing values in the catalog, not constants embedded in scheduling logic. Every window exceeds its job's existing `proceed_minutes`.

## State model

Keep catalog ownership in `data/contracts/contract_catalog.gd` and mutable state in `autoload/game_state.gd`. Do not create a scheduler, timer node, service, or generic outcome engine.

- Replace authored `deadline_day` and `deadline_minute` with `deadline_window_minutes: int`.
- Add mutable `deadline_at_minute: int`: absolute game minute `(day - 1) * 1440 + minute_of_day`. `-1` means no assigned deadline.
- On a fresh state, stamp the initially published job relative to the initial clock. This must work for `GameStateScript.new()` as well as normal boot; headless callers do not necessarily enter the tree.
- First publication stamps `deadline_at_minute = publication_minute + deadline_window_minutes`. Re-publication is a no-op and never resets terminal state or the cutoff.
- Unpublished records have `deadline_at_minute = -1`; published unfinished records must have a nonnegative cutoff.
- Terminal records retain an assigned cutoff where one exists. Legacy completed/failed records may use `-1` because their historical publication time is unknown.
- A deadline terminal record uses `phase = resolved` and `resolution_id = deadline_missed`. `expired` is valid only for an unaccepted offer's terminal outcome; `failed` also covers the active deadline outcome.
- `deadline_missed` is a system resolution reason, not a selectable complication choice. Render it explicitly before looking up authored resolution choices.

## Time advancement and ordering

Extend `_advance_minutes()` so it advances to the next relevant boundary: the requested target, midnight, or a pending contract deadline. It is still the existing game clock, not a new event subsystem.

1. Set the clock to the next boundary.
2. If midnight was crossed, settle rent through `_settle_calendar_day()` first, retaining current monthly and overdue behavior.
3. Settle all published unfinished contracts due at that minute in catalog order. Mark each terminal before publishing successors and clear `active_contract_id` only if it names that contract.
4. Stamp successors using that boundary minute. Continue toward the requested target; new deadlines crossed by the same action must also settle.
5. Expose coherent contract state through the existing notifications. Emit `clock_changed` once at the final clock, as today. Each deadline generates feedback once, not on subsequent refreshes or time advances.

An advance of 620 minutes from the fresh state expires Cold-Chain Delivery at minute 259 relative to start, publishes Data Retrieval and Dead-Drop Audit there, expires Data Retrieval at minute 619, and publishes its successors there. It does not give Data Retrieval a new six-hour window at the end of the advance.

A zero or negative time advance remains a no-op. Reconcile valid overdue version-3 records on load separately; do not use zero-minute advancement as a hidden mutation API.

### Active operations

`proceed_contract()` must check the contract again after `_advance_minutes()`. If travel caused deadline failure, retain `resolved`, do not emit `contract_proceeded`, and do not open the complication or send its arrival message. The accepted time-consuming action returns true and saves its outcome even when that outcome is deadline failure. Rejected calls return false without advancing time or producing duplicate feedback.

Use the same authoritative deadline condition in availability and action guards; the UI cannot bypass expiry. A job at or beyond its deadline cannot be accepted, proceeded, or resolved for a payout. Normal game-time advancement and load reconciliation perform terminal transitions; stale action requests must not resurrect them.

A normal choice remains valid strictly before the cutoff. Resolution itself continues to consume no time. Existing REST restrictions while a contract is active remain unchanged.

## Progression and feedback

- Normal authored resolutions continue using their own successor lists, rewards, and messages.
- Deadline outcomes reuse only the abort successor IDs, not the abort choice's other fields. The current catalog contains an abort choice on every job; catalog coverage must defend this requirement.
- Publish a message from the associated Contact using the existing contact catalog display name, identifying the job and missed deadline. Publish an existing-style ticker message.
- Emit `contracts_changed` after terminal state and successor publication are coherent.
- Emit `contract_resolved(id, failed)` once for active deadline failure so the existing failure audio works. For an expired unaccepted offer, use `contract_resolved(id, expired)`; the current audio handler deliberately plays no failure sound for that status.
- Do not generate new sound assets, alerts, reputation penalties, or bespoke narrative branches.

## Contract UI

Reuse the existing Contracts list, detail panel, ticker, and Comms.

- Render the calculated Day/Time cutoff and authored execution duration in the offer and ready views.
- If `now + proceed_minutes >= deadline_at_minute`, show a textual warning that proceeding will miss the deadline in both views. Keep the action enabled while the job is still valid; this is information, not an auto-abort or a new cancellation feature.
- `expired` rows are disabled and visibly labeled EXPIRED. Existing active/complete/failed and standing-gated states remain intact.
- If a selected offer expires, its open detail changes to an expiry explanation with ACKNOWLEDGE and no ACCEPT/PROCEED/resolution actions.
- An active deadline failure renders CONTRACT FAILED, the missed-deadline reason, and zero contract Credits/Heat changes, with ACKNOWLEDGE. It must not dereference a missing authored choice.
- Normal resolved-choice rendering stays as it is. No countdown animation or new panel is required.
- Reuse the main scene's `contracts_changed` refresh path and setup injection. If an open offer/ready warning can change on a clock advance without any expiry, refresh that selected detail on `clock_changed` as well.

## Persistence and migration

Bump the profile to version 3 because cutoffs become persistent mutable state.

- Persist and restore `deadline_at_minute` alongside `is_playable`, `status`, `phase`, and `resolution_id`. Do not trust saved authored windows, costs, choices, or rewards; reconstruct those from the catalog as today.
- Validate deadline fields as integers, allowing only `-1` or nonnegative values with the state combinations described above. A deadline terminal outcome requires a nonnegative cutoff. An active ID must identify the unique active record, not merely any catalog ID.
- Preserve version-1 contact migration as the first step, then migrate version 2 to version 3.
- For every published unfinished legacy job, assign `saved_clock + authored_window` once. This deliberately avoids punishing a player for deadlines that were not previously enforced.
- Unpublished legacy jobs receive `-1`. Completed/failed legacy records preserve their resolution and receive `-1`; no historical cutoff is invented.
- Persist a successful legacy migration immediately using existing atomic save handling. A failed persistence attempt reports failure through the existing error path and leaves the old file recoverable; never report successful persistence or reset the player's progress.
- A current-version save must never get fresh windows on reload. If it contains valid overdue unfinished records, reconcile them chronologically using the stored cutoffs and the saved clock, including successors that would also be overdue. Do not advance the saved clock or charge rent again. Save only when migration or reconciliation changed state; repeat loading produces no duplicate messages.
- Preserve candidate fallback, single-profile storage, housing, contact state, and atomic replacement. No save slots or legacy deadline-field aliases are added.

## Verification and acceptance

1. Initially published work has a deadline; unpublished work does not. Delayed first publication starts a full window, including a published job whose standing gate is unmet.
2. Acceptance, repeated publication, panel refreshes, and same-version reloads do not extend a cutoff.
3. One minute before the deadline remains actionable; equality expires/fails. Include a same-day boundary, not only midnight.
4. Expiry leaves the offer disabled, produces one explanation, publishes abort successors, and applies no economic, Heat, standing, or favor effects.
5. Proceeding across the cutoff fails once, frees the active slot, awards nothing, and never opens the complication or emits an arrival event.
6. Advancing while already at a complication can fail the active job; resolving afterward is rejected without reward.
7. A long advance and equivalent smaller advances produce the same statuses, cutoff values, publication results, messages, and rent result. Cover simultaneous expiry and a midnight tie.
8. Completed/failed/expired records stay terminal; later actions cannot publish them anew or duplicate deadline feedback.
9. Version-3 deadlines and terminal reasons round-trip. Legacy version 1 and 2 saves migrate once without losing progress. Malformed cutoffs/state combinations are rejected through existing recovery behavior.
10. Loading an overdue current-version save reconciles the portfolio without changing the saved clock or settling rent again; a second load is idempotent.
11. The real Contracts surface shows cutoffs, execution duration, a late-arrival warning, disabled expired rows, and a working acknowledgement for deadline failure. Refresh after time advancement removes stale actions.
12. Existing headless suites remain green, including normal rewards, standing, audio transitions, rent, and profile recovery.

Use existing GDScript test conventions and focused regression cases for these uncertain boundaries. Tests write the real `user://` save paths: execute in a disposable project/user-data context, never against the player's unprotected profile. Runtime UI verification must also use disposable state.

## Non-goals

Heat consequences or decay, preparation, late rewards, deadline extensions, recurring or generated jobs, recovery content, penalties beyond missed work, new inventory/favor/faction systems, real-time timers, and UI redesign are out of scope.
