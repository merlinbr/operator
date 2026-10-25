# Operator — Feature Recommendations

High-leverage feature concepts designed for *Operator*'s UI-first, narrative-event terminal architecture without requiring action engines or asset bloat.

---

## 1. Preparation Phase (Loadouts & Disposable Assets)
*Bridges the gap between Contract Acceptance and Execution (Step 3 of the core loop).*

- **Mechanic:** After accepting a contract, the player can optionally slot 1–2 hardware tools or digital exploits before hitting `Proceed`.
- **Asset Catalog (`data/assets/`):**
  - *Forged Credentials:* Automatically bypasses security/customs checks without taking Heat.
  - *Signal Scrambler:* Prevents surveillance audits during extraction.
  - *Cryo-Stabilizer:* Guarantees cold-chain cargo integrity across transit delays.
  - *Burner Transponder:* Scrambles vehicle/drone traces upon mission completion.
- **Contract Impact:** Complications dynamically surface new resolution choices when matching assets are slotted, allowing clean exits without relying on Contact Favors or Heat spikes.

---

## 2. Specialist Roster (Personal Execution vs. Delegation)
*Delivers on the core design pillar: choose between hands-on operator and desk manager.*

- **Mechanic:** A dedicated `Roster` panel on the icon rail allows hiring specialized subcontractors discovered via contacts.
- **Archetypes:**
  - *Infiltrator:* Counters physical locks and checkpoint complications.
  - *Netrunner:* Counters data audits and ICE countermeasures.
  - *Courier / Driver:* Eliminates transit delays and bypasses dock security.
- **Operation Choice:**
  - **Execute Personally:** Keep 100% of payout; absorb all Heat and complication consequences.
  - **Delegate to Operative:** Deduct operative cut (30–50%); operative counters their matching complication category. Failed checks risk operative injury, downtime, or legal capture.

---

## 3. Dynamic Heat & District Sweeps
*Transforms Heat from a passive stat check into an active threat cycle.*

- **Mechanic:** Cumulative Heat triggers district-wide escalation states once passing defined thresholds (e.g., Heat $\ge 4$).
- **Consequences:**
  - Corporate sweeps raise bribe costs on dock/transit complications.
  - Heightened surveillance temporarily locks high-risk terminals or increases audit frequency.
  - Potential raid complications at the player's current residence if rent is delinquent while Heat is high.
- **Mitigation Actions (Home Module):**
  - *Go to Ground:* Rest multiple days to shed Heat at the cost of clock progression and rent accrual.
  - *Burn Ident:* Spend credits or call in a contact favor to scrub active surveillance flags.

---

## 4. Dynamic Intel & Market Modifiers (Ticker & Comms Integration)
*Converts ambient world flavor into actionable decision-making.*

- **Mechanic:** Shifting district events broadcast over the `TickerBar` and `CommsPanel`, attaching temporary modifiers to contract categories.
- **Event Examples:**
  - *Dock 17 Labor Strike:* Logistics contracts pay +35% credit bonus, but bypass choices carry double Heat.
  - *Northline Grid Audit:* High-tier data runs lock out until an audit window closes, or require verified tokens.
  - *Clinic Medical Emergency:* Payouts on medical supplies increase, and clinic standing gains are doubled.
- **Player Agency:** Encourages evaluating contracts against current environmental conditions rather than treating the board as a static list.

---

## 5. Terminal & Apartment Hardware Progression
*Deepens progression beyond residence switching while leveraging the layered environment.*

- **Mechanic:** Purchase functional terminal peripherals and living space hardware through the `Home` module.
- **Upgrades:**
  - *Sub-band Radio Rig:* Intercepts encrypted corporate channels, unlocking hidden or time-limited contracts.
  - *Decryption Co-Processor:* Reduces contract transit/proceed time requirements.
  - *Hidden Deck Stash:* Protects stored assets and emergency credit reserves from sweeps.
- **Visual Integration:** Tie upgrades to toggleable shader overlays or localized prop UV coordinates in `scenes/main/environment.gd` (e.g., rack lights, secondary screens, desk clutter).
