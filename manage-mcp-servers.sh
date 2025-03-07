#!/bin/bash

# manage-mcp-servers.sh
# Script to manage MCP servers running in the background

# Extract the MCP_SERVERS array from the start script
# Use a more reliable method to extract the array
START_SCRIPT="$(dirname "$0")/start-mcp-servers.sh"
if [ -f "$START_SCRIPT" ]; then
  # Extract the array section and source it directly
  ARRAY_SECTION=$(sed -n '/^MCP_SERVERS=(/,/^)/p' "$START_SCRIPT")
  eval "$ARRAY_SECTION"
else
  echo "Error: Could not find start-mcp-servers.sh"
  exit 1
fi

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

# Function to show usage
show_usage() {
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  help      - Show this help message"
  echo "  list      - List all running MCP servers"
  echo "  stop      - Stop all running MCP servers"
  echo "  stop [n]  - Stop a specific MCP server by number"
  echo "  fg [n]    - Bring a specific MCP server to foreground"
  echo "  logs      - Show all log files"
  echo "  logs [n]  - Show log for a specific MCP server"
  echo ""
  echo "Examples:"
  echo "  $0 help"
  echo "  $0 list"
  echo "  $0 stop"
  echo "  $0 stop 2"
  echo "  $0 fg 1"
  echo "  $0 logs"
  echo "  $0 logs 2"
  echo ""
}

# Function to list running MCP servers
list_servers() {
  echo "Running MCP servers:"
  echo "-------------------"
  
  # Get all node processes that match our MCP server patterns
  local i=1
  for server_cmd in "${MCP_SERVERS[@]}"; do
    server_name=$(get_server_name "$server_cmd")
    pid=$(pgrep -f "$server_cmd" | head -1)
    
    if [ -n "$pid" ]; then
      echo "[$i] $server_name (PID: $pid)"
    else
      echo "[$i] $server_name (not running)"
    fi
    i=$((i+1))
  done
  echo ""
}

# Function to stop all or specific MCP servers
stop_servers() {
  if [ -z "$1" ]; then
    echo "Stopping all MCP servers..."
    for server_cmd in "${MCP_SERVERS[@]}"; do
      pkill -f "$server_cmd"
    done
    echo "All MCP servers stopped."
  else
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -le "${#MCP_SERVERS[@]}" ]; then
      index=$((10#$1 - 1))
      server_cmd="${MCP_SERVERS[$index]}"
      server_name=$(get_server_name "$server_cmd")
      echo "Stopping $server_name..."
      pkill -f "$server_cmd"
      echo "$server_name stopped."
    else
      echo "Error: Invalid server number. Use 'list' to see available servers."
      exit 1
    fi
  fi
}

# Function to bring a specific MCP server to foreground
fg_server() {
  if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -gt "${#MCP_SERVERS[@]}" ]; then
    echo "Error: You must specify a valid server number to bring to foreground."
    echo "Use 'list' to see available servers."
    exit 1
  fi
  
  index=$((10#$1 - 1))
  server_cmd="${MCP_SERVERS[$index]}"
  server_name=$(get_server_name "$server_cmd")
  pid=$(pgrep -f "$server_cmd" | head -1)
  
  if [ -n "$pid" ]; then
    echo "Bringing $server_name to foreground..."
    echo "Press Ctrl+C to stop the server or Ctrl+Z followed by 'bg' to send it back to background."
    echo ""
    
    # This is a bit of a hack, but it works in most shells
    kill -STOP "$pid" 2>/dev/null
    fg %$(jobs -l | grep "$pid" | awk '{print $1}' | tr -d '[]+-') 2>/dev/null || {
      # If fg doesn't work, try to attach using tail on the log file
      kill -CONT "$pid" 2>/dev/null
      echo "Cannot bring process directly to foreground. Showing log file instead..."
      echo "The process is still running with PID $pid"
      tail -f "$server_name.log"
    }
  else
    echo "Error: $server_name is not running."
    exit 1
  fi
}

# Function to show logs
show_logs() {
  if [ -z "$1" ]; then
    echo "Available log files:"
    echo "------------------"
    ls -1 *.log 2>/dev/null
    echo ""
    echo "Use 'logs [n]' to view a specific log file."
  else
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -le "${#MCP_SERVERS[@]}" ]; then
      index=$((10#$1 - 1))
      server_cmd="${MCP_SERVERS[$index]}"
      server_name=$(get_server_name "$server_cmd")
      log_file="$server_name.log"
      
      if [ -f "$log_file" ]; then
        echo "Showing log for $server_name:"
        echo "----------------------------"
        echo "Press Ctrl+C to exit."
        echo ""
        tail -f "$log_file"
      else
        echo "Error: Log file for $server_name not found."
        exit 1
      fi
    else
      echo "Error: Invalid server number. Use 'list' to see available servers."
      exit 1
    fi
  fi
}

# Main command processing
case "$1" in
  list)
    list_servers
    ;;
  stop)
    stop_servers "$2"
    ;;
  fg)
    fg_server "$2"
    ;;
  logs)
    show_logs "$2"
    ;;
  help)
    show_usage
    ;;
  *)
    show_usage
    ;;
esac

exit 0 