# Contact Contract Progression Design

## Goal

Turn the current three-contract linear portfolio into a small continuing progression loop: seven authored contracts across Mara and the Vesper Clinic Coordinator, with visible one-way contact standing that gates published work.

## Ubiquitous language

- **Contact:** a named source of contracts and messages.
- **Contact standing:** a Contact-local availability tier: `COLD` (0), `KNOWN` (1), or `TRUSTED` (2).
- **Favor:** Mara's existing discrete debt. It remains independent from Contact standing.
- **Published contract:** an authored contract whose existing `is_playable` state is true. A published contract can still be unavailable until its Contact-standing requirement is met.
- **Resolution:** the player's final authored choice in a contract complication. A resolution may grant one standing tier; it never removes a tier in this slice.

## Player experience

COMMS presents both contacts before its message rows:

- `MARA // KNOWN` at a fresh start.
- `VESPER CLINIC // COLD` at a fresh start.

The labels update immediately when a resolution grants standing. The Contracts panel continues to list every contract. Its row states distinguish unpublished work (`NETWORK OFFLINE`) from published work that needs a higher relationship (`MARA // TRUSTED REQUIRED` or `VESPER CLINIC // KNOWN REQUIRED`).

The player cannot accept a published contract unless it is available, has no active contract, and meets its Contact-standing requirement. Existing contract detail and event-sequence flow remain unchanged.

## Contract portfolio

Retain the current content and add four jobs. The portfolio is authored, deterministic, and finite.

| Code | Contract | Contact | Publish condition | Minimum standing |
|---|---|---|---|---|
| C-1042 | Cold-Chain Delivery | Mara | fresh profile | COLD |
| D-207 | Data Retrieval | Mara | resolve C-1042 | KNOWN |
| M-508 | Dead-Drop Audit | Mara | resolve C-1042 | KNOWN |
| M-613 | Silent Partner | Mara | resolve D-207 | TRUSTED |
| R-311 | Clinic Asset Recovery | Vesper Clinic | resolve D-207 | COLD |
| H-118 | Dialysis Relay | Vesper Clinic | resolve R-311 | KNOWN |
| Q-219 | Quarantine Manifest | Vesper Clinic | resolve H-118 | TRUSTED |

`is_playable` continues to mean published. All resolution paths that finish or abort a publisher contract publish the designated successor, preserving the existing no-dead-end rule.

Strong, authored resolutions raise standing by one tier, capped at `TRUSTED`. Other completed, failed, or aborted resolutions leave standing unchanged. Existing Credits, Heat, Mara favor, unlock, message, and ticker consequences continue to apply exactly as authored. A player can therefore finish the portfolio with different money, Heat, favor, and work availability without falling below a prior standing tier.

## Data and state

Add `data/contacts/contact_catalog.gd` as the authored source for the two Contact IDs, display labels, starting tiers, and tier-label conversion. Mutable `contact_standing` lives in `GameState`, keyed by Contact ID.

Every contract definition gains:

- `contact_id: StringName`
- `minimum_contact_standing: int`

A resolution choice may gain:

- `contact_standing_delta: int`, constrained to `0` or `1`

`GameState` owns:

- `contacts_changed` signal;
- standing lookup and display helpers;
- the authoritative published-and-standing availability check used by both panel presentation and `accept_contract()`;
- capped, one-way standing adjustment after a valid resolution.

The main scene refreshes the active Contracts panel on `contracts_changed` and refreshes the active COMMS panel on `contacts_changed`. COMMS receives the contacts and messages snapshot supplied by `GameState`; it does not mutate state.

## Persistence and migration

The profile becomes version 2 and saves `contact_standing` after every successful standing-changing resolution, through the existing atomic temporary-file-and-backup flow.

A version-1 save must migrate rather than reset:

1. Rebuild its contract list from the seven-contract authored catalog.
2. Copy only mutable state (`is_playable`, `status`, `phase`, `resolution_id`) from matching saved contract IDs.
3. Preserve the original active contract ID, Credits, clock, Heat, messages, favor, workspace state, and housing data.
4. Initialize Mara to `KNOWN`.
5. Initialize Vesper Clinic to `KNOWN` only if `Clinic Asset Recovery` was completed in the version-1 profile; otherwise initialize it to `COLD`.
6. Set version 2, then run normal profile validation.

New version-2 profiles must contain exactly the authored Contact IDs with integer tiers in `[0, 2]`. Unknown, missing, malformed, or out-of-range contact state remains invalid and falls back through the existing safe clean-profile path.

## Scope boundaries

- No faction matrix, global morality score, negative-standing state, recovery contracts, crew, market, map, generated jobs, contract editor, or event-graph engine.
- No real-time clock, deadlines expiring, procedural calendar, economy simulation, or Contact-specific terminal module.
- No save slots or settings work. The existing single-profile persistence remains the storage model.

## Acceptance criteria

1. Fresh state displays Mara as `KNOWN` and Vesper Clinic as `COLD` in COMMS.
2. The Contracts panel distinguishes unpublished work from published work gated by insufficient standing.
3. `accept_contract()` rejects a published contract below its standing requirement, even if a caller bypasses the panel.
4. A qualifying resolution raises only that contract's Contact by one capped tier; every other resolution leaves standing unchanged.
5. Standing never decreases, and all portfolio publisher contracts publish their successors for both successful and aborted outcomes.
6. The seven-contract catalog follows the specified publication and standing requirements.
7. New version-2 saves round-trip contact standing with the existing profile state.
8. A valid version-1 save migrates its existing state and matching contract progress into version 2 without reset, and gains the four authored contracts.
9. The current full test suite passes with new focused contract, UI, and persistence coverage.
