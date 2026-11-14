# 0005. Run modes and one token holder per character

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (D6 2026-11-13; mobile solo-lite, one holder and reasons 2026-11-14)

## Context
Members use Kaname with or without an org server. A device in solo mode uses Kaname's native (PKCE) ESI application on its own connection; the server uses the install's web application. They are different applications on different connections, so they do not share rate buckets or the error limit. Two pollers for one character still produce two diverging copies of the same data, may write to the game from two places, double the load on CCP for nothing, and leave no single place that shows a character's sync state.

## Decision
- **Three run modes:**

  | Mode | Who | Data | ESI tokens |
  |---|---|---|---|
  | Connected | member of an org server (web, desktop, mobile) | server; app keeps an offline cache (ADR 0006 limits what it may hold) | server |
  | Solo (desktop) | anyone, no server | local store | device (PKCE) |
  | Solo-lite (mobile) | anyone, no server | local store; syncs in the foreground or OS background fetch | device (PKCE) |

  Web has no solo mode.
- **Solo runs every job locally.** It uses the same domain code, sync recipes, job logic, scheduler and governor as the server (ADR 0007, ADR 0009), against the local store, and covers personal modules only. Corp and alliance features are server-only.
- **One token holder per character:**
  - each character has exactly one token holder, the server or one device, and the app shows which;
  - a connected app never calls ESI for a server-held character: it reads from the server, and "refresh now" asks the server to move that job forward;
  - when the server is unreachable, the app shows its cache marked stale and never falls back to calling ESI itself;
  - handing a character to the server parks or revokes the device token; taking it back reverses that.
- **Solo to join:**
  - personal records (fits, plans, notes, alarms, bookmarks) upload;
  - character data (skills, assets, wallets) is re-pulled by the server from ESI, never uploaded;
  - alts can stay solo.
- The local-store technology is chosen at M4 after a spike (strategy R32).

## Consequences
- Domain, ESI, SSO, sync, job and static-data packages stay pure Dart (ADR 0003).
- Writes to the game (waypoints, fits, contacts) for server-held characters go through the server.
- **Rejected:**
  - A connected device also polling ESI: diverging data, game writes from two places, double load on CCP.
  - Mobile always connected: no way to try the app before a server exists.
- **Reversal cost:** high. Sync, token storage and the join flow all assume it.
