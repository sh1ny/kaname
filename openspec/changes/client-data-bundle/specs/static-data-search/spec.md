# Spec Delta

## Purpose

Defines offline search over the static-data bundle's types and solar systems, and the quick search in the app's top bar that presents it.

## ADDED Requirements

### Requirement: Search matches names case-insensitively, prefixes first
A search SHALL match published types and all solar systems whose English name contains the query, ignoring case and surrounding spaces. Names that start with the query SHALL come before other matches; within each group, results SHALL be in name order. At most 50 results SHALL be returned, with a note when more exist.

#### Scenario: Prefix before substring
- **WHEN** the query is `RIF` and the bundle has the published types `Drifter` and `Rifter`
- **THEN** the results are `Rifter` then `Drifter`

#### Scenario: Unpublished type
- **WHEN** the query matches only an unpublished type
- **THEN** no result is returned

#### Scenario: Many matches
- **WHEN** 300 names contain the query
- **THEN** 50 results are returned and the list says more matches exist

### Requirement: An exact id matches its record
A query that is a whole number SHALL also return the type and the solar system with that id, ahead of name matches, whether or not the type is published.

#### Scenario: Type id
- **WHEN** the query is `587` and type 587 is in the bundle and unpublished
- **THEN** type 587 is the first result, and a query for its name does not return it

#### Scenario: Unknown id
- **WHEN** the query is a number that is no type or solar system id
- **THEN** only name matches are returned, and none when nothing matches

### Requirement: Search works with no network
Search SHALL read only the bundle in memory and SHALL make no network request.

#### Scenario: Offline search
- **WHEN** the app holds a bundle, the network is down and the user searches `Jita`
- **THEN** the solar system Jita is returned and no request is sent

#### Scenario: No bundle
- **WHEN** the app holds no bundle and the user searches
- **THEN** the search shows "Static data not loaded yet" with a localised reason (downloading, no server configured, server unreachable, server has no bundle yet, data refused, or app update needed), no exception text, host or port, and no empty result list

### Requirement: The top bar offers quick search
On windows wider than 1080 logical pixels the top bar SHALL hold an inline search field with a result list below it. On narrower windows it SHALL hold a search button that opens a full-width search with its results, closed by Escape or back. Results SHALL list each match's name and kind, with a type's group or a system's region, and the field and its results SHALL be reachable by keyboard and screen reader, with localised text.

#### Scenario: App update needed while holding a bundle
- **WHEN** the app holds build N's bundle and the stream announces a bundle format the app cannot read
- **THEN** the search shows that an app update is needed and still returns results from build N's bundle

#### Scenario: Keyboard search
- **WHEN** the user focuses the search field by keyboard and types `Rifter`
- **THEN** a result list shows `Rifter` with its group, and the arrow keys move through the results

#### Scenario: Narrow window
- **WHEN** the window is 390 logical pixels wide and the user activates the search button and presses Escape
- **THEN** a full-width search opens with the field focused, and Escape closes it and returns focus to the button

#### Scenario: Empty query
- **WHEN** the search field is empty or holds only spaces
- **THEN** no result list is shown
