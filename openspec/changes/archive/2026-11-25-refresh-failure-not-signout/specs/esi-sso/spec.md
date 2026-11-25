# ESI SSO delta

## ADDED Requirements

### Requirement: An inconclusive viewer refresh preserves the last known holder

When a connected viewer refresh cannot establish the holder state, the app SHALL keep the last verified viewer for the same session and apply the existing desktop holder check to it. An inconclusive reply SHALL neither sign the viewer out nor grant desktop authorization. The viewer route SHALL report a temporary session lookup error as unavailable, not as sign-in required, and SHALL NOT expose the error or a credential.

#### Scenario: The holder check survives a failed refresh

- **GIVEN** the last verified viewer has a holder for the selected desktop character and the desktop has no matching reservation
- **WHEN** a viewer refresh after Take or Return fails or the reply cannot establish the viewer's holder state
- **THEN** the connected viewer and last known holder stay available, and the desktop does not start native skills authorization for that character

#### Scenario: A confirmed viewer update replaces the holder view

- **WHEN** a viewer refresh verifies a new holder state for the current session, including a viewer with no holder assignment
- **THEN** the desktop applies its holder check to the new state instead of the previous one

#### Scenario: A confirmed invalid session ends the connected view

- **WHEN** the viewer route confirms that the current session is no longer valid
- **THEN** the app signs the connected viewer out and no longer uses that session's holder information

#### Scenario: A temporary lookup error is not session invalidation

- **WHEN** the viewer route cannot complete the session lookup because of a temporary error
- **THEN** the route reports unavailability without reporting that sign-in is required or exposing the lookup error or a credential

#### Scenario: Sign-out wins over an in-flight refresh

- **WHEN** the user signs out before a viewer refresh completes
- **THEN** the app clears the connected viewer and the late reply cannot restore it or its holder information
