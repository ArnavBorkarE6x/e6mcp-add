# e6data MCP Connector Setup

Interactive wizard to connect **Claude Code** / **Claude Desktop** to your e6data cluster's MCP server. Zero install — just `curl`, `sed`, `plutil` (macOS), and the `claude` CLI.

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
  --target both        # claude-code | claude-desktop | both
```

## Notes

- The session token expires in ~5h — just re-run to refresh.
- After a Claude Desktop change, fully quit (⌘Q) and reopen to load it.
