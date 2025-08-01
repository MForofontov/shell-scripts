#!/usr/bin/env bash
# scale-workloads.sh
# Script to intelligently scale Kubernetes workloads based on metrics or schedules

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
WORKLOAD_TYPE="deployment"          # Default workload type to scale
WORKLOAD_NAME=""                    # Name of the workload to scale
NAMESPACE=""                        # Namespace of the workload
CONTEXT=""                          # Kubernetes context to use
REPLICA_COUNT=0                     # Target number of replicas (0 means no fixed count)
MIN_REPLICAS=1                      # Minimum number of replicas
MAX_REPLICAS=10                     # Maximum number of replicas
SCALE_MODE="fixed"                  # Scaling mode: fixed, metrics, schedule
CPU_THRESHOLD=80                    # CPU threshold percentage for scaling
MEMORY_THRESHOLD=80                 # Memory threshold percentage for scaling
SCALING_FACTOR=1.5                  # Factor to scale by when threshold is exceeded
SCALING_INTERVAL=300                # Interval in seconds between scaling decisions
SCALING_STEP=1                      # Number of replicas to add/remove at once
SCHEDULE=""                         # Schedule for time-based scaling (cron format or simple time)
SCHEDULE_FILE=""                    # File containing multiple schedules
BATCH_FILE=""                       # File containing multiple workloads to scale
LABEL_SELECTOR=""                   # Label selector for batch scaling
GRACE_PERIOD=30                     # Grace period in seconds before evaluating metrics after scaling
MAX_SCALING_OPERATIONS=5            # Maximum number of scaling operations in a single run
POST_SCALE_CHECK=true               # Whether to check workload health after scaling
METRIC_SOURCE="metrics-server"      # Source for metrics: metrics-server, prometheus
PROMETHEUS_URL=""                   # Prometheus server URL
PROMETHEUS_QUERY=""                 # Custom Prometheus query
TIMEOUT=300                         # Timeout for operations in seconds
VERIFY_TIMEOUT=120                  # Timeout for verification in seconds
DRY_RUN=false                       # Whether to perform a dry run
FORCE=false                         # Whether to force scaling without confirmation
# shellcheck disable=SC2034
LOG_FILE="/dev/null"                # Log file location

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Kubernetes Workload Scaling Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script provides intelligent scaling of Kubernetes workloads based on"
  echo "  fixed replica counts, metrics, or schedules."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m--name <NAME>\033[0m                (required) Name of the workload to scale (unless using --selector or --batch-file)"
  echo -e "  \033[1;36m--replicas <COUNT>\033[0m           (required for fixed scaling) Set fixed number of replicas"
  echo -e "  \033[1;36m--schedule <SCHEDULE>\033[0m        (required for schedule mode) Schedule for time-based scaling (cron or simple time)"
  echo -e "  \033[1;36m--schedule-file <FILE>\033[0m       (required for schedule mode) File containing multiple schedules"
  echo -e "  \033[1;36m--batch-file <FILE>\033[0m          (required for batch mode) File containing multiple workloads to scale"
  echo -e "  \033[1;36m--selector <SELECTOR>\033[0m        (required for selector mode) Label selector for batch scaling (e.g., 'app=myapp')"
  echo -e "  \033[1;33m--type <TYPE>\033[0m                (optional) Workload type to scale (default: ${WORKLOAD_TYPE})"
  echo -e "                                     Supported types: deployment, statefulset, replicaset"
  echo -e "  \033[1;33m--namespace <NAMESPACE>\033[0m      (optional) Namespace of the workload (default: current namespace)"
  echo -e "  \033[1;33m--context <CONTEXT>\033[0m          (optional) Kubernetes context to use (default: current context)"
  echo -e "  \033[1;33m--min <COUNT>\033[0m                (optional) Minimum number of replicas (default: ${MIN_REPLICAS})"
  echo -e "  \033[1;33m--max <COUNT>\033[0m                (optional) Maximum number of replicas (default: ${MAX_REPLICAS})"
  echo -e "  \033[1;33m--metrics\033[0m                    (optional) Enable metrics-based scaling"
  echo -e "  \033[1;33m--cpu-threshold <PERCENT>\033[0m    (optional) CPU threshold percentage (default: ${CPU_THRESHOLD}%)"
  echo -e "  \033[1;33m--memory-threshold <PERCENT>\033[0m (optional) Memory threshold percentage (default: ${MEMORY_THRESHOLD}%)"
  echo -e "  \033[1;33m--scaling-factor <FACTOR>\033[0m    (optional) Factor to scale by (default: ${SCALING_FACTOR})"
  echo -e "  \033[1;33m--interval <SECONDS>\033[0m         (optional) Interval between scaling decisions (default: ${SCALING_INTERVAL}s)"
  echo -e "  \033[1;33m--step <COUNT>\033[0m               (optional) Number of replicas to add/remove at once (default: ${SCALING_STEP})"
  echo -e "  \033[1;33m--grace-period <SECONDS>\033[0m     (optional) Grace period after scaling (default: ${GRACE_PERIOD}s)"
  echo -e "  \033[1;33m--metric-source <SOURCE>\033[0m     (optional) Source for metrics (default: ${METRIC_SOURCE})"
  echo -e "                                     Supported sources: metrics-server, prometheus"
  echo -e "  \033[1;33m--prometheus-url <URL>\033[0m       (optional) Prometheus server URL (for prometheus source)"
  echo -e "  \033[1;33m--prometheus-query <QUERY>\033[0m   (optional) Custom Prometheus query (for prometheus source)"
  echo -e "  \033[1;33m--no-post-check\033[0m              (optional) Skip post-scaling health check"
  echo -e "  \033[1;33m--max-operations <COUNT>\033[0m     (optional) Maximum scaling operations (default: ${MAX_SCALING_OPERATIONS})"
  echo -e "  \033[1;33m--timeout <SECONDS>\033[0m          (optional) Timeout for operations (default: ${TIMEOUT}s)"
  echo -e "  \033[1;33m--verify-timeout <SECONDS>\033[0m   (optional) Timeout for verification (default: ${VERIFY_TIMEOUT}s)"
  echo -e "  \033[1;33m--dry-run\033[0m                    (optional) Perform a dry run without making changes"
  echo -e "  \033[1;33m--force\033[0m                      (optional) Force scaling without confirmation"
  echo -e "  \033[1;33m--log <FILE>\033[0m                 (optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                       (optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  # Scale a deployment to 5 replicas"
  echo "  $0 --type deployment --name myapp --replicas 5"
  echo
  echo "  # Scale based on CPU metrics"
  echo "  $0 --type deployment --name myapp --metrics --cpu-threshold 75 --min 2 --max 10"
  echo
  echo "  # Schedule-based scaling"
  echo "  $0 --type deployment --name myapp --schedule 'weekdays 8:00' --replicas 5"
  echo "  $0 --type deployment --name myapp --schedule '0 20 * * *' --replicas 2"
  echo
  echo "  # Batch scaling using a selector"
  echo "  $0 --selector 'app=frontend' --replicas 3"
  print_with_separator
  exit 1
}

#=====================================================================
# DEPENDENCY CHECKING
#=====================================================================
#---------------------------------------------------------------------
# CHECK FOR REQUIRED TOOLS
#---------------------------------------------------------------------
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  # Check for kubectl
  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found. Please install it first."
    exit 1
  fi
  
  # Check for jq
  if ! command_exists jq; then
    format-echo "ERROR" "jq not found. Please install it first."
    exit 1
  fi
  
  # Check for yq if available (not required but helpful)
  if ! command_exists yq; then
    format-echo "WARNING" "yq not found. Some YAML processing capabilities may be limited."
  fi
  
  # If metrics-based scaling, check for metrics-server or prometheus
  if [[ "$SCALE_MODE" == "metrics" ]]; then
    if [[ "$METRIC_SOURCE" == "metrics-server" ]]; then
      # Check if metrics-server is available
      if ! kubectl $CONTEXT_FLAG get apiservice v1beta1.metrics.k8s.io &>/dev/null; then
        format-echo "ERROR" "metrics-server not found in the cluster. Please install it first or use a different metric source."
        exit 1
      fi
    elif [[ "$METRIC_SOURCE" == "prometheus" ]]; then
      # Check if prometheus URL is provided
      if [[ -z "$PROMETHEUS_URL" ]]; then
        format-echo "ERROR" "Prometheus URL not provided. Please specify with --prometheus-url."
        exit 1
      fi
      
      # Check if curl is available
      if ! command_exists curl; then
        format-echo "ERROR" "curl not found. Please install it to use Prometheus as a metric source."
        exit 1
      fi
      
      # Check if we can connect to Prometheus
      if ! curl -s "$PROMETHEUS_URL/api/v1/status/config" &>/dev/null; then
        format-echo "ERROR" "Cannot connect to Prometheus at $PROMETHEUS_URL."
        exit 1
      fi
    else
      format-echo "ERROR" "Unsupported metric source: $METRIC_SOURCE"
      exit 1
    fi
  fi
  
  # For schedule-based scaling with cron format, check for Python dependencies
  if [[ "$SCALE_MODE" == "schedule" && -n "$SCHEDULE" && "$SCHEDULE" =~ ^[0-9*,-/]+[[:space:]][0-9*,-/]+[[:space:]][0-9*,-/]+[[:space:]][0-9*,-/]+[[:space:]][0-9*,-/]+$ ]]; then
    if ! command_exists python3; then
      format-echo "ERROR" "Python3 is required to parse cron schedules."
      exit 1
    fi
    
    # Check if croniter module is installed
    if ! python3 -c "import croniter" &>/dev/null; then
      format-echo "ERROR" "Python module 'croniter' is required. Install it with: pip3 install croniter"
      exit 1
    fi
  fi
  
  format-echo "SUCCESS" "All required tools are available."
}

#=====================================================================
# KUBERNETES OPERATIONS
#=====================================================================
#---------------------------------------------------------------------
# VALIDATE WORKLOAD EXISTS AND IS ACCESSIBLE
#---------------------------------------------------------------------
validate_workload() {
  local workload_type="$1"
  local workload_name="$2"
  local namespace="$3"
  
  format-echo "INFO" "Validating $workload_type '$workload_name' in namespace '$namespace'..."
  
  # Check if workload exists
  if ! kubectl $CONTEXT_FLAG get $workload_type $workload_name -n $namespace &>/dev/null; then
    format-echo "ERROR" "$workload_type '$workload_name' not found in namespace '$namespace'."
    return 1
  fi
  
  # Get current replica count
  local current_replicas=$(kubectl $CONTEXT_FLAG get $workload_type $workload_name -n $namespace -o jsonpath='{.spec.replicas}')
  
  format-echo "SUCCESS" "Found $workload_type '$workload_name' in namespace '$namespace' with $current_replicas replicas."
  echo "$current_replicas"
  return 0
}

#---------------------------------------------------------------------
# SCALE WORKLOAD TO SPECIFIED REPLICA COUNT
#---------------------------------------------------------------------
scale_workload() {
  local workload_type="$1"
  local workload_name="$2"
  local namespace="$3"
  local replicas="$4"
  
  format-echo "INFO" "Scaling $workload_type '$workload_name' in namespace '$namespace' to $replicas replicas..."
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would scale $workload_type '$workload_name' in namespace '$namespace' to $replicas replicas."
    return 0
  fi
  
  # Scale the workload
  if ! kubectl $CONTEXT_FLAG scale $workload_type $workload_name -n $namespace --replicas=$replicas; then
    format-echo "ERROR" "Failed to scale $workload_type '$workload_name' in namespace '$namespace'."
    return 1
  fi
  
  format-echo "SUCCESS" "Scaled $workload_type '$workload_name' in namespace '$namespace' to $replicas replicas."
  return 0
}

#---------------------------------------------------------------------
# VERIFY WORKLOAD HEALTH AFTER SCALING
#---------------------------------------------------------------------
verify_workload_health() {
  local workload_type="$1"
  local workload_name="$2"
  local namespace="$3"
  local target_replicas="$4"
  
  format-echo "INFO" "Verifying $workload_type '$workload_name' health after scaling..."
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would verify $workload_type '$workload_name' health after scaling."
    return 0
  fi
  
  local start_time=$(date +%s)
  local end_time=$((start_time + VERIFY_TIMEOUT))
  local ready_replicas=0
  
  while [[ $(date +%s) -lt $end_time ]]; do
    # Check if the workload exists
    if ! kubectl $CONTEXT_FLAG get $workload_type $workload_name -n $namespace &>/dev/null; then
      format-echo "ERROR" "$workload_type '$workload_name' not found during verification."
      return 1
    fi
    
    # Get available/ready replicas based on workload type
    case "$workload_type" in
      deployment)
        ready_replicas=$(kubectl $CONTEXT_FLAG get deployment $workload_name -n $namespace -o jsonpath='{.status.readyReplicas}')
        ;;
      statefulset)
        ready_replicas=$(kubectl $CONTEXT_FLAG get statefulset $workload_name -n $namespace -o jsonpath='{.status.readyReplicas}')
        ;;
      replicaset)
        ready_replicas=$(kubectl $CONTEXT_FLAG get replicaset $workload_name -n $namespace -o jsonpath='{.status.readyReplicas}')
        ;;
    esac
    
    # If readyReplicas is not set, treat as 0
    if [[ -z "$ready_replicas" ]]; then
      ready_replicas=0
    fi
    
    format-echo "INFO" "$workload_type has $ready_replicas ready replicas of $target_replicas target replicas."
    
    # If we have the desired number of ready replicas, we're done
    if [[ "$ready_replicas" -eq "$target_replicas" ]]; then
      format-echo "SUCCESS" "$workload_type '$workload_name' is healthy with $ready_replicas ready replicas."
      
      # Check for pod status issues
      local pod_issues=$(kubectl $CONTEXT_FLAG get pods -n $namespace -l "app=$workload_name" --no-headers | grep -v "Running" || true)
      if [[ -n "$pod_issues" ]]; then
        format-echo "WARNING" "Some pods may have issues:"
        echo "$pod_issues"
      fi
      
      return 0
    fi
    
    # Wait before checking again
    sleep 5
  done
  
  format-echo "ERROR" "Timeout waiting for $workload_type '$workload_name' to become healthy."
  format-echo "ERROR" "Expected $target_replicas replicas, but only $ready_replicas are ready."
  
  # Show pod status for debugging
  format-echo "INFO" "Current pod status:"
  kubectl $CONTEXT_FLAG get pods -n $namespace -l "app=$workload_name" --no-headers
  
  return 1
}

#=====================================================================
# METRICS FUNCTIONS
#=====================================================================
#---------------------------------------------------------------------
# GET METRICS FOR A WORKLOAD
#---------------------------------------------------------------------
get_workload_metrics() {
  local workload_type="$1"
  local workload_name="$2"
  local namespace="$3"
  
  format-echo "INFO" "Getting metrics for $workload_type '$workload_name' in namespace '$namespace'..."
  
  local cpu_usage=0
  local memory_usage=0
  
  if [[ "$METRIC_SOURCE" == "metrics-server" ]]; then
    # Get pod selector for the workload
    local pod_selector=""
    case "$workload_type" in
      deployment)
        # Get the selector from the deployment
        pod_selector=$(kubectl $CONTEXT_FLAG get deployment $workload_name -n $namespace -o jsonpath='{.spec.selector.matchLabels}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
        ;;
      statefulset)
        # Get the selector from the statefulset
        pod_selector=$(kubectl $CONTEXT_FLAG get statefulset $workload_name -n $namespace -o jsonpath='{.spec.selector.matchLabels}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
        ;;
      replicaset)
        # Get the selector from the replicaset
        pod_selector=$(kubectl $CONTEXT_FLAG get replicaset $workload_name -n $namespace -o jsonpath='{.spec.selector.matchLabels}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
        ;;
    esac
    
    # If we couldn't get a selector, try a common pattern
    if [[ -z "$pod_selector" ]]; then
      pod_selector="app=$workload_name"
      format-echo "WARNING" "Could not determine pod selector, using default: $pod_selector"
    fi
    
    # Get metrics for all pods matching the selector
    local pod_metrics=$(kubectl $CONTEXT_FLAG top pods -n $namespace -l "$pod_selector" --no-headers 2>/dev/null)
    if [[ -z "$pod_metrics" ]]; then
      format-echo "WARNING" "No metrics available for pods with selector '$pod_selector'."
      echo "0 0" # Return zero metrics
      return 0
    fi
    
    # Parse metrics and calculate average CPU and memory usage
    local total_cpu=0
    local total_memory=0
    local pod_count=0
    
    while read -r line; do
      local pod_cpu=$(echo "$line" | awk '{print $2}' | sed 's/m$//')
      local pod_memory=$(echo "$line" | awk '{print $3}' | sed 's/Mi$//')
      
      total_cpu=$((total_cpu + pod_cpu))
      total_memory=$((total_memory + pod_memory))
      pod_count=$((pod_count + 1))
    done <<< "$pod_metrics"
    
    if [[ "$pod_count" -gt 0 ]]; then
      cpu_usage=$((total_cpu / pod_count))
      memory_usage=$((total_memory / pod_count))
    fi
    
  elif [[ "$METRIC_SOURCE" == "prometheus" ]]; then
    # For Prometheus, we need to use custom queries or use pre-defined queries
    
    if [[ -n "$PROMETHEUS_QUERY" ]]; then
      # Use custom query
      format-echo "INFO" "Using custom Prometheus query: $PROMETHEUS_QUERY"
      local query_result=$(curl -s --data-urlencode "query=$PROMETHEUS_QUERY" "$PROMETHEUS_URL/api/v1/query" | jq -r '.data.result[0].value[1]')
      
      if [[ -n "$query_result" && "$query_result" != "null" ]]; then
        # Assuming the query returns CPU usage as a percentage
        cpu_usage=$(echo "$query_result * 100" | bc | cut -d. -f1)
      else
        format-echo "WARNING" "No results from custom Prometheus query."
      fi
    else
      # Use default queries for CPU and memory
      
      # CPU query - avg CPU usage for pods in the deployment as a percentage
      local cpu_query="avg(rate(container_cpu_usage_seconds_total{namespace=\"$namespace\",pod=~\"$workload_name-[a-z0-9]+-[a-z0-9]+\",container!=\"POD\",container!=\"\"}[5m])) * 100"
      local cpu_result=$(curl -s --data-urlencode "query=$cpu_query" "$PROMETHEUS_URL/api/v1/query" | jq -r '.data.result[0].value[1]')
      
      if [[ -n "$cpu_result" && "$cpu_result" != "null" ]]; then
        cpu_usage=$(echo "$cpu_result" | bc | cut -d. -f1)
      else
        format-echo "WARNING" "No CPU metrics available from Prometheus."
      fi
      
      # Memory query - avg memory usage for pods in the deployment in MB
      local memory_query="avg(container_memory_usage_bytes{namespace=\"$namespace\",pod=~\"$workload_name-[a-z0-9]+-[a-z0-9]+\",container!=\"POD\",container!=\"\"}) / 1024 / 1024"
      local memory_result=$(curl -s --data-urlencode "query=$memory_query" "$PROMETHEUS_URL/api/v1/query" | jq -r '.data.result[0].value[1]')
      
      if [[ -n "$memory_result" && "$memory_result" != "null" ]]; then
        memory_usage=$(echo "$memory_result" | bc | cut -d. -f1)
      else
        format-echo "WARNING" "No memory metrics available from Prometheus."
      fi
    fi
  fi
  
  format-echo "INFO" "Current metrics - CPU: ${cpu_usage}%, Memory: ${memory_usage}MB"
  echo "$cpu_usage $memory_usage"
  return 0
}

#---------------------------------------------------------------------
# CALCULATE TARGET REPLICAS BASED ON METRICS
#---------------------------------------------------------------------
calculate_target_replicas() {
  local current_replicas="$1"
  local cpu_usage="$2"
  local memory_usage="$3"
  
  format-echo "INFO" "Calculating target replicas based on metrics..."
  format-echo "INFO" "Current replicas: $current_replicas, CPU usage: ${cpu_usage}%, Memory usage: ${memory_usage}MB"
  
  local target_replicas=$current_replicas
  
  # Scale up if CPU or memory usage is above threshold
  if [[ "$cpu_usage" -gt "$CPU_THRESHOLD" || "$memory_usage" -gt "$MEMORY_THRESHOLD" ]]; then
    format-echo "INFO" "Resource usage above threshold, calculating scale up..."
    
    # Calculate based on the resource with the highest relative usage
    local cpu_ratio=$(echo "scale=2; $cpu_usage / $CPU_THRESHOLD" | bc)
    local memory_ratio=$(echo "scale=2; $memory_usage / $MEMORY_THRESHOLD" | bc)
    
    # Use the higher ratio to determine scaling
    local scaling_ratio=$cpu_ratio
    if (( $(echo "$memory_ratio > $cpu_ratio" | bc -l) )); then
      scaling_ratio=$memory_ratio
    fi
    
    # Apply scaling factor
    local scaling_multiplier=$(echo "scale=2; $scaling_ratio * $SCALING_FACTOR" | bc)
    local calculated_replicas=$(echo "scale=0; $current_replicas * $scaling_multiplier / 1" | bc)
    
    # Ensure we don't scale up too aggressively
    local max_step_increase=$((current_replicas + SCALING_STEP))
    if [[ "$calculated_replicas" -gt "$max_step_increase" ]]; then
      calculated_replicas=$max_step_increase
    fi
    
    target_replicas=$calculated_replicas
    format-echo "INFO" "Calculated target replicas for scale up: $target_replicas"
    
  # Scale down if CPU and memory usage are below thresholds by a significant margin
  elif [[ "$cpu_usage" -lt $((CPU_THRESHOLD / 2)) && "$memory_usage" -lt $((MEMORY_THRESHOLD / 2)) ]]; then
    format-echo "INFO" "Resource usage well below threshold, calculating scale down..."
    
    # Calculate a reasonable scale-down target based on current usage
    local cpu_target_replicas=$(echo "scale=0; $current_replicas * $cpu_usage / $CPU_THRESHOLD / 1" | bc)
    local memory_target_replicas=$(echo "scale=0; $current_replicas * $memory_usage / $MEMORY_THRESHOLD / 1" | bc)
    
    # Use the higher value to ensure we don't scale down too aggressively
    local calculated_replicas=$cpu_target_replicas
    if [[ "$memory_target_replicas" -gt "$cpu_target_replicas" ]]; then
      calculated_replicas=$memory_target_replicas
    fi
    
    # Ensure we don't scale down too aggressively
    local min_step_decrease=$((current_replicas - SCALING_STEP))
    if [[ "$calculated_replicas" -lt "$min_step_decrease" && "$min_step_decrease" -gt 0 ]]; then
      calculated_replicas=$min_step_decrease
    fi
    
    target_replicas=$calculated_replicas
    format-echo "INFO" "Calculated target replicas for scale down: $target_replicas"
  else
    format-echo "INFO" "Resource usage within acceptable range, no scaling needed."
  fi
  
  # Ensure we respect min and max replicas
  if [[ "$target_replicas" -lt "$MIN_REPLICAS" ]]; then
    target_replicas=$MIN_REPLICAS
    format-echo "INFO" "Adjusted target replicas to minimum: $target_replicas"
  elif [[ "$target_replicas" -gt "$MAX_REPLICAS" ]]; then
    target_replicas=$MAX_REPLICAS
    format-echo "INFO" "Adjusted target replicas to maximum: $target_replicas"
  fi
  
  # Return the target replicas
  echo "$target_replicas"
  return 0
}

#=====================================================================
# SCHEDULE FUNCTIONS
#=====================================================================
#---------------------------------------------------------------------
# PARSE A SCHEDULE STRING AND CHECK IF IT MATCHES CURRENT TIME
#---------------------------------------------------------------------
check_schedule() {
  local schedule="$1"
  
  format-echo "INFO" "Checking if schedule '$schedule' matches current time..."
  
  # Get current time
  local current_time=$(date +%s)
  local current_hour=$(date +%H)
  local current_minute=$(date +%M)
  local current_day=$(date +%u) # 1-7, Monday is 1
  local current_date=$(date +%d)
  local current_month=$(date +%m)
  
  # Parse schedule string - two formats supported:
  # 1. Cron format: minute hour day month day-of-week
  # 2. Simple format: [weekdays|weekends|daily|monday|...] HH:MM
  
  if [[ "$schedule" =~ ^[0-9*,-/]+[[:space:]][0-9*,-/]+[[:space:]][0-9*,-/]+[[:space:]][0-9*,-/]+[[:space:]][0-9*,-/]+$ ]]; then
    # Cron format
    format-echo "INFO" "Detected cron format schedule."
    
    # Check if we have the necessary tools to parse cron
    if ! command_exists python3; then
      format-echo "ERROR" "Python3 is required to parse cron schedules."
      return 1
    fi
    
    # Use Python to check if the current time matches the cron schedule
    # This is more reliable than trying to parse cron in bash
    local matches=$(python3 -c "
import sys
from datetime import datetime
from croniter import croniter
try:
    now = datetime.now()
    base = datetime(now.year, now.month, now.day, now.hour, now.minute)
    iter = croniter('$schedule', base)
    prev = iter.get_prev(datetime)
    # Check if the previous run was less than a minute ago
    diff = (base - prev).total_seconds()
    if diff < 60:
        print('true')
    else:
        print('false')
except Exception as e:
    print('error: ' + str(e))
    sys.exit(1)
" 2>/dev/null)
    
    if [[ "$matches" == "true" ]]; then
      format-echo "INFO" "Schedule matches current time."
      return 0
    elif [[ "$matches" == "error:"* ]]; then
      format-echo "ERROR" "Failed to parse cron schedule: ${matches#error: }"
      return 1
    else
      format-echo "INFO" "Schedule does not match current time."
      return 1
    fi
    
  else
    # Simple format
    format-echo "INFO" "Detected simple format schedule."
    
    # Parse the schedule
    local day_spec=""
    local time_spec=""
    
    # Extract day and time specifications
    if [[ "$schedule" =~ ([a-z]+)[[:space:]]([0-9:]+) ]]; then
      day_spec="${BASH_REMATCH[1]}"
      time_spec="${BASH_REMATCH[2]}"
    else
      format-echo "ERROR" "Invalid schedule format: $schedule"
      format-echo "ERROR" "Expected format: '[weekdays|weekends|daily|monday|...] HH:MM'"
      return 1
    fi
    
    # Parse time specification
    local schedule_hour=""
    local schedule_minute=""
    
    if [[ "$time_spec" =~ ([0-9]+):([0-9]+) ]]; then
      schedule_hour="${BASH_REMATCH[1]}"
      schedule_minute="${BASH_REMATCH[2]}"
    else
      format-echo "ERROR" "Invalid time format: $time_spec"
      format-echo "ERROR" "Expected format: 'HH:MM'"
      return 1
    fi
    
    # Check if the current time matches the schedule
    if [[ "$current_hour" -eq "$schedule_hour" && "$current_minute" -eq "$schedule_minute" ]]; then
      # Time matches, now check day
      case "$day_spec" in
        daily)
          # Matches every day
          format-echo "INFO" "Schedule matches current time (daily at $time_spec)."
          return 0
          ;;
        weekdays)
          # Matches Monday to Friday (1-5)
          if [[ "$current_day" -ge 1 && "$current_day" -le 5 ]]; then
            format-echo "INFO" "Schedule matches current time (weekday at $time_spec)."
            return 0
          fi
          ;;
        weekends)
          # Matches Saturday and Sunday (6-7)
          if [[ "$current_day" -ge 6 && "$current_day" -le 7 ]]; then
            format-echo "INFO" "Schedule matches current time (weekend at $time_spec)."
            return 0
          fi
          ;;
        monday|mon)
          if [[ "$current_day" -eq 1 ]]; then
            format-echo "INFO" "Schedule matches current time (Monday at $time_spec)."
            return 0
          fi
          ;;
        tuesday|tue)
          if [[ "$current_day" -eq 2 ]]; then
            format-echo "INFO" "Schedule matches current time (Tuesday at $time_spec)."
            return 0
          fi
          ;;
        wednesday|wed)
          if [[ "$current_day" -eq 3 ]]; then
            format-echo "INFO" "Schedule matches current time (Wednesday at $time_spec)."
            return 0
          fi
          ;;
        thursday|thu)
          if [[ "$current_day" -eq 4 ]]; then
            format-echo "INFO" "Schedule matches current time (Thursday at $time_spec)."
            return 0
          fi
          ;;
        friday|fri)
          if [[ "$current_day" -eq 5 ]]; then
            format-echo "INFO" "Schedule matches current time (Friday at $time_spec)."
            return 0
          fi
          ;;
        saturday|sat)
          if [[ "$current_day" -eq 6 ]]; then
            format-echo "INFO" "Schedule matches current time (Saturday at $time_spec)."
            return 0
          fi
          ;;
        sunday|sun)
          if [[ "$current_day" -eq 7 ]]; then
            format-echo "INFO" "Schedule matches current time (Sunday at $time_spec)."
            return 0
          fi
          ;;
        *)
          format-echo "ERROR" "Invalid day specification: $day_spec"
          format-echo "ERROR" "Expected one of: daily, weekdays, weekends, monday, tuesday, etc."
          return 1
          ;;
      esac
    fi
    
    format-echo "INFO" "Schedule does not match current time."
    return 1
  fi
}

#---------------------------------------------------------------------
# PROCESS MULTIPLE SCHEDULES FROM A FILE
#---------------------------------------------------------------------
process_schedule_file() {
  local schedule_file="$1"
  local workload_type="$2"
  local workload_name="$3"
  local namespace="$4"
  
  format-echo "INFO" "Processing schedules from file: $schedule_file..."
  
  if [[ ! -f "$schedule_file" ]]; then
    format-echo "ERROR" "Schedule file not found: $schedule_file"
    return 1
  fi
  
  # Read each line from the file
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    
    # Parse line format: schedule,replicas
    if [[ "$line" =~ ([^,]+),([0-9]+) ]]; then
      local schedule="${BASH_REMATCH[1]}"
      local replicas="${BASH_REMATCH[2]}"
      
      format-echo "INFO" "Checking schedule: $schedule with replicas: $replicas"
      
      # Check if the schedule matches current time
      if check_schedule "$schedule"; then
        format-echo "INFO" "Schedule matches! Scaling $workload_type '$workload_name' to $replicas replicas."
        
        # Scale the workload
        if scale_workload "$workload_type" "$workload_name" "$namespace" "$replicas"; then
          if [[ "$POST_SCALE_CHECK" == true ]]; then
            # Verify the workload is healthy after scaling
            verify_workload_health "$workload_type" "$workload_name" "$namespace" "$replicas"
          fi
          
          # We found a matching schedule, no need to check others
          return 0
        else
          format-echo "ERROR" "Failed to scale workload for matching schedule."
          return 1
        fi
      fi
    else
      format-echo "WARNING" "Invalid line format in schedule file: $line"
      format-echo "WARNING" "Expected format: 'schedule,replicas'"
    fi
  done < "$schedule_file"
  
  format-echo "INFO" "No matching schedules found in file."
  return 1
}

#=====================================================================
# BATCH OPERATIONS
#=====================================================================
#---------------------------------------------------------------------
# PROCESS BATCH OPERATIONS FROM A FILE
#---------------------------------------------------------------------
process_batch_file() {
  local batch_file="$1"
  
  format-echo "INFO" "Processing batch operations from file: $batch_file..."
  
  if [[ ! -f "$batch_file" ]]; then
    format-echo "ERROR" "Batch file not found: $batch_file"
    return 1
  fi
  
  local operation_count=0
  local success_count=0
  
  # Read each line from the file
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    
    # Parse line format: type,name,namespace,replicas
    if [[ "$line" =~ ([^,]+),([^,]+),([^,]+),([0-9]+) ]]; then
      local type="${BASH_REMATCH[1]}"
      local name="${BASH_REMATCH[2]}"
      local ns="${BASH_REMATCH[3]}"
      local replicas="${BASH_REMATCH[4]}"
      
      operation_count=$((operation_count + 1))
      
      # Check if we've reached the maximum number of operations
      if [[ "$operation_count" -gt "$MAX_SCALING_OPERATIONS" ]]; then
        format-echo "WARNING" "Reached maximum number of scaling operations ($MAX_SCALING_OPERATIONS)."
        break
      fi
      
      format-echo "INFO" "Processing batch operation: $type '$name' in namespace '$ns' to $replicas replicas"
      
      # Validate the workload
      if validate_workload "$type" "$name" "$ns" &>/dev/null; then
        # Scale the workload
        if scale_workload "$type" "$name" "$ns" "$replicas"; then
          success_count=$((success_count + 1))
          
          if [[ "$POST_SCALE_CHECK" == true ]]; then
            # Verify the workload is healthy after scaling
            verify_workload_health "$type" "$name" "$ns" "$replicas"
          fi
        fi
      else
        format-echo "WARNING" "Skipping invalid workload: $type '$name' in namespace '$ns'"
      fi
    else
      format-echo "WARNING" "Invalid line format in batch file: $line"
      format-echo "WARNING" "Expected format: 'type,name,namespace,replicas'"
    fi
  done < "$batch_file"
  
  format-echo "INFO" "Batch processing completed. $success_count of $operation_count operations succeeded."
  return 0
}

#---------------------------------------------------------------------
# PROCESS WORKLOADS MATCHING A SELECTOR
#---------------------------------------------------------------------
process_selector() {
  local selector="$1"
  local replicas="$2"
  local type="$3"
  
  format-echo "INFO" "Processing workloads matching selector: $selector..."
  
  # Default to deployments if type is not specified
  if [[ -z "$type" ]]; then
    type="deployment"
  fi
  
  # Get all workloads matching the selector
  local workloads=$(kubectl $CONTEXT_FLAG get $type -A -l "$selector" --no-headers 2>/dev/null)
  
  if [[ -z "$workloads" ]]; then
    format-echo "ERROR" "No $type found matching selector: $selector"
    return 1
  fi
  
  local operation_count=0
  local success_count=0
  
  # Process each workload
  while IFS= read -r line; do
    local ns=$(echo "$line" | awk '{print $1}')
    local name=$(echo "$line" | awk '{print $2}')
    
    operation_count=$((operation_count + 1))
    
    # Check if we've reached the maximum number of operations
    if [[ "$operation_count" -gt "$MAX_SCALING_OPERATIONS" ]]; then
      format-echo "WARNING" "Reached maximum number of scaling operations ($MAX_SCALING_OPERATIONS)."
      break
    fi
    
    format-echo "INFO" "Processing $type '$name' in namespace '$ns'"
    
    # Scale the workload
    if scale_workload "$type" "$name" "$ns" "$replicas"; then
      success_count=$((success_count + 1))
      
      if [[ "$POST_SCALE_CHECK" == true ]]; then
        # Verify the workload is healthy after scaling
        verify_workload_health "$type" "$name" "$ns" "$replicas"
      fi
    fi
  done <<< "$workloads"
  
  format-echo "INFO" "Selector processing completed. $success_count of $operation_count operations succeeded."
  return 0
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  CONTEXT_FLAG=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --type)
        WORKLOAD_TYPE="$2"
        case "$WORKLOAD_TYPE" in
          deployment|statefulset|replicaset) ;;
          *)
            format-echo "ERROR" "Unsupported workload type '${WORKLOAD_TYPE}'."
            format-echo "ERROR" "Supported types: deployment, statefulset, replicaset"
            exit 1
            ;;
        esac
        shift 2
        ;;
      --name)
        WORKLOAD_NAME="$2"
        shift 2
        ;;
      --namespace)
        NAMESPACE="$2"
        shift 2
        ;;
      --context)
        CONTEXT="$2"
        CONTEXT_FLAG="--context=$CONTEXT"
        shift 2
        ;;
      --replicas)
        REPLICA_COUNT="$2"
        SCALE_MODE="fixed"
        shift 2
        ;;
      --min)
        MIN_REPLICAS="$2"
        shift 2
        ;;
      --max)
        MAX_REPLICAS="$2"
        shift 2
        ;;
      --metrics)
        SCALE_MODE="metrics"
        shift
        ;;
      --cpu-threshold)
        CPU_THRESHOLD="$2"
        shift 2
        ;;
      --memory-threshold)
        MEMORY_THRESHOLD="$2"
        shift 2
        ;;
      --scaling-factor)
        SCALING_FACTOR="$2"
        shift 2
        ;;
      --interval)
        SCALING_INTERVAL="$2"
        shift 2
        ;;
      --step)
        SCALING_STEP="$2"
        shift 2
        ;;
      --grace-period)
        GRACE_PERIOD="$2"
        shift 2
        ;;
      --metric-source)
        METRIC_SOURCE="$2"
        case "$METRIC_SOURCE" in
          metrics-server|prometheus) ;;
          *)
            format-echo "ERROR" "Unsupported metric source '${METRIC_SOURCE}'."
            format-echo "ERROR" "Supported sources: metrics-server, prometheus"
            exit 1
            ;;
        esac
        shift 2
        ;;
      --prometheus-url)
        PROMETHEUS_URL="$2"
        shift 2
        ;;
      --prometheus-query)
        PROMETHEUS_QUERY="$2"
        shift 2
        ;;
      --schedule)
        SCHEDULE="$2"
        SCALE_MODE="schedule"
        shift 2
        ;;
      --schedule-file)
        SCHEDULE_FILE="$2"
        SCALE_MODE="schedule"
        shift 2
        ;;
      --batch-file)
        BATCH_FILE="$2"
        SCALE_MODE="batch"
        shift 2
        ;;
      --selector)
        LABEL_SELECTOR="$2"
        SCALE_MODE="selector"
        shift 2
        ;;
      --no-post-check)
        POST_SCALE_CHECK=false
        shift
        ;;
      --max-operations)
        MAX_SCALING_OPERATIONS="$2"
        shift 2
        ;;
      --timeout)
        TIMEOUT="$2"
        shift 2
        ;;
      --verify-timeout)
        VERIFY_TIMEOUT="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --log)
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  # Set default namespace if not provided
  if [[ -z "$NAMESPACE" ]]; then
    NAMESPACE=$(kubectl $CONTEXT_FLAG config view --minify --output 'jsonpath={..namespace}')
    if [[ -z "$NAMESPACE" ]]; then
      NAMESPACE="default"
    fi
  fi
  
  # Validate required parameters based on scaling mode
  case "$SCALE_MODE" in
    fixed)
      if [[ -z "$WORKLOAD_NAME" && -z "$LABEL_SELECTOR" ]]; then
        format-echo "ERROR" "Workload name or selector is required for fixed scaling."
        exit 1
      fi
      
      if [[ "$REPLICA_COUNT" -lt 0 ]]; then
        format-echo "ERROR" "Replica count must be a non-negative integer."
        exit 1
      fi
      ;;
    metrics)
      if [[ -z "$WORKLOAD_NAME" ]]; then
        format-echo "ERROR" "Workload name is required for metrics-based scaling."
        exit 1
      fi
      ;;
    schedule)
      if [[ -z "$WORKLOAD_NAME" && -z "$LABEL_SELECTOR" && -z "$BATCH_FILE" ]]; then
        format-echo "ERROR" "Workload name, selector, or batch file is required for schedule-based scaling."
        exit 1
      fi
      
      if [[ -z "$SCHEDULE" && -z "$SCHEDULE_FILE" ]]; then
        format-echo "ERROR" "Schedule or schedule file is required for schedule-based scaling."
        exit 1
      fi
      
      if [[ -n "$SCHEDULE" && -z "$REPLICA_COUNT" ]]; then
        format-echo "ERROR" "Replica count is required when using a schedule."
        exit 1
      fi
      ;;
    batch)
      if [[ -z "$BATCH_FILE" ]]; then
        format-echo "ERROR" "Batch file is required for batch scaling."
        exit 1
      fi
      ;;
    selector)
      if [[ -z "$LABEL_SELECTOR" ]]; then
        format-echo "ERROR" "Label selector is required for selector-based scaling."
        exit 1
      fi
      
      if [[ "$REPLICA_COUNT" -lt 0 ]]; then
        format-echo "ERROR" "Replica count must be a non-negative integer."
        exit 1
      fi
      ;;
  esac
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  # Parse arguments
  parse_args "$@"

  setup_log_file
  
  print_with_separator "Kubernetes Workload Scaling Script"
  
  format-echo "INFO" "Starting workload scaling in ${SCALE_MODE} mode..."
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  # Display configuration
  format-echo "INFO" "Configuration:"
  
  case "$SCALE_MODE" in
    fixed)
      format-echo "INFO" "  Mode:             Fixed replica count"
      if [[ -n "$WORKLOAD_NAME" ]]; then
        format-echo "INFO" "  Workload Type:     $WORKLOAD_TYPE"
        format-echo "INFO" "  Workload Name:     $WORKLOAD_NAME"
        format-echo "INFO" "  Namespace:         $NAMESPACE"
      fi
      if [[ -n "$LABEL_SELECTOR" ]]; then
        format-echo "INFO" "  Label Selector:    $LABEL_SELECTOR"
      fi
      format-echo "INFO" "  Target Replicas:   $REPLICA_COUNT"
      ;;
    metrics)
      format-echo "INFO" "  Mode:             Metrics-based scaling"
      format-echo "INFO" "  Workload Type:     $WORKLOAD_TYPE"
      format-echo "INFO" "  Workload Name:     $WORKLOAD_NAME"
      format-echo "INFO" "  Namespace:         $NAMESPACE"
      format-echo "INFO" "  Min Replicas:      $MIN_REPLICAS"
      format-echo "INFO" "  Max Replicas:      $MAX_REPLICAS"
      format-echo "INFO" "  CPU Threshold:     ${CPU_THRESHOLD}%"
      format-echo "INFO" "  Memory Threshold:  ${MEMORY_THRESHOLD}%"
      format-echo "INFO" "  Scaling Factor:    $SCALING_FACTOR"
      format-echo "INFO" "  Scaling Interval:  ${SCALING_INTERVAL}s"
      format-echo "INFO" "  Scaling Step:      $SCALING_STEP"
      format-echo "INFO" "  Metric Source:     $METRIC_SOURCE"
      if [[ "$METRIC_SOURCE" == "prometheus" ]]; then
        format-echo "INFO" "  Prometheus URL:    $PROMETHEUS_URL"
        if [[ -n "$PROMETHEUS_QUERY" ]]; then
          format-echo "INFO" "  Prometheus Query:  $PROMETHEUS_QUERY"
        fi
      fi
      ;;
    schedule)
      format-echo "INFO" "  Mode:             Schedule-based scaling"
      if [[ -n "$WORKLOAD_NAME" ]]; then
        format-echo "INFO" "  Workload Type:     $WORKLOAD_TYPE"
        format-echo "INFO" "  Workload Name:     $WORKLOAD_NAME"
        format-echo "INFO" "  Namespace:         $NAMESPACE"
      fi
      if [[ -n "$SCHEDULE" ]]; then
        format-echo "INFO" "  Schedule:          $SCHEDULE"
        format-echo "INFO" "  Target Replicas:   $REPLICA_COUNT"
      fi
      if [[ -n "$SCHEDULE_FILE" ]]; then
        format-echo "INFO" "  Schedule File:     $SCHEDULE_FILE"
      fi
      ;;
    batch)
      format-echo "INFO" "  Mode:             Batch scaling"
      format-echo "INFO" "  Batch File:        $BATCH_FILE"
      format-echo "INFO" "  Max Operations:    $MAX_SCALING_OPERATIONS"
      ;;
    selector)
      format-echo "INFO" "  Mode:             Selector-based scaling"
      format-echo "INFO" "  Label Selector:    $LABEL_SELECTOR"
      format-echo "INFO" "  Target Replicas:   $REPLICA_COUNT"
      format-echo "INFO" "  Workload Type:     $WORKLOAD_TYPE"
      ;;
  esac
  
  format-echo "INFO" "  Post-Scale Check:  $POST_SCALE_CHECK"
  format-echo "INFO" "  Dry Run:           $DRY_RUN"
  format-echo "INFO" "  Force:             $FORCE"
  
  if [[ -n "$CONTEXT" ]]; then
    format-echo "INFO" "  Context:           $CONTEXT"
  fi
  
  #---------------------------------------------------------------------
  # PREREQUISITE CHECKS
  #---------------------------------------------------------------------
  # Check requirements
  check_requirements
  
  # Confirm operation if not forced and not dry run
  if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
    format-echo "WARNING" "This operation will scale Kubernetes workloads."
    read -r -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      format-echo "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  # Execute scaling based on mode
  case "$SCALE_MODE" in
    fixed)
      #---------------------------------------------------------------------
      # FIXED REPLICA SCALING
      #---------------------------------------------------------------------
      # Single workload with fixed replicas
      if [[ -n "$WORKLOAD_NAME" ]]; then
        format-echo "INFO" "Scaling single workload with fixed replicas..."
        
        # Validate the workload
        local current_replicas
        if current_replicas=$(validate_workload "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE"); then
          if [[ "$current_replicas" -eq "$REPLICA_COUNT" ]]; then
            format-echo "INFO" "$WORKLOAD_TYPE '$WORKLOAD_NAME' already has $REPLICA_COUNT replicas."
          else
            # Scale the workload
            if scale_workload "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE" "$REPLICA_COUNT"; then
              if [[ "$POST_SCALE_CHECK" == true ]]; then
                # Verify the workload is healthy after scaling
                verify_workload_health "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE" "$REPLICA_COUNT"
              fi
            fi
          fi
        fi
      # Selector-based scaling
      elif [[ -n "$LABEL_SELECTOR" ]]; then
        format-echo "INFO" "Scaling workloads matching selector with fixed replicas..."
        process_selector "$LABEL_SELECTOR" "$REPLICA_COUNT" "$WORKLOAD_TYPE"
      fi
      ;;
    metrics)
      #---------------------------------------------------------------------
      # METRICS-BASED SCALING
      #---------------------------------------------------------------------
      # Metrics-based scaling
      if [[ -n "$WORKLOAD_NAME" ]]; then
        format-echo "INFO" "Scaling single workload based on metrics..."
        
        # Validate the workload
        local current_replicas
        if current_replicas=$(validate_workload "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE"); then
          # Get current metrics
          local metrics
          if metrics=$(get_workload_metrics "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE"); then
            local cpu_usage=$(echo "$metrics" | cut -d' ' -f1)
            local memory_usage=$(echo "$metrics" | cut -d' ' -f2)
            
            # Calculate target replicas based on metrics
            local target_replicas
            if target_replicas=$(calculate_target_replicas "$current_replicas" "$cpu_usage" "$memory_usage"); then
              if [[ "$target_replicas" -eq "$current_replicas" ]]; then
                format-echo "INFO" "No scaling needed, current replica count is optimal."
              else
                # Scale the workload
                if scale_workload "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE" "$target_replicas"; then
                  if [[ "$POST_SCALE_CHECK" == true ]]; then
                    # Wait for grace period before verifying
                    format-echo "INFO" "Waiting for ${GRACE_PERIOD}s grace period before verification..."
                    sleep "$GRACE_PERIOD"
                    
                    # Verify the workload is healthy after scaling
                    verify_workload_health "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE" "$target_replicas"
                  fi
                fi
              fi
            fi
          fi
        fi
      # Selector-based metrics scaling is not implemented
      elif [[ -n "$LABEL_SELECTOR" ]]; then
        format-echo "WARNING" "Metrics-based scaling with selectors is a complex operation."
        format-echo "WARNING" "Consider using Kubernetes Horizontal Pod Autoscaler (HPA) for this use case."
        format-echo "ERROR" "Selector-based metrics scaling is not implemented."
        exit 1
      fi
      ;;
    schedule)
      #---------------------------------------------------------------------
      # SCHEDULE-BASED SCALING
      #---------------------------------------------------------------------
      # Schedule-based scaling
      if [[ -n "$SCHEDULE_FILE" ]]; then
        format-echo "INFO" "Processing schedule file..."
        
        if [[ -n "$WORKLOAD_NAME" ]]; then
          process_schedule_file "$SCHEDULE_FILE" "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE"
        elif [[ -n "$LABEL_SELECTOR" ]]; then
          format-echo "ERROR" "Schedule file with selector is not supported yet."
          exit 1
        fi
      elif [[ -n "$SCHEDULE" ]]; then
        format-echo "INFO" "Checking schedule: $SCHEDULE"
        
        if check_schedule "$SCHEDULE"; then
          format-echo "INFO" "Schedule matches! Proceeding with scaling."
          
          if [[ -n "$WORKLOAD_NAME" ]]; then
            # Validate the workload
            if validate_workload "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE" &>/dev/null; then
              # Scale the workload
              if scale_workload "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE" "$REPLICA_COUNT"; then
                if [[ "$POST_SCALE_CHECK" == true ]]; then
                  # Verify the workload is healthy after scaling
                  verify_workload_health "$WORKLOAD_TYPE" "$WORKLOAD_NAME" "$NAMESPACE" "$REPLICA_COUNT"
                fi
              fi
            fi
          elif [[ -n "$LABEL_SELECTOR" ]]; then
            process_selector "$LABEL_SELECTOR" "$REPLICA_COUNT" "$WORKLOAD_TYPE"
          fi
        else
          format-echo "INFO" "Schedule does not match current time. No scaling needed."
        fi
      fi
      ;;
    batch)
      #---------------------------------------------------------------------
      # BATCH SCALING
      #---------------------------------------------------------------------
      # Batch scaling
      if [[ -n "$BATCH_FILE" ]]; then
        format-echo "INFO" "Processing batch file for scaling..."
        process_batch_file "$BATCH_FILE"
      fi
      ;;
    selector)
      #---------------------------------------------------------------------
      # SELECTOR-BASED SCALING
      #---------------------------------------------------------------------
      # Selector-based scaling
      if [[ -n "$LABEL_SELECTOR" ]]; then
        format-echo "INFO" "Scaling workloads matching label selector..."
        process_selector "$LABEL_SELECTOR" "$REPLICA_COUNT" "$WORKLOAD_TYPE"
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "Workload scaling completed."
  print_with_separator
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
