# Spec Delta

## Purpose

Gives every part of Kaname that plans or records ESI calls one generated source for each route's rate group and limit, scopes, required roles, cache behaviour and pagination, taken from the pinned spec.

## ADDED Requirements

### Requirement: One catalogue entry per operation
The route catalogue SHALL hold exactly one entry for every operation in the pinned spec, keyed by its operation id. Each entry SHALL give the HTTP method and the path template.

#### Scenario: Complete catalogue
- **WHEN** the catalogue generated from the 2026-11-19 snapshot is read
- **THEN** it has 208 entries, one per operation id in the snapshot, each with the snapshot's method and path template

#### Scenario: Unknown operation id
- **WHEN** a caller looks up an operation id the catalogue does not hold
- **THEN** the lookup returns no entry and raises no error

### Requirement: Lookup by method and path template
The catalogue SHALL find an entry by HTTP method and path template as well as by operation id.

#### Scenario: Found by method and path
- **WHEN** a caller looks up `GET` and `/characters/{character_id}/assets`
- **THEN** it gets that operation's entry

#### Scenario: Method not defined for the path
- **WHEN** a caller looks up `DELETE` and `/characters/{character_id}/assets`
- **THEN** the lookup returns no entry

### Requirement: Rate group per route
Each entry SHALL give the route's rate group, its maximum tokens and its window as the spec states them. A route whose operation has no rate-limit extension SHALL be marked as having no rate group, distinct from any group.

#### Scenario: Route with a rate group
- **WHEN** the entry for `GET /alliances/{alliance_id}/contacts` is read
- **THEN** its rate group is `alliance-social` with 300 tokens over a 15-minute window

#### Scenario: Route without a rate group
- **WHEN** the entry for `GET /alliances` is read
- **THEN** it is marked as having no rate group, and no group name, token count or window is reported for it

### Requirement: Scopes and required roles per route
Each entry SHALL list the SSO scopes its operation requires and the corporation roles the spec says it requires. A public route SHALL list no scopes.

#### Scenario: Scoped route with roles
- **WHEN** the entry for `GET /corporation/{corporation_id}/mining/extractions` is read
- **THEN** it lists the scope `esi-industry.read_corporation_mining.v1` and the role `Station_Manager`

#### Scenario: Public route
- **WHEN** the entry for `GET /alliances` is read
- **THEN** it lists no scopes and no roles, and reports that no authentication is needed

### Requirement: Cache behaviour per route
Each entry SHALL give the cache facts the spec states for its operation: cache mode, server cache mode, server cache TTL, client cache TTL and cache age, each reported as absent when the spec does not state it.

#### Scenario: Route with stated cache facts
- **WHEN** the entry for `GET /alliances` is read
- **THEN** its server cache mode is `ttl-based`, its server cache TTL, client cache TTL and cache age are each 3600 seconds, and its cache mode is absent

#### Scenario: Route with no cache facts
- **WHEN** the entry for `GET /alliances/{alliance_id}/icons`, which states no cache extension in the snapshot, is read
- **THEN** each cache fact is reported as absent, not as zero

### Requirement: Pagination kind per route
Each entry SHALL state the route's pagination kind: none, page-numbered (a `page` query parameter with a page-count header) or cursor (`before` and `after` parameters).

#### Scenario: Page-numbered route
- **WHEN** the entry for `GET /characters/{character_id}/assets` is read
- **THEN** its pagination kind is page-numbered

#### Scenario: Cursor route
- **WHEN** the entry for `GET /corporations/{corporation_id}/freelance-jobs` is read
- **THEN** its pagination kind is cursor

#### Scenario: Unpaginated route
- **WHEN** the entry for `GET /alliances` is read
- **THEN** its pagination kind is none
