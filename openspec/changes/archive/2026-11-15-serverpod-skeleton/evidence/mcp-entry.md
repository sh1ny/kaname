# Serverpod MCP entry (task 7.3, design S7, A10)

Linux (WSL Ubuntu), toolchain through mise. The entry is read from
`.mcp.json` (`mcpServers.serverpod`: command `mise`, args
`exec -C server/kaname_server -- dart run serverpod_cli mcp-server --server-dir .`)
and started from the repository root, exactly as a harness starts it. No
Serverpod runner or server was running, and none was started.

A small JSON-RPC client (kept outside the repository, in a scratch folder)
spawned the entry and spoke newline-delimited JSON-RPC over stdio:
`initialize`, `notifications/initialized`, `tools/list`, then `tools/call` of
`tail_server_logs`. Output below is the client's output, with two mechanical
transformations made by the client itself: the repository root path is printed
as `<repo>`, and the `tools/list` reply is reduced to the tool names.

## (a) The bridge starts and names `server/kaname_server`

The `initialize` reply's `instructions` field names the package it serves.

## (b) A tool call with no runner returns the "not running" error

The `tools/call` reply carries `isError: true` and the bridge's
"is not running" text. The bridge started and answered; it did not fail to
start. Its stderr holds only the Dart build-hook notice, and it exited 0 when
the client closed stdin.

```text
$ mise exec -C server/kaname_server -- dart run serverpod_cli mcp-server --server-dir .
>> {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "evidence-client", "version": "0"}}}
<< {"jsonrpc":"2.0","result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":true},"resources":{"listChanged":true,"subscribe":true}},"serverInfo":{"name":"serverpod-bridge","version":"4.1.2"},"instructions":"Manage the Serverpod server in <repo>/server/kaname_server and its Flutter app, running under the Serverpod runner. This bridge serves that server package only, whatever the current directory is. Use these tools to read Serverpod and Flutter logs, create and apply database migrations, hot reload or restart the server and Flutter app, and get the Flutter app's Dart Tooling Daemon (DTD) URI. If a tool reports the server is not running, call `tail_runner_logs` to see whether it is still starting or why it stopped, then run `serverpod runner start` with `--directory` set to `<repo>/server/kaname_server` and call the tool again."},"id":1}
>> {"jsonrpc": "2.0", "method": "notifications/initialized"}
>> {"jsonrpc": "2.0", "id": 2, "method": "tools/list"}
<< tools: apply_migrations, create_migration, create_repair_migration, hot_reload, hot_restart, tail_server_logs, tail_flutter_logs, spawn_flutter_app, get_flutter_app_dtd, tail_runner_logs
>> {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "tail_server_logs", "arguments": {}}}
<< {"jsonrpc":"2.0","result":{"content":[{"text":"The server in <repo>/server/kaname_server is not running. Call `tail_runner_logs` to see whether it is still starting or why it stopped, then run `serverpod runner start` with `--directory` set to `<repo>/server/kaname_server` and call this tool again.","type":"text"}],"isError":true},"id":3}
stderr: Running build hooks...Running build hooks...
bridge exit code: 0
```

After the run, no process of this command remained.
