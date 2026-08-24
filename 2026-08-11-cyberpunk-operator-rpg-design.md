# Cyberpunk Operator RPG — Early Design Specification

**Date:** 2026-08-11  
**Status:** Draft for design review  
**Engine:** Godot  
**Format:** 2D, UI-heavy single-player management / narrative RPG

## 1. Vision

Create a dark dystopian cyberpunk science-fiction RPG in which the player begins as a small independent operator and gradually builds reputation, contacts, resources, crew, and access to increasingly dangerous opportunities.

The game should support several emergent careers—legitimate trader, smuggler, mercenary, bounty hunter, criminal contractor, corporate fixer—without requiring the player to choose a permanent class.

The game may eventually span planets and star systems, but it should begin at a more personal scale. A ship is not required at the start and should not define the entire experience.

## 2. Player fantasy

The player starts with limited money, limited influence, and a personal history.

They decide:

- which jobs they accept;
- which factions they help or oppose;
- how legal or criminal their operation becomes;
- who they recruit;
- what risks they take;
- whether they personally participate in operations or increasingly delegate them.

The desired fantasy is progression from "small person trying to survive" to "recognized operator whose decisions matter."

## 3. Core loop

**Discover → Evaluate → Prepare → Execute → React → Resolve → Progress**

### Discover
The player receives opportunities through boards, contacts, messages, factions, rumors, and previous consequences.

### Evaluate
Each contract communicates enough information for the player to judge reward, risk, legality, client, destination, time constraints, known threats, and requirements.

### Prepare
The player chooses relevant people, equipment, money, route, cover story, intelligence, cargo arrangements, or other resources.

### Execute
The contract unfolds as an interactive series of events rather than a passive timer or separate action game.

### React
Complications present dialogue and action choices whose availability can depend on background, crew, equipment, contacts, reputation, preparation, and prior decisions.

### Resolve
Outcomes can include partial success, collateral damage, injuries, debt, lost cargo, new information, new contacts, faction changes, heat, wanted status, future story threads, and other consequences.

### Progress
The player improves their economic position, network, capabilities, crew, access, and eventually geographic scope.

## 4. Contract execution model

The chosen direction is **interactive event sequences**.

The player should feel tension after committing to a job because plans may be disrupted.

Example sequence:

1. A contraband delivery begins normally.
2. Security unexpectedly stops the transport.
3. The player chooses whether to comply, deceive, bribe, rely on a contact, flee, escalate, or abort.
4. The result may create a second complication.
5. The contract concludes with consequences broader than success/failure.

This model keeps the project UI-heavy while maintaining meaningful player interaction.

## 5. Background system

Background describes the player's origin, not their permanent role.

Working backgrounds:

- Corporate
- Military / Security
- Street / Slums
- Industrial / Mining
- Spacer / Pilot

Background affects the opening and should remain relevant throughout the game.

Potential effects:

- initial district/location;
- starting resources;
- initial reputation;
- starting contact/mentor;
- dialogue options;
- knowledge-based options;
- occasional disadvantages;
- access to certain early jobs;
- recognition by specific NPCs or organizations.

Avoid simple class-like passive bonuses as the main expression of background.

## 6. Opening structure

Five backgrounds should not require five separate full campaigns.

Preferred production approach:

- approximately five backgrounds;
- approximately three shared starting districts;
- multiple backgrounds may begin in the same district under different circumstances;
- each background receives a unique introduction and relationship context;
- each background receives roughly two or three distinctive opening events or contracts;
- routes converge into the shared sandbox after the opening;
- background-specific options continue appearing later.

The game should initially feel local. The first hours may take place within a city, colony, station complex, or planet rather than immediately across star systems.

## 7. Mentor / relationship character

A mentor, relative, old colleague, fixer, former squad leader, older sibling, or similar relationship helps introduce the player to the world.

The role serves both narrative and tutorial purposes.

Requirements:

- teaches mechanics through believable situations;
- provides initial contacts and opportunities;
- has personality and opinions;
- can approve or disapprove of decisions;
- remains relevant after onboarding;
- can become part of future storylines;
- should not behave like a generic tutorial assistant.

The exact relationship may vary with background.

## 8. Player role: captain vs operator

The player is not permanently forced into either captain or abstract company-owner mode.

Early game economics may encourage personal participation because hiring experienced specialists is expensive.

As the player's operation grows, they may hire people to perform roles they previously filled themselves.

Examples:

- captain;
- pilot;
- engineer;
- security specialist;
- negotiator;
- operative.

Eventually a player may conduct operations almost entirely through terminal communication, while another may remain personally involved.

The first prototype should not require multi-ship management, but architecture should avoid assumptions that make delegation impossible later.

## 9. Factions and reputation

Reputation should be faction-specific rather than a single morality score.

Potential categories:

- corporations;
- government/security;
- syndicates/gangs;
- independent settlements;
- industrial/labor groups;
- mercenary networks.

Reputation affects:

- available clients;
- contract tiers;
- trust;
- access to restricted opportunities;
- market/services access;
- prices where appropriate;
- dialogue;
- willingness to help;
- hostility or scrutiny.

Higher reputation is not universally positive. Helping one group can damage another relationship or expose the player to different risks.

## 10. Setting and tone

The setting is dark dystopian cyberpunk science fiction and does not need to be Earth.

Visual and thematic references should evoke, without copying existing IP:

- neon megacities;
- heavy industry;
- corporate arcologies;
- orbital ports;
- mining colonies;
- worn spacecraft and machinery;
- cybernetics;
- surveillance;
- class inequality;
- morally ambiguous work;
- rain, smoke, darkness, brutalism, holographic interfaces;
- interplanetary civilization.

Different locations should have distinct identities while belonging to the same world.

## 11. UI-first design

The interface is a core part of the game fantasy.

Likely screens:

- operations/home terminal;
- contracts;
- contract details;
- messages/contacts;
- crew;
- player/background profile;
- inventory/equipment;
- market/trading;
- faction/reputation;
- travel/location map;
- interactive contract event view;
- ship systems later.

The UI should resemble an in-world operations interface rather than a generic admin dashboard.

## 12. Godot architectural direction

When implementation begins:

- use Godot Control nodes for most presentation;
- keep UI and game state separated;
- define backgrounds, factions, contracts, events, choices, items, and characters as data-driven content;
- avoid embedding narrative content in scene scripts;
- create reusable components for repeated UI patterns;
- keep scripts/scenes small and focused;
- prefer clear interfaces between systems;
- make the project friendly to iterative work through Godot MCP and a coding agent.

A later implementation plan should define concrete autoloads, resource classes, scene hierarchy, state flow, save format, and content loading approach.

## 13. First vertical slice target

Do not build the galaxy first.

A strong vertical slice should focus on proving contract selection and execution.

Candidate scope:

- one main location;
- two or three districts;
- two implemented backgrounds;
- one mentor/contact per implemented background;
- three factions;
- a small contract board;
- 8–12 authored contracts;
- reusable event/choice logic;
- credits;
- simple inventory/equipment;
- simple reputation;
- at least one recruitable companion or crew member;
- no mandatory ship ownership.

Success criterion: choosing, preparing, and resolving contracts feels engaging even before large-scale progression exists.

## 14. Design pillars

1. Player agency over passive progression.
2. The player makes plans, but complications create uncertainty.
3. Outcomes are richer than binary success/failure.
4. Career identity emerges from behavior rather than a locked class.
5. Reputation unlocks and closes content.
6. Background remains relevant after the opening.
7. The ship is a progression system, not the entire game identity.
8. UI is the main gameplay surface.
9. Start locally and earn access to the wider world.
10. Characters and relationships should create future consequences.

## 15. Explicitly unresolved

Do not treat these as decided:

- final background list/names;
- exact protagonist stats;
- exact crew stat model;
- precise economy;
- precise combat abstraction;
- full travel system;
- ship acquisition and ownership model;
- procedural content;
- death/injury model;
- exact starting city/planet;
- final faction roster;
- main plot;
- detailed UI layout;
- final visual identity;
- save architecture.

## 16. Approval / implementation gate

This is a design draft.

Before scaffolding gameplay systems in Godot, review this specification and resolve any major disagreements. After approval, create a separate implementation plan for the Godot project foundation and first vertical slice.
