# MATLAB ↔ Unity Communication Protocol

Version 1.0

This document is the contract between the MATLAB server and the Unity client.
If a change affects the wire format, update this file, `MATLAB/Communication/+cmr/+net/Protocol.m`
and `Unity/CleanMyRoom/Assets/Scripts/Net/ProtocolConstants.cs` in the same change.

## 1. Roles and transport

- **MATLAB is the TCP server.** It listens before Unity starts and owns all
  gameplay decisions.
- **Unity is the TCP client.** It connects, sends requests, displays results and
  never validates answers or awards stars.
- Transport is a plain TCP socket on `127.0.0.1:55001` by default.
- Payload is UTF-8 JSON.
- Framing is **one JSON object per line**, terminated by a single LF (`0x0A`).
  CRLF (`0x0D 0x0A`) is accepted from clients.
- There is no TLS, authentication or encryption. The protocol is intended for
  a local, single-player setup.

### Configuration

| Setting | MATLAB | Unity |
|---|---|---|
| Host | `startServer('Host', ...)` default `127.0.0.1` | `NetworkManager.host` default `127.0.0.1` |
| Port | `startServer('Port', ...)` default `55001` | `NetworkManager.port` default `55001` |
| Socket timeout | `Protocol.DefaultTimeout` = 30 s | connect timeout 4 s |
| Maximum message size | `Protocol.MaxMessageBytes` = 65536 | `ProtocolConstants.MaxMessageBytes` = 65536 |
| Reconnect delay | n/a (server stays listening) | `NetworkManager.reconnectSeconds` default 2 s |
| Heartbeat | n/a | `heartbeatIntervalSeconds` = 5 s, `heartbeatTimeoutSeconds` = 8 s |

The value `1.0` is carried by `Protocol.Version` / `ProtocolConstants.Version`.
It is documentation metadata only; it is not currently a wire field.

## 2. Framing rules

TCP is a byte stream, so write boundaries are not preserved. Both sides must
treat the connection as a stream of bytes and split it on LF.

Rules:

1. A message is complete only when an LF byte has been received.
2. A single read may contain a partial message, one message, or several
   messages. The receiver buffers bytes until LF and then dispatches each line.
3. An empty line (just LF) is ignored by Unity. MATLAB answers a
   whitespace-only line with `INVALID_JSON`, so clients must not send blank
   lines.
4. The CR of a CRLF pair is stripped before JSON decoding.
5. A message larger than 65536 bytes is rejected. MATLAB answers
   `MESSAGE_TOO_LARGE`; Unity drops the oversized message and reports a
   protocol error.
6. If more than 65536 bytes arrive without a delimiter, the buffer is reset so a
   malformed sender cannot grow memory without bound.

## 3. Coordinates

Placement positions use **normalized activity-canvas coordinates**:

- `x` and `y` are floating point numbers in `[0, 1]`.
- The origin `(0, 0)` is the **top-left** corner of the activity canvas.
- `x` grows to the right; `y` grows downward.
- Values are relative to the canvas, so they are independent of screen
  resolution, window size and aspect ratio.
- Unity converts pointer coordinates to this space before sending.
- MATLAB may use the position for feedback or hit testing, but a placement is
  only "correct" when `targetId` matches the activity definition.

`position` must contain finite numeric `x` and `y`. Missing, non-numeric or
non-finite values are rejected with `INVALID_REQUEST`.

## 4. Message catalogue

All messages are JSON objects. Every client request carries a unique
`requestId` string; the server echoes it in every response that belongs to that
request. The server ignores a repeated `requestId` (it sends no second reply),
which makes accidental retries harmless.

### 4.1 `PING` → `PONG`

Liveness check. Unity sends this on a heartbeat and on demand.

Request:

```json
{"type":"PING","requestId":"req_000001"}
```

Response:

```json
{"type":"PONG","requestId":"req_000001","status":"CONNECTED"}
```

`status` is currently always `"CONNECTED"`.

### 4.2 `PLACE_REQ`

Sent when the player drops an object onto a target.

```json
{
  "type": "PLACE_REQ",
  "requestId": "req_000002",
  "activity": "COLOR",
  "objectId": "object_01",
  "targetId": "basket_red",
  "position": { "x": 0.45, "y": 0.62 }
}
```

| Field | Type | Required | Meaning |
|---|---|---|---|
| `type` | string | yes | `"PLACE_REQ"` |
| `requestId` | string | yes | Unique id for correlation |
| `activity` | string | yes | Activity id known to MATLAB, e.g. `"COLOR"` |
| `objectId` | string | yes | Id of the dragged object |
| `targetId` | string | yes | Id of the drop target |
| `position` | object | yes | Normalized canvas point `{x, y}` |

A valid request produces **two** replies, in this order:

`PLACE_RES` — what happened to this single placement:

```json
{
  "type": "PLACE_RES",
  "requestId": "req_000002",
  "activity": "COLOR",
  "valid": true,
  "correct": true,
  "position": { "x": 0.45, "y": 0.62 },
  "score": 1,
  "message": "Correct placement"
}
```

`ACTIVITY_RESULT` — result for the activity as a whole:

```json
{
  "type": "ACTIVITY_RESULT",
  "requestId": "req_000002",
  "activity": "COLOR",
  "correct": true,
  "completed": false,
  "stars": 0,
  "message": "Correct placement"
}
```

Field semantics:

- `PLACE_RES.valid` is true when the object and target exist in the activity
  definition. It is always true on a successful reply; validation failures use
  `ERROR` instead.
- `PLACE_RES.correct` is MATLAB's authoritative judgement for this placement.
- `PLACE_RES.score` is the number of **distinct correctly placed objects** in
  the activity so far. It is not the star count.
- `ACTIVITY_RESULT.completed` is true only on the placement that finishes the
  activity.
- `ACTIVITY_RESULT.stars` is the **total stars earned so far** in the session.
  It is sent on every successful placement, not only on completion.
- `message` is human-readable text for display. Unity must not parse it to make
  gameplay decisions.

When the placement completes an activity, the server also sends
`GAME_PROGRESS` immediately after `ACTIVITY_RESULT` (see 4.3).

### 4.3 `GAME_PROGRESS`

Sent by MATLAB after an activity is completed, and only then.

```json
{
  "type": "GAME_PROGRESS",
  "stars": 1,
  "completedActivities": ["COLOR"],
  "gameCompleted": false
}
```

| Field | Type | Meaning |
|---|---|---|
| `stars` | integer | Total stars earned so far |
| `completedActivities` | array of strings | Completed activity ids; **always** a JSON array |
| `gameCompleted` | boolean | True once all configured activities are complete |

`completedActivities` is always an array, including when empty (`[]`) and when
it contains one element (`["COLOR"]`). MATLAB serializes it with `cellstr` at
the wire boundary because `jsonencode` would otherwise encode a scalar string
as a JSON string, and Unity's `string[]` field would stay `null`. This is
covered by regression tests on both sides.

`GAME_PROGRESS` is not a reply to a specific request and has no `requestId`.
The preceding `ACTIVITY_RESULT.requestId` identifies the triggering request.

### 4.4 `ERROR`

Sent by MATLAB when a request cannot be processed. `requestId` is echoed when
the server could read one; otherwise it is `""`.

```json
{
  "type": "ERROR",
  "requestId": "req_000003",
  "code": "UNKNOWN_ACTIVITY",
  "message": "Unknown activity 'MISSING'."
}
```

| `code` | When it is sent |
|---|---|
| `INVALID_JSON` | The line is not valid JSON, is empty or is whitespace-only |
| `INVALID_REQUEST` | Top-level value is not an object, `type` is missing/invalid, a required field is missing, or `position` is invalid |
| `UNSUPPORTED_TYPE` | `type` is not `PING` or `PLACE_REQ` (for example the retired `HAND`) |
| `UNKNOWN_ACTIVITY` | `activity` is not registered |
| `UNKNOWN_OBJECT` | `objectId` is not part of the activity |
| `UNKNOWN_TARGET` | `targetId` is not one of the activity's targets |
| `MESSAGE_TOO_LARGE` | The line or the un-delimited buffer exceeds the size limit |
| `INTERNAL_ERROR` | An unexpected server-side failure was caught |

Error replies replace the normal success replies. For example, an
`UNKNOWN_OBJECT` placement produces one `ERROR` and no `PLACE_RES` or
`ACTIVITY_RESULT`.

## 5. Activity definitions

Activity content is owned by MATLAB and loaded from JSON files in the data
directory (`Shared_Data/ActivityData` by default, or the `DataDirectory` passed
to `startServer`).

```json
{
  "id": "COLOR",
  "title": "Color Sorting",
  "objects": [
    { "id": "object_01", "target": "basket_red" },
    { "id": "object_02", "target": "basket_blue" }
  ],
  "targets": ["basket_red", "basket_blue", "basket_green"]
}
```

- `id` must be non-empty.
- `objects` must be a non-empty array; object ids must be unique.
- Every object's `target` must appear in `targets`.
- `targets` must be non-empty with no duplicates.
- A malformed file is skipped with a warning; it does not stop the server.

Unity receives only what it needs to display and request actions. It never
receives the object-to-target mapping and cannot validate locally.

## 6. Typical flows

### Connect and heartbeat

1. MATLAB starts `tcpserver` and waits.
2. Unity starts, connects on a background thread.
3. `NetworkManager` marks activities enabled only after the state becomes
   `Connected`.
4. Every 5 seconds Unity sends `PING`. If no `PONG` arrives within 8 seconds,
   the client closes the socket and reconnects.
5. Any `PONG` with the pending heartbeat `requestId` clears the timeout.

### Place an object

1. Player drops an object in Unity.
2. Unity converts the pointer position to normalized canvas coordinates and
   sends `PLACE_REQ`.
3. MATLAB validates against the activity definition.
4. MATLAB replies `PLACE_RES` then `ACTIVITY_RESULT`.
5. If the activity is now complete, MATLAB sends `GAME_PROGRESS`.
6. Unity renders feedback and stars from these messages only.

### Complete the game

After the third activity completes, `GAME_PROGRESS` has `gameCompleted: true`
and `stars` equal to the configured activity count. Unity shows the ending; it
does not compute completion itself.

## 7. Disconnect and reconnection

**Unity**

- The client keeps running when MATLAB is unavailable.
- The status overlay shows `MATLAB: DISCONNECTED` (or `CONNECTING`) and
  `Activities: disabled (waiting for MATLAB)`.
- `NetworkManager.ActivitiesEnabled` is false while disconnected. Activity code
  must check it and must not fall back to local validation.
- Reconnection is automatic every `reconnectSeconds` (default 2 s).
- The partial-message buffer is reset on disconnect so bytes from the old
  connection cannot corrupt the new one.
- Requests that were in flight when the connection dropped are not retried
  automatically. The caller may resend with a new `requestId`.

**MATLAB**

- A client disconnect does not stop the server; it keeps listening and accepts
  a new connection.
- Game progress is kept in the `cmr.game.Session` object and survives a client
  reconnect. Restarting `startServer` creates a fresh session.
- Request de-duplication memory is bounded (512 ids).

## 8. Threading (Unity)

- Socket connect, receive and send run on background threads.
- Unity API calls and all public events (`ConnectionChanged`, `MessageReceived`)
  are delivered on the main thread from `NetworkManager.Update()` via
  `MatlabClient.Tick()`.
- Game code should subscribe to events rather than poll sockets.

## 9. Running the server

From the repository root:

```matlab
cd('MATLAB')
server = startServer();          % blocks; press Ctrl+C to stop
```

Choose a data folder or port explicitly:

```matlab
server = startServer( ...
    'Host', '127.0.0.1', ...
    'Port', 55001, ...
    'DataDirectory', fullfile(pwd, '..', 'Shared_Data', 'ActivityData'), ...
    'TotalActivities', 3, ...
    'Verbose', true);
server.run(Inf);
server.stop();
```

For the protocol fixture, point the server at `MATLAB/Tests/fixtures`:

```matlab
server = startServer( ...
    'Port', 55001, ...
    'DataDirectory', fullfile(pwd, 'Tests', 'fixtures'), ...
    'TotalActivities', 3, ...
    'Verbose', true);
server.run(600);
server.stop();
```

## 10. Unity integration points

`NetworkManager` (namespace `CleanMyRoom.Net`) creates itself after the first
scene loads if no instance exists, so no scene setup is required for the
protocol layer.

| Member | Use |
|---|---|
| `NetworkManager.Instance` | Singleton access |
| `State` / `IsConnected` / `ActivitiesEnabled` | Gate activities |
| `Endpoint` / `LastError` | Status display and diagnostics |
| `ConnectionChanged` | React to connect/disconnect |
| `MessageReceived` | Receive `PLACE_RES`, `ACTIVITY_RESULT`, `GAME_PROGRESS`, `ERROR` |
| `SendPlaceRequest(...)` | Send a placement; returns `requestId` or `null` |
| `SendPing()` | Manual liveness check |

`ConnectionStatusHud` draws the always-on status overlay with IMGUI and also
creates itself automatically.

## 11. Tests

### MATLAB

```powershell
& "<MATLAB>\bin\matlab.exe" -batch "cd('<repo>\MATLAB\Tests'); runAllTests"
```

The suite covers codec encoding/decoding, validation, session scoring, framing,
partial packets, multiple messages per read, invalid JSON, unsupported types,
duplicates, disconnect/reconnect and the `completedActivities` array regression.
`runAllTests` throws if any test fails, so the process exit code is meaningful.

### Unity EditMode

Open **Window → General → Test Runner**, select EditMode, or:

```powershell
& "<Unity>\Editor\Unity.exe" -batchmode -nographics `
  -projectPath "<repo>\Unity\CleanMyRoom" `
  -runTests -testPlatform EditMode `
  -testResults "<temp>\editmode-results.xml" `
  -logFile "<temp>\editmode.log"
```

`MessageFramerTests` and `JsonCodecTests` need no server.

### Unity ↔ MATLAB integration

1. Start the MATLAB server on port 55001 with the fixture directory (section 9).
2. Run the explicit EditMode test:

```powershell
& "<Unity>\Editor\Unity.exe" -batchmode -nographics `
  -projectPath "<repo>\Unity\CleanMyRoom" `
  -runTests -testPlatform EditMode `
  -testFilter CleanMyRoom.Tests.NetworkIntegrationTests `
  -testResults "<temp>\integration-results.xml" `
  -logFile "<temp>\integration.log"
```

The test connects, pings, places both fixture objects, checks
`PLACE_RES`/`ACTIVITY_RESULT`/`GAME_PROGRESS`, verifies invalid JSON and the
retired `HAND` type are rejected, forces a disconnect and confirms the client
reconnects and answers a new ping.

## 12. Out of scope

The following are deliberately not part of this protocol:

- Camera, webcam, hand tracking, gesture recognition and any `HAND` message.
- Python or any non-MATLAB validation service.
- Unity-side answer checking, scoring or star awards.
- Authentication, encryption and multi-client sessions.

Sending a retired or unknown type such as `HAND` produces `UNSUPPORTED_TYPE`.
