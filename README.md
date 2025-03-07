# MCP Server Management Scripts

This repository contains scripts to easily start and manage MCP (Model Context
Protocol) servers for development.

## Scripts Overview

- **start-mcp-servers.sh**: Starts all your MCP servers
- **manage-mcp-servers.sh**: Helps you manage running MCP servers (list, stop,
  view logs, etc.)

## Getting Started

Make sure both scripts are executable:

```bash
chmod +x start-mcp-servers.sh manage-mcp-servers.sh
```

## Starting MCP Servers

To start all your MCP servers:

```bash
./start-mcp-servers.sh
```

By default, this will:

1. Clear any existing log files
2. Run all servers in the foreground with output displayed in the current
   terminal
3. Prefix each line with the server name for easy identification

### Running in Background Mode

If you prefer to run servers in the background:

```bash
./start-mcp-servers.sh --background
```

In background mode, the script will try to start servers using one of these
methods (in order of preference):

1. iTerm2 tabs (if using iTerm2)
2. Terminal.app windows (if using Terminal.app)
3. tmux sessions (if tmux is available)
4. Background processes with log files (fallback method)

### Command Line Options

```bash
./start-mcp-servers.sh --help
```

Available options:

- `--background`, `-b`: Run servers in background mode
- `--help`, `-h`: Show help message

## Managing MCP Servers

The management script provides several commands to help you manage your running
MCP servers:

### Show Help

```bash
./manage-mcp-servers.sh help
```

### List Running Servers

```bash
./manage-mcp-servers.sh list
```

This will show all configured servers and whether they're running or not.

### Stop Servers

Stop all servers:

```bash
./manage-mcp-servers.sh stop
```

Stop a specific server (by number):

```bash
./manage-mcp-servers.sh stop 1  # Stop the first server
```

### View Logs

List all log files:

```bash
./manage-mcp-servers.sh logs
```

View logs for a specific server (by number):

```bash
./manage-mcp-servers.sh logs 1  # View logs for the first server
```

### Bring a Server to Foreground

```bash
./manage-mcp-servers.sh fg 1  # Bring the first server to foreground
```

If bringing to foreground isn't possible, it will show the log file in
real-time.

## Adding New MCP Servers

To add a new MCP server, you only need to edit the `start-mcp-servers.sh` file:

1. Open `start-mcp-servers.sh`
2. Find the `MCP_SERVERS` array at the top of the file
3. Add your new server command as a new line in the array

```bash
MCP_SERVERS=(
  "npx @agentdeskai/browser-tools-server"
  "npx -y @modelcontextprotocol/server-sequential-thinking"
  "npx your-new-server-command"  # Add your new server here
)
```

The management script will automatically pick up the new server from the start
script.

## Log Management

The scripts handle logs in the following ways:

1. **Automatic Cleanup**: When starting servers, existing log files are
   automatically cleared to prevent them from growing too large.

2. **Foreground Mode**: In the default foreground mode, logs are displayed
   directly in the terminal with server name prefixes.

3. **Background Mode**: In background mode, logs are saved to files named after
   each server (e.g., `browser-tools-server.log`).

4. **Viewing Logs**: Use `./manage-mcp-servers.sh logs` to view logs for
   background processes.

## How It Works

- The start script defines all your MCP servers in an array at the top
- It detects your environment and starts the servers in the most appropriate way
- The management script extracts the server configuration from the start script
- It uses `pgrep` to find running processes and `pkill` to stop them
- For viewing logs, it uses `tail -f` to show real-time updates

## Troubleshooting

If you encounter any issues:

1. Make sure both scripts are executable (`chmod +x *.sh`)
2. Check that the server commands in the array are correct
3. Look at the log files in the current directory for error messages
4. Try running the server commands manually to see if they work
