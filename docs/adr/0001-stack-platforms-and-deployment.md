# 0001. Stack, platforms and deployment

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (D1–D3, 2026-11-13; Redis and one instance, 2026-11-14)

## Context
Kaname is a server plus one client on six platforms, built and maintained mostly by agents for one owner. One language end to end keeps domain code shareable between the server, the app and the desktop solo engine. Installs are run by volunteers, so deployment must be simple.

## Decision
- **Server:** Serverpod 4.1 (Dart) with PostgreSQL as the source of truth.
- **Redis is required on every install.** It holds ESI rate-limit state and per-character refresh locks, and backs Serverpod's global (cross-instance) messages.
- **One server instance per install in 1.0.** This is enough for the target of 500 members on 2 vCPU and 4 GB. Running several instances needs a superseding ADR that gives each worker role a single owner, for example a lease.
- **Client:** one Flutter app for web, Windows, Linux, macOS, Android and iOS. Parity and sync first; desktop-only extras later.
- **Deployment:** self-hosted with Docker Compose: `server`, `postgres`, `redis` and `caddy` (TLS and the static web app). No SaaS and no paid tier.
- The toolchain is pinned in `mise.toml`, and the Serverpod CLI is a package-local dev dependency.

## Consequences
- Domain logic that runs on the server, in the app and in the solo engine is pure Dart (ADR 0003).
- Workers and loops need no cross-instance coordination in 1.0 (ADR 0009).
- Windows desktop builds need a Windows machine. CI covers the other targets (roadmap M0).
- **Rejected:**
  - A separate backend language with a generated client: it would split the domain code and lose the shared solo engine.
  - Optional Redis: the budget state and the bus would each need a second design.
  - Several instances in 1.0: worker leases are not needed at the target size.
- **Reversal cost:** very high for the stack; medium for one instance (a later ADR adds leases).
