# Spec Delta

## MODIFIED Requirements

### Requirement: Every commit is signed off under the DCO
`CONTRIBUTING.md` SHALL require, under the Developer Certificate of Origin 1.1, a `Signed-off-by: Name <email>` line matching the author on every commit, and SHALL include or link its text. Agent instructions SHALL require owner and agent-made commits to write it explicitly in the final trailer block, before the `Co-authored-by` trailer. CONTRIBUTING SHALL state that CI checks every pull request commit's sign-off, exempting only Dependabot's own commits in pull requests it opened.

#### Scenario: Signed commit
- **WHEN** a contributor commits with `git commit -s`
- **THEN** the commit message contains a `Signed-off-by` line matching the author in its final trailer block, as CONTRIBUTING describes

#### Scenario: Agent-made commit
- **WHEN** an agent commits under AGENTS.md's rules
- **THEN** the message's final trailer block has the owner's `Signed-off-by` line before the single `Co-authored-by` trailer, written explicitly rather than through `git commit -s`

#### Scenario: Unsigned commit
- **WHEN** a pull request contains a commit without a matching `Signed-off-by` line
- **THEN** CI's sign-off check fails on the pull request, and CONTRIBUTING tells the contributor to amend or rebase with sign-off and states that such pull requests are not merged

#### Scenario: Sign-off checked locally
- **WHEN** a contributor runs the sign-off check task on their branch with the upstream `main` as its base
- **THEN** it reports the same commits and reasons that CI would for a pull request from that branch, and exits non-zero when any commit fails

#### Scenario: No base given
- **WHEN** the sign-off check task runs without a base
- **THEN** it exits non-zero with a message naming the `--base` option and CONTRIBUTING's sign-off section
