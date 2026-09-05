# Project Context — Untitled Cyberpunk Operator RPG

**Status:** Early playable prototype
**Engine:** Godot
**Game type:** 2D, UI-heavy, single-player management / narrative RPG
**Primary platform:** Desktop first
**Setting:** Dark dystopian cyberpunk / sci-fi with interplanetary and eventually interstellar scope

## High-level concept

The player is an independent operator trying to build a life and eventually an organization inside a dystopian corporate society. The game should support different play styles rather than forcing a fixed class: legitimate trader, smuggler, bounty hunter, mercenary contractor, corporate fixer, criminal middleman, or a mixture.

The game is not primarily a spaceship game. It can begin locally inside a city, colony, industrial zone, orbital port, or similar environment. Off-world travel and owning a ship should be meaningful progression milestones, not assumptions made at character creation.

## Core fantasy

> Start small, build contacts and reputation, accept increasingly consequential work, assemble people and resources around you, and decide how personally involved you want to be in the operations you create.

The player may eventually act as:

- a hands-on captain / operative;
- a manager who stays behind a terminal and delegates;
- or something between those extremes.

This should remain a player choice rather than a mandatory role.

## Core gameplay direction

The current intended loop is:

1. Discover opportunities.
2. Evaluate clients, risk, legality, rewards, factions, and requirements.
3. Prepare the contract: crew, equipment, money, route, cover story, intel, etc.
4. Execute through an interactive event sequence.
5. React to complications using dialogue and meaningful choices.
6. Resolve consequences rather than only success/failure.
7. Gain or lose credits, reputation, contacts, injuries, heat, items, favors, enemies, and future opportunities.
8. Upgrade the player's capabilities and expand into larger jobs and locations.

## Contract execution

Contracts should not normally become action-game missions. The preferred model is an **interactive event sequence**.

Example complication:

> Corporate security stops the player or their crew and demands an inspection.

Possible responses can depend on context:

- comply;
- present forged documents;
- bribe the officer;
- rely on a crew member's background or contact;
- attempt deception;
- run;
- escalate to violence;
- abort the contract.

Choices should have consequences. A contract can succeed with a wounded crew member, damaged reputation, lost cargo, a new contact, new enemy, debt, wanted status, or a discovered story thread.

## Reputation and factions

Do not use one global morality meter.

Use multiple competing factions and organizations. Possible groups include:

- megacorporations;
- government / security organizations;
- crime syndicates and gangs;
- independent colonies or districts;
- mercenary networks;
- industrial / labor groups;
- other setting-specific factions introduced later.

Reputation should primarily unlock or close content, contacts, prices, services, dialogue options, trust, and contract tiers.

## Character creation and backgrounds

Background and current role are separate.

A background describes where the player came from. It should influence:

- starting location or district;
- starting resources;
- initial contacts;
- mentor / relative / friend relationship;
- unique dialogue options;
- knowledge checks;
- reputation biases;
- a small number of opening contracts or events;
- occasional advantages and disadvantages later in the game.

Current candidate backgrounds:

- Corporate
- Military / Security
- Street / Slums
- Industrial / Mining
- Spacer / Pilot

These are working concepts, not final names.

Avoid making backgrounds into rigid classes or simple passive bonuses.

## Starting structure

Do not build five separate campaigns.

Preferred scope:

- roughly 5 backgrounds;
- roughly 3 shared starting districts / locations;
- some backgrounds may share locations;
- each background gets a distinct introduction and mentor/contact;
- each background gets around 2–3 unique opening events/contracts;
- paths converge into the broader sandbox after the opening;
- background-specific dialogue and opportunities continue throughout the game.

The opening should be local and personal. The player should not necessarily own a ship.

Possible progression:

Character creation → origin → mentor → local jobs → contacts → reputation → larger city/planetary jobs → off-world travel → ship access / leasing / ownership → wider operations.

## Mentor / tutorial character

Each player should have an important person who helps introduce the world and mechanics. This may be a mentor, relative, former colleague, fixer, squad leader, older sibling, etc.

This character should:

- introduce systems naturally through dialogue and jobs;
- provide the player's first useful contacts;
- have opinions and personality;
- react to some player choices;
- occasionally ask the player for help;
- remain relevant beyond the tutorial;
- potentially become involved in larger story events later.

They should feel like a real character, not a tutorial UI mascot.

## Player role and organization

Do not assume the player is always physically present on a job.

Early game may make personal involvement economically attractive because hiring specialists is expensive. Later, the player may choose to hire captains, pilots, operatives, engineers, security staff, etc.

The architecture should leave room for eventual delegation and possibly multiple concurrent operations, but **do not build multiple-ship management for the initial prototype**.

## World tone and art direction

Keywords:

- dark dystopian cyberpunk;
- Blade Runner-like atmosphere without copying specific IP;
- corporate oppression;
- neon, rain, industrial decay, brutalist megastructures;
- orbital infrastructure;
- mining colonies;
- worn technology;
- cybernetics;
- morally ambiguous work;
- interplanetary / interstellar society;
- strong UI / terminal presentation.

The world does not need to be Earth.

## UX / UI direction

This should be a UI-first Godot game. Likely major screens eventually include:

- home / operations terminal;
- contract board;
- contract detail;
- contacts / messages;
- crew roster;
- player profile / background;
- inventory / equipment;
- market / trade;
- faction / reputation view;
- location / travel map;
- contract execution event screen;
- ship management later, when relevant.

The UI should feel like an in-world operations system rather than a generic management dashboard.

## Godot implementation principles

When implementation begins:

- Use Godot Control-based UI heavily.
- Keep game content data-driven.
- Avoid hard-coding contracts, factions, backgrounds, dialogue, and events directly into UI scenes.
- Prefer Resources or another clean data model for content definitions.
- Keep simulation/game state separate from presentation scenes.
- Use reusable UI components for cards, dialogs, list rows, choices, status indicators, etc.
- Design systems so a coding agent can safely modify isolated parts without touching large monolithic scripts.
- Prefer small scenes/scripts with clear responsibilities.
- The Godot MCP can be used by the coding agent once implementation is approved.

## Prototype philosophy

Do not start by building a giant galaxy.

A good first playable slice could eventually contain something like:

- 1 main starting location;
- 2–3 districts;
- 2 backgrounds initially implemented;
- 1 mentor per implemented background;
- 3 factions;
- a small contract board;
- 8–12 contracts;
- several reusable event types;
- simple reputation;
- basic credits / inventory;
- one crew/companion system;
- no mandatory ship ownership.

The game should prove that **choosing and executing contracts is fun** before expanding the world.

## Important design pillars

1. **Player agency over passive progression.**
2. **Plans should produce tension because complications can change them.**
3. **Consequences should be richer than success/failure.**
4. **Different careers should emerge from player behavior rather than fixed classes.**
5. **Reputation should unlock content, not merely provide percentage bonuses.**
6. **Background should remain relevant after the tutorial.**
7. **The ship is progression/content, not the identity of the whole game.**
8. **UI is the primary gameplay surface, not a layer wrapped around an action game.**

## Current prototype vocabulary

- **Contact:** a named source of authored opportunities and messages. The initial progression slice has Mara and the Vesper Clinic Coordinator.
- **Contact standing:** one-way progress with one Contact, displayed as **COLD**, **KNOWN**, or **TRUSTED**. It gates authored contracts; a resolution can raise standing but this slice never lowers it.
- **Favor:** a discrete debt owed to Mara. It is separate from Contact standing and can unlock or alter a specific resolution.
- **Contract:** an authored operation with one Contact, a minimum Contact-standing requirement, and a fixed event-sequence resolution. It is not a generated mission.
- **Deadline:** a persistent absolute game-time cutoff assigned when a contract is first published. Acceptance and reload do not renew it.
- **Deadline miss:** an unaccepted published offer becomes `expired`; an active job becomes `failed`. Both use the `deadline_missed` runtime outcome.
- **Preparation:** an optional contract purchase shown on the ready screen of Cold-Chain Delivery and Data Retrieval. A one-time upfront payment unlocks an additional response without replacing basic options or advancing time; preparation can trade Credits for a quiet, trust-earning route without creating a new favor debt. Spending is saved, is not refunded on abort or deadline failure, and is included in the contract's net result. Other contracts have no preparation purchase; faction reputation remains deferred.

## Open design questions

These are intentionally unresolved and should not be hard-coded yet:

- exact backgrounds and their names;
- exact starting city/planet/colony;
- whether all backgrounds share one mentor framework or unique named mentors;
- character attributes and skills;
- crew stats and progression;
- economy depth;
- travel model;
- combat abstraction;
- ship ownership and ship mechanics;
- death / injury rules;
- how many factions exist in the full game;
- procedural vs authored contracts;
- main narrative structure;
- exact visual style and UI layout.

## Current implementation boundary

The implemented prototype contains:

- an in-world terminal shell and boot sequence;
- persistent single-profile state for credits, Heat, clock, housing, contract progress, and Contact standing;
- Studio and Loft apartment environments with time-reactive lighting, localized rain, subtle glints, lamp glow, and diffuse window-originated lightning;
- seven deterministic authored contracts across Mara and the Vesper Clinic Coordinator, gated by Contact-local standing and resolved through interactive event sequences;
- publication-relative contract deadlines: unaccepted offers expire and active jobs fail at their persistent cutoff; deadline outcomes publish the same successors as an abort without rewards or changes to Heat, standing, or favors;
- optional contract preparation on Cold-Chain Delivery and Data Retrieval: a one-time upfront payment unlocks an additional response without replacing basic options or advancing time; preparation can trade Credits for a quiet, trust-earning route without creating a new favor debt; spending is saved, is not refunded on abort or deadline failure, and is included in the contract's net result; other contracts have no preparation purchase and faction reputation remains deferred;
- a small housing loop: rest, rent, moving to the Loft, and Studio buyout.

It intentionally does not contain combat, crew, inventory, market, map/travel, procedural contracts, a faction matrix, save slots, or simulation systems. New work should extend one proven player-facing loop rather than introduce a broad subsystem.
