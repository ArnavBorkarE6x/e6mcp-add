# e6data MCP Connector Setup

Interactive wizard to connect **Claude Code**, **Claude Desktop**, and **Codex** to your e6data cluster's MCP server.

Minimal deps: `curl` + `sed`, plus the CLI for whatever you're configuring (`claude` and/or `codex`). The **Claude Desktop** and **Codex** paths also need **Node.js** (`npx`) — both take STDIO servers, so the wizard bridges the remote endpoint through `mcp-remote` (Desktop also uses `plutil`, built into macOS). Claude Code connects directly over HTTP, no Node required.

## Run it

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ArnavBorkarE6x/e6mcp-add/main/e6-mcp.sh)"
```

It will prompt for your cluster host, e6 email, PAT/password, and cluster name, then wire up the MCP server for you.

> Use the `bash -c "$(curl …)"` form above, **not** `curl … | bash`. The wizard reads your answers from the terminal; piping into `bash` takes over stdin and the prompts fail.

## Headless (no prompts)

Pass everything as flags. The `e6-mcp` placeholder just fills `$0` so the flags parse:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ArnavBorkarE6x/e6mcp-add/main/e6-mcp.sh)" e6-mcp \
  --host https://your-cluster-host \
  --user you@example.com \
  --password YOUR_PAT \
  --cluster YOUR_CLUSTER \
  --target both        # claude-code | claude-desktop | codex | both | all
```

## Notes

- Paste the cluster host however you have it — with or without `https://`, with trailing slashes, or even the full `/api/v2/mcp` URL. The wizard normalizes it to the correct base.
- The session token expires in ~5h — just re-run to refresh.
- The wizard quits Claude Desktop for you before writing its config — just reopen it afterward (first launch fetches `mcp-remote`, ~5s).
- Configuring Codex? Restart it afterward to load the refreshed MCP server.
- `--target both` = Claude Code + Claude Desktop; `--target all` adds Codex too.
