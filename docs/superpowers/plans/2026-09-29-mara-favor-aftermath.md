# Mara Favor and Aftermath Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Mara's one-way favor flag with a signed one-slot balance, let an authored Silent Partner resolution spend a favor, and make favor-changing actions visible without new follow-up messages.

**Architecture:** `GameState` remains the authority for the saved balance, choice eligibility, resolution effects, and legacy migration. The existing contract catalog authors the four affected choices; existing contract detail and Comms panels render their effects from injected `GameState`. No new subsystem or event scheduler.

**Tech Stack:** Godot 4.7.1, GDScript, existing headless `tests/run_test.ps1` runner and JSON profile persistence.

## Global Constraints

- Approved spec: `docs/superpowers/specs/2026-09-29-mara-favor-aftermath-design.md`. No additional contact, favor ledger, timed follow-up, new screen, altered contract order, or change to ordinary Heat/standing/deadline/preparation rules.
- Balance is `-1` (you owe Mara), `0` (square), `+1` (Mara owes you), capped to that range. Opposite favor changes cancel first. All favor changes require a valid selected resolution.
- Preserve existing C-1042 debt, R-311 settlement reward, and all old save versions; v4 `mara_favor_owed` migrates to v5 `mara_favor_balance`. Remove old fields and choice flags from current schema, catalog, code, and tests.
- Catalog's M-613 favor option pays +5,600 CR, gains zero Heat and standing, requires a positive balance regardless of Heat, consumes one favor, and leaves ordinary choices unchanged.
- Do not modify untracked idea documents or historical design docs. Update `next-features.md` only after the feature is verified.

---

## File map

- `autoload/game_state.gd`: authoritative balance, state transitions, conditional resolution text, contact snapshot, save/load/validation/migration.
- `data/contracts/contract_catalog.gd`: authored signed favor deltas, exact balance gates, new M-613 response.
- `scenes/modules/contracts/contract_detail.gd`: favor preview and subtle button text tint; no authorization.
- `scenes/modules/comms/comms_panel.gd`: Mara favor label alongside standing.
- `tests/test_game_state.gd`, `tests/test_persistence.gd`, `tests/test_contracts.gd`, `tests/test_panels_basic.gd`: consumer-visible transitions, migration, rendering.
- `tests/test_deadlines.gd`, `tests/test_preparation.gd`, `tests/test_contract_catalog.gd`: migrate old boolean references; remove the catalog test that merely pins old choice-flag wiring.
- `next-features.md`: replace now-obsolete current-state/recommendation statements after verification, keep broader systems deferred.

### Task 1: Favor rules, authored route, and save compatibility

**Files:** Modify `autoload/game_state.gd:19-50,87-110,150-175,201-229,263-345,484-520,708-722,838-869,890-892`; `data/contracts/contract_catalog.gd:35-39,132-139,163-171,198-203`; `tests/test_game_state.gd`; `tests/test_persistence.gd`; `tests/test_deadlines.gd`; `tests/test_preparation.gd`; `tests/test_contract_catalog.gd`.

**Interfaces:** Produces `mara_favor_balance: int`, `contact_snapshot()` Mara `favor_label: String`, and catalog fields `mara_favor_delta: int` (`-1`/`+1`), `requires_mara_balance: int` (`-1`/`+1`). These are the only favor choice fields; `GameState.resolve_contract()` remains the only mutation path.

- [ ] **Step 1: Write failing behavioral checks** in `test_game_state.gd` using the existing `_resolve_c1042`, `_choice_ids`, and `_at_silent_partner` helpers. Exercise real contract order (C-1042 unlocks M-508 and D-207; D-207 unlocks M-613/R-311), not hand-set balance. Add this core sequence (with `check()` per transition):

```gdscript
var credit := GameStateScript.new()
_resolve_c1042(credit, &"pay_fee")
check(credit.accept_contract(&"dead_drop_audit")
    and credit.proceed_contract(&"dead_drop_audit")
    and credit.resolve_contract(&"dead_drop_audit", &"trace_tag")
    and credit.mara_favor_balance == 1, "tracing earns Mara credit")
check(credit.accept_contract(&"data_retrieval")
    and credit.proceed_contract(&"data_retrieval")
    and credit.resolve_contract(&"data_retrieval", &"spoof_credentials"),
    "D-207 publishes Silent Partner at Trusted Mara standing")
check(credit.accept_contract(&"silent_partner")
    and credit.proceed_contract(&"silent_partner"), "favor path reaches M-613")
credit.heat = 6
var ids := _choice_ids(credit.get_contract(&"silent_partner"))
check(ids.has(&"call_in_mara_favor") and ids.has(&"buy_intermediary_silence")
    and ids.has(&"mirror_archive"), "favor route coexists with high-Heat routes")
var before := credit.credits
check(credit.resolve_contract(&"silent_partner", &"call_in_mara_favor")
    and credit.mara_favor_balance == 0 and credit.credits == before + 5600
    and credit.heat == 6, "favor spends for full payout without added Heat")
credit.reset_profile()
credit.free()
```

Also add debt cancellation (`call_mara` -> `trace_tag` yields `0` and hides R-311 hand delivery); debt settlement without tracing (`call_mara` -> D-207 -> R-311 hand delivery yields `0` and +2,600 CR); negative/zero balance rejects M-613 favor route without changing Credits, balance, or active job; unrelated paid and abort routes preserve balance; deadline expiry preserves balance. Replace every live boolean expectation/fixture in the listed tests with `-1` or `0` assertions; retain old boolean **only** in intentionally serialized legacy fixtures. Delete `test_contract_catalog.gd`'s two-line flag-presence check rather than rewriting it as another wiring assertion.

- [ ] **Step 2: Run focused tests to see failures.** `powershell -NoProfile -File tests/run_test.ps1 -Test test_game_state` and `powershell -NoProfile -File tests/run_test.ps1 -Test test_persistence`. Expected before implementation: missing `mara_favor_balance` / new authored M-613 choice.

- [ ] **Step 3: Implement authored effects.** In `contract_catalog.gd`, replace `sets_mara_favor_owed` on `call_mara` with `"mara_favor_delta": -1`; add `"mara_favor_delta": 1` to `trace_tag`; replace `requires_mara_favor` / `clears_mara_favor` on `settle_mara_favor` with `"requires_mara_balance": -1, "mara_favor_delta": 1`. Add this complete choice to M-613, with existing M-613 choices untouched:

```gdscript
{"id": &"call_in_mara_favor", "label": "CALL IN MARA'S FAVOR",
 "requires_mara_balance": 1, "mara_favor_delta": -1,
 "credit_delta": 5600, "heat_delta": 0, "contact_standing_delta": 0,
 "terminal_status": &"completed", "unlocks_contract_ids": [],
 "preview": "+5,600 CR // HEAT +0 // CONTRACT COMPLETE // FAVOR SPENT",
 "result": "MARA'S CHANNEL OPENED // FILE RELEASED // FAVOR SPENT",
 "ticker": "CONTRACT COMPLETE // +5,600 CR // FAVOR SPENT",
 "message_sender": "MARA", "message_preview": "The file is yours. We're square."},
```

For M-508's `trace_tag`, retain its +2,600 CR and Mara standing +1 but set `preview` to `+2,600 CR // HEAT +0 // CONTRACT COMPLETE // MARA OWES YOU`, `result` to `TAG TRACED // DROP SECURED // MARA OWES YOU`, and `message_preview` to `You found the leak without waking it. I owe you one.` The debt-to-square case uses `FAVOR SETTLED` instead at render/feedback time; never persist an alternate authored result.

- [ ] **Step 4: Implement authoritative balance and migration** in `game_state.gd`. Set `PROFILE_VERSION := 5`, replace boolean default/reset/payload/apply with `mara_favor_balance: int = 0`, `"mara_favor_balance": mara_favor_balance`, and `int(data.mara_favor_balance)`. Change `_available_choices` to:

```gdscript
if choice.has("requires_mara_balance") \
        and mara_favor_balance != int(choice.requires_mara_balance):
    continue
```

In `resolve_contract`, after valid choice selection and before signal emission/save, apply `mara_favor_balance = clampi(mara_favor_balance + int(choice.get("mara_favor_delta", 0)), -1, 1)` only for choices with the delta field and emit `contacts_changed` when it actually changes. `contact_snapshot()` adds `favor_label` only for Mara, mapping `-1/0/+1` to `YOU OWE MARA` / `SQUARE` / `MARA OWES YOU`; no second favor store. When `trace_tag` is resolved with the old balance `-1`, pass a **copy** of the authored choice to `_push_resolution_feedback` with `message_preview: "We're square. You found the leak without waking it."`; the contract detail derives its terminal result from the final balance (`0` means settled, `1` means Mara owes the player). Do not mutate catalog data or persist a redundant result field. Preserve unrelated ticker/message and choice effects.

In `_read_profile_candidate`, validate v4 with the old boolean field before migration. In `load_profile`, after existing v2/v3 migrations, add v4 -> v5 conversion and validation **before** `_apply_profile`:

```gdscript
func _migrate_v4_profile(data: Dictionary) -> Dictionary:
    var migrated := data.duplicate(true)
    migrated.mara_favor_balance = -1 if data.mara_favor_owed else 0
    migrated.erase("mara_favor_owed")
    migrated.version = 5
    return migrated
```

Adapt `_validate_profile` so shared fields are required for all versions, v1-v4 require a bool `mara_favor_owed` while v5 requires a strict integer in `[-1, 1]` (reject bool, float, missing, and out-of-range; `_is_int_value` is intentionally too permissive here). Ensure older v1-v3 migrations still pass their original validation and then flow through v4 migration; keep existing deadline/prep migration behavior and saved-authoritative-record reconstruction. `load_profile` must persist migrated v5 once, not renew deadlines.

- [ ] **Step 5: Test save semantics** in `test_persistence.gd`: round-trip each balance `-1/0/+1`; synthesize v4 profile payloads by removing `mara_favor_balance`, inserting `mara_favor_owed` for both true and false, setting `version = 4`, then write via existing `_write_deadline_profile`; load and verify signed balance, version 5 saved and obsolete key removed. Update v1-v3 fixture generation similarly, including existing `version == 4` expectations -> `5`; turn the existing legacy Alerts fixture into a genuine version-4 payload rather than labeling a v5 payload as v4. Reject v5 balance `-2`, `2`, `true`, `0.5`, and missing. Reset between invalid fixtures to avoid alternate save candidates. Check reload with credit still exposes M-613 option after reaching its complication; expired or rejected choices do not affect saved balance. In `test_game_state.gd`, adjust the `contacts_changed` count in the existing call-Mara test: standing rises and favor changes, so both emit; verify one fresh state refresh reflects both facts.

- [ ] **Step 6: Run focused behavioral suites and commit.** Run `test_game_state`, `test_persistence`, `test_deadlines`, `test_preparation`, `test_contract_catalog` via `powershell -NoProfile -File tests/run_test.ps1 -Test <name>`; expected: `RESULT: ALL PASSED` and process exit 0 for each. Check for legacy flag references outside intentionally old-save fixtures, then commit only these files: `git add -- autoload/game_state.gd data/contracts/contract_catalog.gd tests/test_game_state.gd tests/test_persistence.gd tests/test_deadlines.gd tests/test_preparation.gd tests/test_contract_catalog.gd && git commit -m "feat: make Mara favors reciprocal and spendable"`.

### Task 2: Clear favor presentation on existing surfaces

**Files:** Modify `scenes/modules/contracts/contract_detail.gd:4-8,131-145,149-162`; `scenes/modules/comms/comms_panel.gd:40-55`; `tests/test_contracts.gd`; `tests/test_panels_basic.gd`.

**Interfaces:** Consumes Task 1's `gs.mara_favor_balance`, `contact_snapshot()` Mara `favor_label`, and choice fields `mara_favor_delta`, `requires_mara_balance`. UI does not modify favors; resolution requests carry only contract/choice IDs.

- [ ] **Step 1: Add a failing UI scenario** in `test_contracts.gd` using a fresh `GameState` and contract detail: C-1042 at complication displays `MARA FAVOR OWED` for `CALL MARA`; its button is tinted while `PAY CLEARANCE FEE` is not. After `call_mara`, M-508 `trace_tag` preview reads `FAVOR SETTLED`; after a neutral `pay_fee` path to M-508, the same action reads `MARA OWES YOU`. On the positive-balance M-613 path, the favor action visibly reads `FAVOR SPENT` and remains selectable at Heat 6; ordinary intermediary action is not tinted. Assert button text color via `has_theme_color_override("font_color")` and the visible preview via existing `_text(detail)`, rather than source-text assertions. Update `test_panels_basic.gd` to assert the Mara contact row shows `SQUARE` initially and `YOU OWE MARA` after the real `call_mara` resolution, while the clinic row stays unchanged. Run both focused suites and observe their missing UI state.

```gdscript
var call_button := _button(detail, "CALL MARA")
check(call_button != null and call_button.has_theme_color_override("font_color")
    and not _button(detail, "PAY CLEARANCE FEE // 250 CR").has_theme_color_override("font_color")
    and _text(detail).contains("MARA FAVOR OWED"),
    "favor action is legible and distinguished from a normal choice")
```

- [ ] **Step 2: Implement presentation** with no new panel or signal. In `comms_panel.gd`, append `" // " + str(contact.favor_label)` to Mara's existing `display_name // standing_label` row only when `contact.has("favor_label")`. In `contract_detail.gd`, obtain the `Button` returned by `_add_action` in `_render_customs`, and when `choice.has("mara_favor_delta")` apply a subtle `font_color` override using the existing accent palette. Keep normal buttons unmodified and text readable. For `trace_tag` when `gs.mara_favor_balance == -1`, replace its visible static credit outcome's favor suffix with `FAVOR SETTLED`; otherwise display `MARA OWES YOU`. Preserve current preview text for every unrelated choice and avoid a second label/choice tree. On resolved `trace_tag`, render the same balance-dependent result using the recorded resolution's outcome (`0` after settlement, `1` after earning) rather than trusting static positive-case catalog copy. Color supplements words, never replaces them.

```gdscript
# comms_panel.gd, inside _make_contact_row():
label.text = "%s // %s" % [contact.display_name, contact.standing_label]
if contact.has("favor_label"):
    label.text += " // " + str(contact.favor_label)

# contract_detail.gd, beside existing color constants:
const COLOR_FAVOR := Color(0.22353, 0.81569, 1.0) # existing Comms accent

# contract_detail.gd, inside _render_customs():
var button := _add_action(choice.label, _emit_resolution.bind(choice_id))
if choice.has("mara_favor_delta"):
    button.add_theme_color_override("font_color", COLOR_FAVOR)
```

- [ ] **Step 3: Verify the actual UI path.** Run `test_contracts` and `test_panels_basic` via existing runner and launch the project with `& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --path .`; navigate Cold-Chain Delivery -> `CALL MARA` and open Comms to observe the debt label, then use a reset profile for `pay_fee` -> Dead-Drop Audit -> `trace_tag` -> Silent Partner and observe the positive balance, accent, preview, and normal alternate choices. Close the running project. Commit only UI and UI-test files: `git add -- scenes/modules/contracts/contract_detail.gd scenes/modules/comms/comms_panel.gd tests/test_contracts.gd tests/test_panels_basic.gd && git commit -m "feat: show Mara favor outcomes in contracts and Comms"`.

### Task 3: Final integration and current-feature notes

**Files:** Modify `next-features.md:7,32-59` only after verified gameplay; no historical spec edits.

**Interfaces:** No new runtime interface. Ensures docs describe the implemented Mara-only scope rather than claiming a per-contact ledger or delayed messages exist.

- [ ] **Step 1: Run full project suites** without depending on the user's untracked `tests/run_all.ps1`. From PowerShell:

```powershell
foreach ($name in @("test_persistence","test_panels_basic","test_module_registry","test_main","test_icon_rail","test_game_state","test_contracts","test_preparation","test_contract_catalog","test_deadlines","test_environment","test_boot","test_smoke","test_status_chip","test_ticker_bar","test_theme")) {
    powershell -NoProfile -File tests/run_test.ps1 -Test $name
    if ($LASTEXITCODE -ne 0) { throw "$name failed" }
}
```

Expected: `RESULT: ALL PASSED` and exit 0 for each. Run an end-to-end actual Godot session if Task 2 did not complete its live smoke; observe the favor route and Comms. Check no current code/test reference to legacy boolean or its old choice flags remains; historical design docs may keep them.
- [ ] **Step 2: Update `next-features.md`** current-state and recommendation to say Mara now has signed favor debt/credit, the M-508 -> M-613 option is an authored consequence, and separate timed follow-ups/per-contact expansion are not implemented. Preserve explicit deferral of inventory, crew, market, and maps. Do not present the old per-contact ledger/follow-up proposal as already shipped.
- [ ] **Step 3: Commit documentation:** `git add -- next-features.md && git commit -m "docs: record Mara favor depth pass"`. Do not stage the user's untracked idea files or scripts.
