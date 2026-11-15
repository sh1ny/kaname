# 0002. Licence, clean room and EULA boundary

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (D4, D10, 2026-11-13; EULA boundary in AGENTS.md)

## Context
Kaname is public from day one and runs next to the EVE client. It must stay inside CCP's developer licence and EULA, and its code must be its own.

## Decision
- **Licence:** AGPL-3.0, except separately licensed vendored assets (tooling skills, fonts) that keep their own licences and notices.
- **Clean room:** concepts only. No third-party product code, schemas or templates are copied. A pinned, unmodified, credited dependency is use, not copying. Any copied data file needs the owner's approval first and a licence notice. Code from the owner's own projects may be adapted with a provenance note.
- **Non-commercial:** no paid tiers, hosted service, ads or ISK-for-access.
- **EULA boundary:** desktop integration only reads game and chat log files and moves or resizes windows. Never input broadcasting, synthetic input, focus cycling on keys, memory reading, screen capture or OCR of the client, packet inspection, or global keyboard hooks; hotkeys work only while Kaname's window is focused. An architecture test enforces it when desktop extras land.
- CI fails on dependencies whose licences are not AGPL-compatible, and `THIRD_PARTY_NOTICES` lists every bundled dependency. The owner counts the Server Side Public License v1 (SSPL), which is the AGPL-3.0 plus a service clause, as compatible: its extra obligation applies only to offering the SSPL-licensed program itself as a hosted service, and Kaname publishes its full source anyway. The `serverpod` package is accepted on that basis as an unmodified runtime dependency, through an exception pinned to its exact version in `licence-policy.yaml`; each Serverpod version change returns to the owner. (Amended 2026-11-15, change `serverpod-skeleton`.)

## Consequences
- Contributors follow CONTRIBUTING's no-copy rule; reviewers check provenance.
- Some community data must be curated by hand rather than imported.
- **Rejected:** a non-commercial source licence (not open source, GPL-incompatible); input automation features (banned by the EULA).
- **Reversal cost:** high for the licence (needs every contributor's consent); the EULA boundary is not reversible.
