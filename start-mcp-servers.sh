#!/bin/bash

# start-mcp-servers.sh
# Script to start all MCP servers for development

# ==============================================
# CONFIGURATION: Add your MCP server commands here
# ==============================================
MCP_SERVERS=(
  "npx @agentdeskai/browser-tools-server"
  "npx -y @modelcontextprotocol/server-sequential-thinking"
  # Add more server commands below, one per line:
  # "npx your-new-server-command"
  # "npx another-server-command"
)
# ==============================================

# Default mode is foreground (print logs to current terminal)
BACKGROUND_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --background|-b)
      BACKGROUND_MODE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --background, -b    Run servers in background mode (default: foreground)"
      echo "  --help, -h          Show this help message"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help to see available options"
      exit 1
      ;;
  esac
done

# If this script is being sourced by another script, don't execute the commands
if [[ "${BASH_SOURCE[0]}" != "${0}" && "$1" != "force-run" ]]; then
  return 0
fi

echo "Starting MCP servers..."

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to extract server name from command
get_server_name() {
  local cmd="$1"
  # Extract the package name after @
  if [[ "$cmd" =~ @([^/]+)/([^[:space:]]+) ]]; then
    echo "${BASH_REMATCH[2]}"
  else
    # Fallback to using the second word if no @ pattern found
    echo "$cmd" | awk '{print $2}'
  fi
}

# Clear existing log files
echo "Clearing existing log files..."
for server_cmd in "${MCP_SERVERS[@]}"; do
  server_name=$(get_server_name "$server_cmd")
  if [ -f "$server_name.log" ]; then
    rm "$server_name.log"
    echo "Removed $server_name.log"
  fi
done

# If not in background mode, run all servers in the current terminal with combined output
if [ "$BACKGROUND_MODE" = false ]; then
  echo "Running servers in foreground mode. Press Ctrl+C to stop all servers."
  echo "To run in background mode, use: $0 --background"
  echo ""
  
  # Use GNU parallel if available, otherwise fallback to a simple approach
  if command_exists parallel; then
    # Create a temporary file with server commands
    tmp_cmds=$(mktemp)
    for server_cmd in "${MCP_SERVERS[@]}"; do
      server_name=$(get_server_name "$server_cmd")
      # Create a command that also logs to a file
      echo "echo 'Starting $server_name...' && ($server_cmd 2>&1 | tee '$server_name.log')" >> "$tmp_cmds"
    done
    
    # Run all commands in parallel with output prefixed by server name
    parallel --tagstring '[{#}] {= s/.*\/(.+?)(\s.*|$)/$1/ =}:' --lb :::: "$tmp_cmds"
    rm "$tmp_cmds"
  else
    # Simple approach using background processes and tee
    # Create a named pipe for each server
    pipes_dir=$(mktemp -d)
    trap 'rm -rf "$pipes_dir"; kill $(jobs -p) 2>/dev/null' EXIT
    
    for server_cmd in "${MCP_SERVERS[@]}"; do
      server_name=$(get_server_name "$server_cmd")
      pipe="$pipes_dir/$server_name"
      mkfifo "$pipe"
      
      # Start each server with output redirected to the pipe and also to a log file
      (echo "Starting $server_name..." && ($server_cmd 2>&1 | tee "$server_name.log") || echo "$server_name exited with error") > "$pipe" &
      
      # Read from the pipe and prefix each line with the server name
      sed "s/^/[$server_name] /" < "$pipe" &
    done
    
    # Wait for all background processes to finish
    wait
  fi
  
  exit 0
fi

# If we get here, we're in background mode
# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # Check if iTerm2 is available
  if command_exists osascript && command_exists pgrep && pgrep -q "iTerm"; then
    echo "Starting servers in iTerm2 tabs..."
    
    # Start each server in a new tab
    for server_cmd in "${MCP_SERVERS[@]}"; do
      server_name=$(get_server_name "$server_cmd")
      # Create a wrapper script that will run the command and log output
      wrapper_script=$(mktemp)
      cat > "$wrapper_script" << WRAPPER
#!/bin/bash
echo "Starting $server_name..."
$server_cmd 2>&1 | tee "$(pwd)/$server_name.log"
WRAPPER
      chmod +x "$wrapper_script"
      
      osascript <<EOF
      tell application "iTerm"
        tell current window
          create tab with default profile
          tell current session
            write text "bash '$wrapper_script'; rm '$wrapper_script'"
          end tell
        end tell
      end tell
EOF
    done

  # Check if Terminal.app is available
  elif command_exists osascript && command_exists pgrep && pgrep -q "Terminal"; then
    echo "Starting servers in Terminal.app tabs..."
    
    # Start each server in a new window
    for server_cmd in "${MCP_SERVERS[@]}"; do
      server_name=$(get_server_name "$server_cmd")
      # Create a wrapper script that will run the command and log output
      wrapper_script=$(mktemp)
      cat > "$wrapper_script" << WRAPPER
#!/bin/bash
echo "Starting $server_name..."
$server_cmd 2>&1 | tee "$(pwd)/$server_name.log"
WRAPPER
      chmod +x "$wrapper_script"
      
      osascript <<EOF
      tell application "Terminal"
        do script "bash '$wrapper_script'; rm '$wrapper_script'"
      end tell
EOF
    done

  else
    # Fallback to tmux if available
    if command_exists tmux; then
      echo "Starting servers in tmux sessions..."
      
      # Create a new tmux session if not already in one
      if [ -z "$TMUX" ]; then
        tmux new-session -d -s mcp
      fi
      
      # Create windows for each server
      window_index=1
      for server_cmd in "${MCP_SERVERS[@]}"; do
        server_name=$(get_server_name "$server_cmd")
        # Create a wrapper script that will run the command and log output
        wrapper_script=$(mktemp)
        cat > "$wrapper_script" << WRAPPER
#!/bin/bash
echo "Starting $server_name..."
$server_cmd 2>&1 | tee "$(pwd)/$server_name.log"
WRAPPER
        chmod +x "$wrapper_script"
        
        tmux new-window -t mcp:$window_index -n "$server_name" "bash '$wrapper_script'; rm '$wrapper_script'"
        window_index=$((window_index + 1))
      done
      
      # Attach to the session if not already in tmux
      if [ -z "$TMUX" ]; then
        tmux attach-session -t mcp
      fi
    else
      # Simple fallback - start in background with output to files
      echo "Starting servers in background..."
      echo "Output will be logged to log files in the current directory."
      
      for server_cmd in "${MCP_SERVERS[@]}"; do
        server_name=$(get_server_name "$server_cmd")
        echo "Starting $server_name..."
        $server_cmd > "$server_name.log" 2>&1 &
      done
      
      echo "Servers started in background. Use './manage-mcp-servers.sh' to manage them."
    fi
  fi
else
  # For Linux and other systems, use simpler approach with gnome-terminal if available
  if command_exists gnome-terminal; then
    echo "Starting servers in gnome-terminal tabs..."
    for server_cmd in "${MCP_SERVERS[@]}"; do
      server_name=$(get_server_name "$server_cmd")
      # Create a wrapper script that will run the command and log output
      wrapper_script=$(mktemp)
      cat > "$wrapper_script" << WRAPPER
#!/bin/bash
echo "Starting $server_name..."
$server_cmd 2>&1 | tee "$(pwd)/$server_name.log"
WRAPPER
      chmod +x "$wrapper_script"
      
      gnome-terminal -- bash -c "bash '$wrapper_script'; rm '$wrapper_script'; bash"
    done
  else
    # Simple fallback - start in background with output to files
    echo "Starting servers in background..."
    echo "Output will be logged to log files in the current directory."
    
    for server_cmd in "${MCP_SERVERS[@]}"; do
      server_name=$(get_server_name "$server_cmd")
      echo "Starting $server_name..."
      $server_cmd > "$server_name.log" 2>&1 &
    done
    
    echo "Servers started in background. Use './manage-mcp-servers.sh' to manage them."
  fi
fi

echo "All MCP servers have been started." 