## ADDED Requirements

### Requirement: The connected app reads the viewer's ESI call log

Authenticated app reads SHALL use the existing privacy-scoped data-access interface. The server SHALL derive the viewer, current ownership and admin grant from validated server identity. Individual reads SHALL offer bounded newest-first pages. Only an admin SHALL receive the existing fixed-window route aggregates. The client SHALL discard results when the viewer or server changes.

#### Scenario: A member pages through their own calls

- **WHEN** a signed-in member who made a scoped ESI call opens their call history and requests an older page
- **THEN** the app displays only that viewer's rows, at most 100 per response, without handing the caller a filter for another member or character

#### Scenario: An admin reads both views

- **WHEN** a signed-in admin opens the individual and aggregate views
- **THEN** the individual view contains only that admin's own rows, and the other view contains only the allowed fixed-window route totals and error counts

#### Scenario: An anonymous or forged viewer requests data

- **WHEN** a caller lacks an authenticated viewer, tries to choose another viewer, or requests aggregates without admin scope
- **THEN** no protected data is returned, and a cursor copied from another viewer cannot expose that viewer's rows

#### Scenario: A reply arrives after sign-out or server change

- **WHEN** an earlier call-log request completes after the connected identity or server has changed
- **THEN** the app discards that answer and does not show the old viewer's data

#### Scenario: Log reads reach the server work limit

- **WHEN** a viewer opens another log read while their first is still running, or a read cannot get a server work slot
- **THEN** it returns a fixed busy result without sending additional database work or returning another viewer's page

#### Scenario: Admins read the same released window

- **WHEN** two authorized readers request route totals for one released window before the next window opens
- **THEN** they receive the same counts and only one successful aggregation is needed for that window

