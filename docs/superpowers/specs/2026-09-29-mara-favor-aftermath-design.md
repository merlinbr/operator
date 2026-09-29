# Mara Favor and Aftermath Design

## Goal

Make the existing Mara favor matter in both directions, with a later authored contract choice as the payoff. The player should see when a choice creates, settles, earns, or spends a favor. The lasting balance and changed later choices are the aftermath; existing resolution messages already provide immediate narrative feedback. This specification describes future work, not implemented behavior. Review it before implementation planning.

## Gameplay

- Mara alone has a signed favor balance: `-1` means the player owes Mara, `0` means square, `+1` means Mara owes the player. Initial balance is `0`. There is no state in which both parties owe each other. Changes are capped at `-1` and `+1`; earning credit while in debt settles the debt first.
- C-1042 Cold-Chain Delivery, `call_mara`: balance `-1` (existing obligation). It is only reachable once on a single-use contract.
- M-508 Dead-Drop Audit, `trace_tag`: balance `+1` step (from `-1` to `0`, or `0` to `+1`). Other audit choices leave it unchanged. Tracing grants a favor even if Mara standing is already Trusted.
- R-311 Clinic Asset Recovery, `settle_mara_favor`: available only at `-1`; balance becomes `0`, retaining the existing +2,600 CR, Heat +0, standing +1, result, message, and successor. It is not an option when square or in credit.
- M-613 Silent Partner gains one authored option, `call_in_mara_favor`, available only at `+1`, regardless of Heat. Mara arranges a quiet release: completed, +5,600 CR, Heat +0, no standing change, no preparation requirement, no successor; balance becomes `0`. The favor substitutes for the existing 900/1,300 CR silence payment. Existing paid and high-Heat intermediary routes remain available with their current rewards, gates, and outcomes; mirroring/abort remain available too. M-613's current Trusted standing gate and publication rules still apply.
- Favor changes occur only when a valid resolution is selected. Expired offers, missed active-job deadlines, rejected resolutions, and unrelated choices do not modify the balance. Existing Heat, Credits, standing, preparation, and deadline semantics otherwise remain unchanged.
- The player can earn credit by tracing M-508 before resolving M-613; these contracts may be tackled in either order. If M-613 was already resolved, earning the credit remains visible but cannot retroactively reopen that job or create a new contract. The new route is optional, not guaranteed in every playthrough.

## Presentation and aftermath

- Keep existing immediate resolution messages and tickers. Do not enqueue delayed messages or add a timed follow-up, event/flag/thread system, or new screen. The persisted balance and its later effect on available contract choices are the aftermath in this pass.
- In Comms, show Mara's balance next to her existing standing: `YOU OWE MARA`, `SQUARE`, or `MARA OWES YOU`. Clinic contact display stays as it is. Reuse the existing `contacts_changed` refresh path when the balance changes.
- On the complication screen, give only favor-affecting choice buttons a subtle existing accent-color text override; do not change normal buttons or add animation. Retain full button labels, keyboard/accessibility contrast, and readable outcome previews; color must not be the only cue.
- Choice previews state the actual favor transition alongside Credits/Heat: `MARA FAVOR OWED` for `call_mara`, `FAVOR SETTLED` or `MARA OWES YOU` for `trace_tag` depending on current balance, `FAVOR SETTLED` for hand delivery, `FAVOR SPENT` for the new M-613 option. The resolved result and message for `trace_tag` reflect settling an existing debt versus earning a credit where appropriate. Other choices do not claim to change favors. The balance must be read from GameState at rendering/resolution, not inferred from a static preview.
- The existing resolution message remains enough feedback; no additional acceptance or follow-up message is needed.

## State and data flow

- `autoload/game_state.gd` owns the authoritative `mara_favor_balance: int` and saves/loads it. `data/contracts/contract_catalog.gd` authors choice effects and the new Silent Partner choice. `_available_choices()` checks signed balance for the two gated responses; `resolve_contract()` applies the chosen signed delta once, before emitting change signals and saving. Contract detail continues to receive `GameState` through `setup()` and reads the balance only to render truthful previews; `resolve_contract()` remains the authority for eligibility and effects.
- Replace the legacy Mara-specific boolean choice flags with explicit authored favor effects/requirements on the affected choices; remove the obsolete boolean state rather than keeping two sources of truth. No general per-contact ledger yet; future contacts can be added when a second real favor relationship needs it.
- Increase profile version from 4 to 5. Migrate valid v4 saves by mapping `mara_favor_owed: true` to `-1`, false to `0`, remove the obsolete key on next save; existing older-version migrations must continue through this step. Validate that a v5 balance is an integer in `[-1, 1]`; malformed profile candidates follow existing recovery behavior. Keep authored contract fields reconstructed from the current catalog rather than trusting saved choice data. A save/reload must preserve balance and the correct available choices.
- No timer, random outcomes, new contact, general ledger, inventory, economy, or faction system. No change to clinic standing, existing contract unlock order, or resolution feedback outside the named favor choices.

## Verification

- Play through a debt path: call Mara, confirm `-1` and hand-delivery availability; settle, confirm `0` and its disappearance. Play through a credit path: trace the tag from neutral, confirm `+1`, spend it on Silent Partner, confirm the favor route disappears and the normal routes remain. Trace while in debt to verify cancellation; unrelated/invalid resolutions and deadline failure do not change favor.
- Verify preview text and accent treatment for all four favor transitions and neutral choice styling on the actual contract detail surface; verify Mara's Comms row updates.
- Save/reload balances at `-1`, `0`, and `+1` and migrate a v4 profile with each legacy boolean value. Keep the smallest permanent behavioral checks for favor gating, state transitions, and migration alongside the existing GameState/persistence tests.
