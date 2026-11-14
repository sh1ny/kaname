# contribution-policy Specification

## Purpose

States what every contribution to Kaname must satisfy (clean-room provenance, the EULA boundary, DCO sign-off) and how security vulnerabilities are reported privately.

## Requirements

### Requirement: CONTRIBUTING states the no-copy rule
`CONTRIBUTING.md` SHALL state that contributions use concepts only: no third-party product code, schemas or templates are copied; a pinned, unmodified, credited dependency is use, not copying; copying any data file needs the owner's approval first and a licence notice; and code adapted from the owner's own projects carries a provenance note.

#### Scenario: Rule present
- **WHEN** a contributor reads `CONTRIBUTING.md`
- **THEN** it contains a no-copy section that covers code, schemas, templates, data files, dependencies and the provenance note

#### Scenario: A contribution with copied code
- **WHEN** a pull request says it copies code, a schema or a template from another product
- **THEN** CONTRIBUTING names this as grounds to decline it, and the PR template's no-copy item cannot be honestly ticked

### Requirement: CONTRIBUTING states the EULA boundary
`CONTRIBUTING.md` SHALL state that desktop integration only reads game and chat log files and moves or resizes windows, and SHALL list what is never accepted: input broadcasting, synthetic input, focus cycling on keys, memory reading, screen capture or OCR of the client, packet inspection, and global keyboard hooks.

#### Scenario: Boundary present
- **WHEN** a contributor reads `CONTRIBUTING.md`
- **THEN** it lists the two allowed integrations and every forbidden technique named above

#### Scenario: A feature outside the boundary
- **WHEN** a proposed feature needs input automation or reads the client's memory or screen
- **THEN** CONTRIBUTING states it is not accepted, whatever its configuration or default

### Requirement: Every commit is signed off under the DCO
`CONTRIBUTING.md` SHALL require a `Signed-off-by: Name <email>` line matching the commit author on every commit, under the Developer Certificate of Origin 1.1, and SHALL include or link the certificate's text. Agent instructions SHALL require owner and agent-made commits to write it explicitly in the final trailer block, before the `Co-authored-by` trailer.

#### Scenario: Signed commit
- **WHEN** a contributor commits with `git commit -s`
- **THEN** the commit message contains a `Signed-off-by` line matching the author in its final trailer block, as CONTRIBUTING describes

#### Scenario: Agent-made commit
- **WHEN** an agent commits under AGENTS.md's rules
- **THEN** the message's final trailer block has the owner's `Signed-off-by` line before the single `Co-authored-by` trailer, written explicitly rather than through `git commit -s`

#### Scenario: Unsigned commit
- **WHEN** a pull request contains a commit without a matching `Signed-off-by` line
- **THEN** CONTRIBUTING tells the contributor to amend or rebase with sign-off, and states that such pull requests are not merged (an automated check is added with CI in `ci-matrix`)

### Requirement: Pull requests carry a provenance checklist
The repository SHALL provide a pull request template with check items for the no-copy rule, the EULA boundary and DCO sign-off.

#### Scenario: New pull request
- **WHEN** someone opens a pull request on GitHub
- **THEN** its description is pre-filled with the three check items

#### Scenario: Template missing
- **WHEN** the template file is moved or removed
- **THEN** the workspace's file check fails and names the missing template

### Requirement: Vulnerabilities are reported privately
`SECURITY.md` SHALL direct reporters to GitHub's private vulnerability reporting for this repository, SHALL ask them not to open public issues for vulnerabilities, and SHALL state that no version is supported until release 0.1.

#### Scenario: Reporter finds the channel
- **WHEN** a reporter reads `SECURITY.md`
- **THEN** it names GitHub private vulnerability reporting, links to the repository's security advisory page, and publishes no email address

#### Scenario: Private reporting not enabled
- **WHEN** private vulnerability reporting is disabled in the repository settings
- **THEN** the change is not complete: the owner's `[user]` task to enable it stays unticked
