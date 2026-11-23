# Spec Delta

## MODIFIED Requirements

### Requirement: Failed downloads keep the old bundle and retry
A download that fails (a 503 included), or a bundle a reader refuses, SHALL leave the bundle in use unchanged. The app SHALL retry after 1 minute, doubling to at most 30 minutes, and at once only when the stream announces another bundle or the user asks to download now; a reconnect announcing the same bundle SHALL NOT bypass the wait.

#### Scenario: Network error
- **WHEN** downloading build N+1's bundle fails with a network error while build N's is in use
- **THEN** build N's bundle stays in use and the download is retried 1 minute later

#### Scenario: Same bundle from a restarted server
- **WHEN** build N+1's bundle is downloading or waiting out a backoff, and the server restarts and announces build N+1's bundle under a new epoch
- **THEN** the running transfer goes on, or the backoff wait is kept

#### Scenario: Reconnect during backoff
- **WHEN** a download failed 20 seconds ago and the stream reconnects announcing the same bundle
- **THEN** no download starts until the 1-minute wait has passed

#### Scenario: Hash mismatch
- **WHEN** the app holds and has saved build N's bundle, and the downloaded bytes of build N+1 do not match the announced SHA-256
- **THEN** the bytes are discarded, build N's bundle stays in use and kept, an offline restart loads build N's bundle, and a retry is scheduled

#### Scenario: Download now during backoff
- **WHEN** a download of build N+1's bundle failed 20 seconds ago and the user asks to download now
- **THEN** one download of build N+1's bundle starts at once, and if it fails again the next wait is 2 minutes

#### Scenario: Download now with nothing to fetch
- **WHEN** the app already uses the announced bundle, or no bundle is announced, or a download is running, and the user asks to download now
- **THEN** no download starts
