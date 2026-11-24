# esi-client Specification

## Purpose
Defines the typed ESI client generated from the pinned spec: how it builds requests, how it turns responses into typed results, and that it reaches ESI only through a transport injected by its caller.

## Requirements

### Requirement: One typed method per operation
The client SHALL offer one method for every operation in the pinned spec. Each method SHALL take the operation's path, query and body parameters as typed arguments, with required parameters required and optional ones optional.

#### Scenario: Every operation covered
- **WHEN** the client generated from the 2026-11-19 snapshot is compared with the snapshot
- **THEN** it has 208 methods, one per operation id, and each one, called with placeholder arguments, sends the transport a request whose method matches the catalogue entry and whose path equals the snapshot's path template with those arguments filled in

#### Scenario: Cursor value reaches the wire unchanged
- **WHEN** a caller passes the cursor `a+b/c=` as `after` to `GET /corporations/{corporation_id}/freelance-jobs`
- **THEN** the request target the transport receives carries the query `after=a%2Bb%2Fc%3D`, and decoding that query once gives exactly `a+b/c=`

#### Scenario: Required parameter left out
- **WHEN** code calls a method without one of its operation's required parameters
- **THEN** static analysis reports an error and the code does not compile

### Requirement: Requests carry the pinned compatibility date
Every request the client builds SHALL carry the `X-Compatibility-Date` header with the pinned date. The client SHALL build the request target, a relative `Uri`, by percent-encoding each path parameter value and each query parameter value exactly once, and SHALL encode a request body as JSON. The transport SHALL resolve that target against `https://esi.evetech.net` without re-encoding it.

#### Scenario: Request built
- **WHEN** a caller asks for `GET /characters/{character_id}/assets` with character id 90000001 and page 2
- **THEN** the transport receives a GET whose request target is exactly `/characters/90000001/assets?page=2` with `X-Compatibility-Date: 2026-11-19` and no `If-None-Match`, `User-Agent`, `Authorization` or `X-Tenant` header

#### Scenario: Body request
- **WHEN** a caller asks for `POST /universe/names` with ids 1 and 2
- **THEN** the transport receives a POST with a JSON body `[1,2]` and the content type `application/json`

#### Scenario: Body outside the spec's bounds
- **WHEN** a caller passes an empty id list to `POST /universe/names`, whose schema requires at least one item
- **THEN** the client returns an invalid-request result naming the parameter and sends nothing to the transport

### Requirement: Optional and forbidden headers
The client SHALL add `If-None-Match` and `Accept-Language` only when the caller passes them, and SHALL NOT set `User-Agent`, `Authorization` or `X-Tenant`.

#### Scenario: Conditional request
- **WHEN** a caller passes an ETag value for `If-None-Match`
- **THEN** the request carries `If-None-Match` with exactly that value

#### Scenario: Language requested
- **WHEN** a caller passes `de` as the language
- **THEN** the request carries `Accept-Language: de`, and a request built without it carries no `Accept-Language`

### Requirement: The transport is the only way out
The client SHALL send each request only through a transport its caller injects, and SHALL have no network access of its own. The package SHALL have no runtime dependencies. Every import, export, part and conditional-import URI in its `lib/` files, generated ones included, SHALL be one of `dart:core`, `dart:async`, `dart:convert`, `dart:collection`, `dart:math`, `dart:typed_data`, or a URI that resolves inside the package's own `lib/`.

#### Scenario: Fixture transport
- **WHEN** a test injects a transport that answers from a recorded exchange
- **THEN** the client's result is built from that exchange and no network connection is opened

#### Scenario: Disallowed library imported
- **WHEN** a file under the package's `lib/`, generated or hand-written, imports, exports or conditionally imports `dart:html`, `dart:js_interop`, `dart:io` or any other `dart:` library outside the allowed six
- **THEN** the package's tests fail and name the file and the library

#### Scenario: Import leaves the package
- **WHEN** a file under the package's `lib/` imports, exports or conditionally imports another workspace package (such as `package:kaname_core/...`) or a relative path outside `lib/`, with the pubspec unchanged
- **THEN** the package's tests fail and name the file and the URI

#### Scenario: Runtime dependency added
- **WHEN** the package's pubspec lists any runtime dependency
- **THEN** the package's tests fail and name the dependency

#### Scenario: Transport fails
- **WHEN** the transport reports that the request could not be sent
- **THEN** the client returns a transport-failure result carrying that report, and raises no exception

### Requirement: Call identity stays with the transport
The client SHALL send every request through the one transport it was built with, and SHALL put no caller identity, token or priority into a request. Which character's token and budget a call uses, and its priority, SHALL be bound by whoever supplies the transport.

#### Scenario: Two clients, two transports
- **WHEN** two clients built on two different transports make the same call at the same time
- **THEN** each transport receives exactly one request, from its own client

#### Scenario: No identity in requests
- **WHEN** any request the client builds is inspected
- **THEN** it holds no `Authorization` header, token, character id beyond the operation's own parameters, or priority

### Requirement: Typed results, never thrown
Each call SHALL return one result of a closed set: success, not modified, ESI error, malformed response, invalid request or transport failure. The client SHALL NOT throw for any HTTP status or response body.

#### Scenario: Success
- **WHEN** the transport answers 200 with a body that matches the operation's schema and headers `ETag`, `Expires`, `Last-Modified` and `X-Pages: 3`
- **THEN** the result is a success holding the typed body, the status, those header values and a page count of 3

#### Scenario: No content
- **WHEN** an operation whose spec answers 204 gets a 204
- **THEN** the result is a success with no body

#### Scenario: Not modified
- **WHEN** the transport answers 304
- **THEN** the result is not modified, carrying the response's `ETag` and `Expires` when present

#### Scenario: ESI error with body
- **WHEN** the transport answers 404 with `{"error":"Character not found"}`
- **THEN** the result is an ESI error with status 404 and the message `Character not found`

#### Scenario: ESI error without a readable body
- **WHEN** the transport answers 502 with a body that is not JSON
- **THEN** the result is an ESI error with status 502 and no parsed message

### Requirement: Malformed responses are reported
A success status whose body does not match the operation's schema SHALL give a malformed-response result naming the status and the JSON path of the first mismatch. A missing required field, a JSON type that differs from the schema, or a body that is not JSON SHALL each count as a mismatch.

#### Scenario: Conforming body
- **WHEN** a 200 body for `GET /alliances/{alliance_id}` holds every required field with the schema's types
- **THEN** the result is a success, not malformed, and holds those values

#### Scenario: Body that is not JSON
- **WHEN** the transport answers 200 with a body that is not JSON
- **THEN** the result is malformed, with status 200 and the root JSON path

#### Scenario: Missing required field
- **WHEN** a 200 body for `GET /alliances/{alliance_id}` lacks a field the schema requires
- **THEN** the result is malformed, with status 200 and the path of the missing field

#### Scenario: Wrong JSON type
- **WHEN** a 200 body holds a string where the schema has an integer
- **THEN** the result is malformed, with the path of that value

### Requirement: Values the pinned spec does not list
A string where an enum is expected, holding a value the pinned spec does not list, SHALL decode to an explicit unknown case holding that string. A `oneOf` value that is an object with exactly one key, where the key names no listed variant, SHALL decode to an unknown case holding the object. Object fields the schema does not declare SHALL be ignored. None of these SHALL make a response malformed.

#### Scenario: New enum value
- **WHEN** a 200 body holds a notification type the pinned enum does not list
- **THEN** the result is a success and that item's type is the unknown case holding the received string

#### Scenario: New oneOf variant
- **WHEN** a 200 body holds a `oneOf` value whose single key matches none of the listed variants
- **THEN** the result is a success and that value is the unknown case holding the received object

#### Scenario: Extra field
- **WHEN** a 200 body holds an object field the schema does not declare
- **THEN** the result is a success and the declared fields hold their values

#### Scenario: Known variant with a wrong-typed payload
- **WHEN** a 200 body holds a price `{"isk": "1500.5"}`, whose key names a listed variant but whose value is a string
- **THEN** the result is malformed, with the path of that value

#### Scenario: oneOf object without exactly one key
- **WHEN** a 200 body holds a `oneOf` value with no key, or with two keys
- **THEN** the result is malformed, with the path of that value

#### Scenario: Enum position holding a non-string
- **WHEN** a 200 body holds a number where a string enum is expected
- **THEN** the result is malformed, with the path of that value

#### Scenario: Known variant
- **WHEN** a 200 body holds a listed `oneOf` variant, such as a price given as `{"isk": 1500.5}`
- **THEN** the value decodes to that variant with the amount 1500.5

### Requirement: Contract tests over recorded exchanges
The client SHALL be tested against Kaname-written recorded exchanges (status, headers, body) in three sets: conforming, negative (malformed) and forward-compatibility (unlisted values). Each test SHALL assert its exact result case and decoded values or captured request. The exchanges SHALL hold no data copied from ESI.

#### Scenario: Exact assertion
- **WHEN** a forward-compatibility exchange holds an unlisted notification type
- **THEN** its test asserts a success whose item type is the unknown case holding that exact string

### Requirement: Contract coverage
Inbound tests SHALL cover: object, array, scalar array, `oneOf` variant, unknown enum and variant, 204, 304, error body, malformed body and page count. Outbound tests SHALL assert the captured request for a cursor and a request body.

#### Scenario: Every construct covered
- **WHEN** the contract tests run
- **THEN** each listed inbound construct has a test asserting its result case and decoded values, each listed outbound construct has a test asserting the captured request, and every test passes

#### Scenario: Snapshot bump breaks an asserted behaviour
- **WHEN** a date bump changes a schema so that a conforming exchange no longer decodes to the case and values its test asserts (for example, an asserted enum member is removed and the value now decodes as unknown)
- **THEN** the contract test for that exchange fails and names the operation and what differs
