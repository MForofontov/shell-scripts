#!/usr/bin/env bash
# filepath: /Users/mykfor1/Documents/git/github/shell-scripts/security-and-access/password_generator.sh
# Advanced script to generate strong, random passwords with various options.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
LENGTH=16
LOG_FILE="/dev/null"
OUTPUT_FILE=""
COUNT=1
MODE="random"  # Options: random, memorable, pin, passphrase
CLIPBOARD=false
UPPERCASE=true
LOWERCASE=true
NUMBERS=true
SYMBOLS=true
EXCLUDE_AMBIGUOUS=false
EXCLUDE_SIMILAR=false
SHOW_STRENGTH=true
MIN_STRENGTH="strong"  # Options: weak, medium, strong, very-strong
PASSPHRASE_WORDS=4
PASSPHRASE_SEPARATOR="-"
WORDLIST="/usr/share/dict/words"
PIN_LENGTH=4
FORCE_SPECIAL=false
NO_DISPLAY=false
EXCLUDE_CHARS=""

# Character sets - careful with quotes!
UPPERCASE_CHARS="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
LOWERCASE_CHARS="abcdefghijklmnopqrstuvwxyz"
NUMBER_CHARS="0123456789"
SYMBOL_CHARS="!@#$%^&*()_+-=[]{}|;:,.<>?"
# Define ambiguous chars without quotes to avoid escaping issues
AMBIGUOUS_CHARS="{}[]()/<>\\,;:.|"
SIMILAR_CHARS="iIl1Lo0O"

# Define safe symbol pattern for regex checks
SAFE_SYMBOL_PATTERN='[!@#$%^*()\-_+={}|:,.]'

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Advanced Password Generator Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates strong, random passwords with various customization options."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mGeneral Options:\033[0m"
  echo -e "  \033[1;33m--length <length>\033[0m             (Optional) Length of the password (default: 16)."
  echo -e "  \033[1;33m--count <number>\033[0m              (Optional) Number of passwords to generate (default: 1)."
  echo -e "  \033[1;33m--mode <mode>\033[0m                 (Optional) Password generation mode: random, memorable, pin, passphrase (default: random)."
  echo -e "  \033[1;33m--output <file>\033[0m               (Optional) Save passwords to a file."
  echo -e "  \033[1;33m--log <file>\033[0m                  (Optional) Path to save detailed log information."
  echo -e "  \033[1;33m--clipboard\033[0m                   (Optional) Copy password to clipboard (only when generating a single password)."
  echo -e "  \033[1;33m--no-display\033[0m                  (Optional) Don't display passwords in terminal (use with --output or --clipboard)."
  echo
  echo -e "\033[1;34mCharacter Set Options:\033[0m"
  echo -e "  \033[1;33m--no-uppercase\033[0m                (Optional) Exclude uppercase letters."
  echo -e "  \033[1;33m--no-lowercase\033[0m                (Optional) Exclude lowercase letters."
  echo -e "  \033[1;33m--no-numbers\033[0m                  (Optional) Exclude numbers."
  echo -e "  \033[1;33m--no-symbols\033[0m                  (Optional) Exclude symbols."
  echo -e "  \033[1;33m--exclude-ambiguous\033[0m           (Optional) Exclude ambiguous characters like {}[]()/<>,;:.|"
  echo -e "  \033[1;33m--exclude-similar\033[0m             (Optional) Exclude similar-looking characters like iIl1Lo0O"
  echo -e "  \033[1;33m--exclude-chars <chars>\033[0m       (Optional) Exclude specific characters."
  echo -e "  \033[1;33m--force-special\033[0m               (Optional) Force inclusion of uppercase, lowercase, number, and symbol."
  echo
  echo -e "\033[1;34mPassphrase Options:\033[0m"
  echo -e "  \033[1;33m--words <count>\033[0m               (Optional) Number of words in passphrase (default: 4)."
  echo -e "  \033[1;33m--separator <char>\033[0m            (Optional) Word separator for passphrases (default: -)."
  echo -e "  \033[1;33m--wordlist <file>\033[0m             (Optional) Custom wordlist file for passphrases."
  echo
  echo -e "\033[1;34mMiscellaneous Options:\033[0m"
  echo -e "  \033[1;33m--no-strength\033[0m                 (Optional) Don't display password strength."
  echo -e "  \033[1;33m--min-strength <level>\033[0m        (Optional) Minimum required strength: weak, medium, strong, very-strong (default: strong)."
  echo -e "  \033[1;33m--help\033[0m                        (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --length 20 --output passwords.txt"
  echo "  $0 --count 5 --no-symbols --exclude-similar"
  echo "  $0 --mode passphrase --words 6 --separator ."
  echo "  $0 --mode pin --length 6"
  echo "  $0 --clipboard --force-special --length 24"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --length)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
          format-echo "ERROR" "Invalid length value: $2"
          usage
        fi
        LENGTH="$2"
        shift 2
        ;;
      --count)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
          format-echo "ERROR" "Invalid count value: $2"
          usage
        fi
        COUNT="$2"
        shift 2
        ;;
      --mode)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^(random|memorable|pin|passphrase)$ ]]; then
          format-echo "ERROR" "Invalid mode: $2. Must be one of: random, memorable, pin, passphrase"
          usage
        fi
        MODE="$2"
        shift 2
        ;;
      --output)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No output file provided after --output."
          usage
        fi
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --clipboard)
        CLIPBOARD=true
        shift
        ;;
      --no-uppercase)
        UPPERCASE=false
        shift
        ;;
      --no-lowercase)
        LOWERCASE=false
        shift
        ;;
      --no-numbers)
        NUMBERS=false
        shift
        ;;
      --no-symbols)
        SYMBOLS=false
        shift
        ;;
      --exclude-ambiguous)
        EXCLUDE_AMBIGUOUS=true
        shift
        ;;
      --exclude-similar)
        EXCLUDE_SIMILAR=true
        shift
        ;;
      --exclude-chars)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No characters provided after --exclude-chars."
          usage
        fi
        EXCLUDE_CHARS="$2"
        shift 2
        ;;
      --words)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
          format-echo "ERROR" "Invalid word count: $2"
          usage
        fi
        PASSPHRASE_WORDS="$2"
        shift 2
        ;;
      --separator)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No separator provided after --separator."
          usage
        fi
        PASSPHRASE_SEPARATOR="$2"
        shift 2
        ;;
      --wordlist)
        if [ -z "${2:-}" ] || [ ! -f "$2" ]; then
          format-echo "ERROR" "Invalid wordlist file: $2"
          usage
        fi
        WORDLIST="$2"
        shift 2
        ;;
      --force-special)
        FORCE_SPECIAL=true
        shift
        ;;
      --no-strength)
        SHOW_STRENGTH=false
        shift
        ;;
      --min-strength)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^(weak|medium|strong|very-strong)$ ]]; then
          format-echo "ERROR" "Invalid strength level: $2. Must be one of: weak, medium, strong, very-strong"
          usage
        fi
        MIN_STRENGTH="$2"
        shift 2
        ;;
      --no-display)
        NO_DISPLAY=true
        shift
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  # Validate arguments
  validate_args
}

# Validate command-line arguments
validate_args() {
  # Check if at least one character set is enabled
  if [[ "$UPPERCASE" == "false" && "$LOWERCASE" == "false" && "$NUMBERS" == "false" && "$SYMBOLS" == "false" && "$MODE" == "random" ]]; then
    format-echo "ERROR" "At least one character set must be enabled (uppercase, lowercase, numbers, or symbols)."
    exit 1
  fi
  
  # Check if clipboard is requested with multiple passwords
  if [[ "$CLIPBOARD" == "true" && "$COUNT" -gt 1 ]]; then
    format-echo "WARNING" "Clipboard option is only available when generating a single password. Disabling clipboard."
    CLIPBOARD=false
  fi
  
  # Check if both --no-display and no output/clipboard options are specified
  if [[ "$NO_DISPLAY" == "true" && "$OUTPUT_FILE" == "" && "$CLIPBOARD" == "false" ]]; then
    format-echo "ERROR" "When using --no-display, you must specify either --output or --clipboard."
    exit 1
  fi
  
  # Set appropriate length for PIN mode
  if [[ "$MODE" == "pin" ]]; then
    NUMBERS=true
    UPPERCASE=false
    LOWERCASE=false
    SYMBOLS=false
    if [[ "$LENGTH" == "16" ]]; then  # If user didn't specify length, use PIN default
      LENGTH="$PIN_LENGTH"
    fi
  fi
  
  # Adjust options for passphrase mode
  if [[ "$MODE" == "passphrase" && ! -f "$WORDLIST" ]]; then
    format-echo "WARNING" "Wordlist file not found: $WORDLIST. Using built-in wordlist."
    WORDLIST=""
  fi
}

#=====================================================================
# PASSWORD GENERATION FUNCTIONS
#=====================================================================
# Build character set based on options
build_charset() {
  local charset=""
  
  if [[ "$UPPERCASE" == "true" ]]; then
    charset="${charset}${UPPERCASE_CHARS}"
  fi
  
  if [[ "$LOWERCASE" == "true" ]]; then
    charset="${charset}${LOWERCASE_CHARS}"
  fi
  
  if [[ "$NUMBERS" == "true" ]]; then
    charset="${charset}${NUMBER_CHARS}"
  fi
  
  if [[ "$SYMBOLS" == "true" ]]; then
    charset="${charset}${SYMBOL_CHARS}"
  fi
  
  # Remove ambiguous characters if requested
  if [[ "$EXCLUDE_AMBIGUOUS" == "true" ]]; then
    for (( i=0; i<${#AMBIGUOUS_CHARS}; i++ )); do
      charset=${charset//${AMBIGUOUS_CHARS:$i:1}/}
    done
  fi
  
  # Remove similar characters if requested
  if [[ "$EXCLUDE_SIMILAR" == "true" ]]; then
    for (( i=0; i<${#SIMILAR_CHARS}; i++ )); do
      charset=${charset//${SIMILAR_CHARS:$i:1}/}
    done
  fi
  
  # Remove explicitly excluded characters
  if [[ -n "$EXCLUDE_CHARS" ]]; then
    for (( i=0; i<${#EXCLUDE_CHARS}; i++ )); do
      charset=${charset//${EXCLUDE_CHARS:$i:1}/}
    done
  fi
  
  # Check if we have any characters left
  if [[ -z "$charset" ]]; then
    format-echo "ERROR" "No characters available for password generation after applying exclusions."
    exit 1
  fi
  
  echo "$charset"
}

# Check if a string contains any symbol character
has_symbol_char() {
  local str="$1"
  
  # Check for basic symbols using safe regex pattern
  if [[ "$str" =~ $SAFE_SYMBOL_PATTERN ]]; then
    return 0
  fi
  
  # Check for problematic symbols individually
  if [[ "$str" == *"<"* ]] || [[ "$str" == *">"* ]] || [[ "$str" == *";"* ]] || [[ "$str" == *"?"* ]]; then
    return 0
  fi
  
  return 1
}

# Generate a random password
generate_random_password() {
  local length=$1
  local charset=$2
  local password=""
  
  # Generate the initial password
  for (( i=0; i<length; i++ )); do
    local index=$(( RANDOM % ${#charset} ))
    password="${password}${charset:$index:1}"
  done
  
  # If force special is enabled, ensure all required character types are present
  if [[ "$FORCE_SPECIAL" == "true" ]]; then
    local has_upper=false
    local has_lower=false
    local has_number=false
    local has_symbol=false
    
    # Check if the password already has all required types
    if [[ "$UPPERCASE" == "true" && "$password" =~ [A-Z] ]]; then has_upper=true; fi
    if [[ "$LOWERCASE" == "true" && "$password" =~ [a-z] ]]; then has_lower=true; fi
    if [[ "$NUMBERS" == "true" && "$password" =~ [0-9] ]]; then has_number=true; fi
    
    # Check for symbols using the helper function
    if [[ "$SYMBOLS" == "true" ]] && has_symbol_char "$password"; then
      has_symbol=true
    fi
    
    # Add missing character types by replacing random characters
    if [[ "$UPPERCASE" == "true" && "$has_upper" == "false" ]]; then
      local index=$(( RANDOM % length ))
      local upper_char=${UPPERCASE_CHARS:$(( RANDOM % ${#UPPERCASE_CHARS} )):1}
      password="${password:0:$index}${upper_char}${password:$((index+1))}"
    fi
    
    if [[ "$LOWERCASE" == "true" && "$has_lower" == "false" ]]; then
      local index=$(( RANDOM % length ))
      local lower_char=${LOWERCASE_CHARS:$(( RANDOM % ${#LOWERCASE_CHARS} )):1}
      password="${password:0:$index}${lower_char}${password:$((index+1))}"
    fi
    
    if [[ "$NUMBERS" == "true" && "$has_number" == "false" ]]; then
      local index=$(( RANDOM % length ))
      local number_char=${NUMBER_CHARS:$(( RANDOM % ${#NUMBER_CHARS} )):1}
      password="${password:0:$index}${number_char}${password:$((index+1))}"
    fi
    
    if [[ "$SYMBOLS" == "true" && "$has_symbol" == "false" ]]; then
      local index=$(( RANDOM % length ))
      local symbol_char=${SYMBOL_CHARS:$(( RANDOM % ${#SYMBOL_CHARS} )):1}
      password="${password:0:$index}${symbol_char}${password:$((index+1))}"
    fi
  fi
  
  echo "$password"
}

# Generate a PIN
generate_pin() {
  local length=$1
  local pin=""
  
  for (( i=0; i<length; i++ )); do
    local digit=$(( RANDOM % 10 ))
    pin="${pin}${digit}"
  done
  
  echo "$pin"
}

# Generate a memorable password
generate_memorable_password() {
  local length=$1
  local password=""
  
  # Consonants and vowels for pronounceable combinations
  local consonants="bcdfghjklmnpqrstvwxyz"
  local vowels="aeiou"
  
  # Start with either consonant or vowel
  local start_with_consonant=$(( RANDOM % 2 ))
  
  while [ ${#password} -lt "$length" ]; do
    if [ "$start_with_consonant" -eq 1 ]; then
      # Add consonant-vowel pair
      if [ ${#password} -lt "$length" ]; then
        password="${password}${consonants:$(( RANDOM % ${#consonants} )):1}"
      fi
      if [ ${#password} -lt "$length" ]; then
        password="${password}${vowels:$(( RANDOM % ${#vowels} )):1}"
      fi
    else
      # Add vowel-consonant pair
      if [ ${#password} -lt "$length" ]; then
        password="${password}${vowels:$(( RANDOM % ${#vowels} )):1}"
      fi
      if [ ${#password} -lt "$length" ]; then
        password="${password}${consonants:$(( RANDOM % ${#consonants} )):1}"
      fi
    fi
    
    # Randomly add a number or symbol if those options are enabled
    if [ ${#password} -lt "$length" ] && [ "$NUMBERS" == "true" ] && [ $(( RANDOM % 5 )) -eq 0 ]; then
      password="${password}${NUMBER_CHARS:$(( RANDOM % ${#NUMBER_CHARS} )):1}"
    fi
    
    if [ ${#password} -lt "$length" ] && [ "$SYMBOLS" == "true" ] && [ $(( RANDOM % 8 )) -eq 0 ]; then
      password="${password}${SYMBOL_CHARS:$(( RANDOM % ${#SYMBOL_CHARS} )):1}"
    fi
  done
  
  # Truncate to exact length
  password="${password:0:$length}"
  
  # Capitalize the first letter if uppercase is enabled
  if [ "$UPPERCASE" == "true" ]; then
    password="$(tr '[:lower:]' '[:upper:]' <<< ${password:0:1})${password:1}"
  fi
  
  echo "$password"
}

# Generate a passphrase
generate_passphrase() {
  local word_count=$1
  local separator="$2"
  local passphrase=""
  local words=()
  
  # Check if we have a wordlist
  if [[ -f "$WORDLIST" ]]; then
    # Count words in the wordlist
    local word_count_in_file=$(wc -l < "$WORDLIST")
    
    # Select random words from the wordlist
    for (( i=0; i<word_count; i++ )); do
      local line_number=$(( (RANDOM % word_count_in_file) + 1 ))
      local word=$(sed -n "${line_number}p" "$WORDLIST" | tr -d '\r\n')
      
      # Skip words that are too short or contain non-alphabetic characters
      while [[ ${#word} -lt 3 || ! "$word" =~ ^[a-zA-Z]+$ ]]; do
        line_number=$(( (RANDOM % word_count_in_file) + 1 ))
        word=$(sed -n "${line_number}p" "$WORDLIST" | tr -d '\r\n')
      done
      
      words+=("$word")
    done
  else
    # Use a small built-in wordlist if no file is available
    local builtin_words=(
      "apple" "banana" "cherry" "dragon" "eagle" "forest" "guitar" "honey" "island" "jungle"
      "kiwi" "lemon" "mango" "nature" "orange" "purple" "queen" "river" "summer" "tiger"
      "umbrella" "violet" "winter" "xylophone" "yellow" "zebra" "mountain" "ocean" "planet" "rabbit"
      "silver" "thunder" "unicorn" "volcano" "whisper" "crystal" "dolphin" "elephant" "falcon" "garden"
    )
    
    # Shuffle the array
    local array_size=${#builtin_words[@]}
    for (( i=0; i<word_count; i++ )); do
      local random_index=$(( RANDOM % array_size ))
      words+=("${builtin_words[$random_index]}")
    done
  fi
  
  # Add capitalization, numbers, or symbols if enabled
  for (( i=0; i<${#words[@]}; i++ )); do
    local word="${words[$i]}"
    
    # Capitalize if uppercase is enabled (50% chance per word)
    if [[ "$UPPERCASE" == "true" && $(( RANDOM % 2 )) -eq 0 ]]; then
      word="$(tr '[:lower:]' '[:upper:]' <<< ${word:0:1})${word:1}"
    fi
    
    # Add a random number at the end if numbers are enabled (25% chance per word)
    if [[ "$NUMBERS" == "true" && $(( RANDOM % 4 )) -eq 0 ]]; then
      word="${word}${NUMBER_CHARS:$(( RANDOM % ${#NUMBER_CHARS} )):1}"
    fi
    
    # Replace a random letter with a symbol if symbols are enabled (12.5% chance per word)
    if [[ "$SYMBOLS" == "true" && $(( RANDOM % 8 )) -eq 0 && ${#word} -gt 0 ]]; then
      local pos=$(( RANDOM % ${#word} ))
      local symbol="${SYMBOL_CHARS:$(( RANDOM % ${#SYMBOL_CHARS} )):1}"
      word="${word:0:$pos}${symbol}${word:$((pos+1))}"
    fi
    
    words[$i]="$word"
  done
  
  # Join words with the separator
  passphrase=$(IFS="$separator"; echo "${words[*]}")
  
  echo "$passphrase"
}

#=====================================================================
# PASSWORD STRENGTH EVALUATION
#=====================================================================
evaluate_password_strength() {
  local password="$1"
  local score=0
  local length=${#password}
  
  # Length contribution (up to 30 points)
  if [ "$length" -ge 20 ]; then
    score=$((score + 30))
  elif [ "$length" -ge 16 ]; then
    score=$((score + 25))
  elif [ "$length" -ge 12 ]; then
    score=$((score + 20))
  elif [ "$length" -ge 8 ]; then
    score=$((score + 10))
  else
    score=$((score + 5))
  fi
  
  # Character composition (up to 30 points)
  if [[ "$password" =~ [A-Z] ]]; then score=$((score + 7)); fi
  if [[ "$password" =~ [a-z] ]]; then score=$((score + 7)); fi
  if [[ "$password" =~ [0-9] ]]; then score=$((score + 7)); fi
  
  # Using the helper function for symbol check
  if has_symbol_char "$password"; then
    score=$((score + 9))
  fi
  
  # Variety of characters (up to 30 points)
  local uppercase_count=$(echo "$password" | grep -o '[A-Z]' | wc -l)
  local lowercase_count=$(echo "$password" | grep -o '[a-z]' | wc -l)
  local number_count=$(echo "$password" | grep -o '[0-9]' | wc -l)
  # Safe symbol counting using tr
  local symbol_count=$(echo "$password" | tr -d 'A-Za-z0-9' | wc -c)
  
  if [ "$uppercase_count" -ge 3 ]; then score=$((score + 7)); fi
  if [ "$lowercase_count" -ge 3 ]; then score=$((score + 7)); fi
  if [ "$number_count" -ge 3 ]; then score=$((score + 7)); fi
  if [ "$symbol_count" -ge 2 ]; then score=$((score + 9)); fi
  
  # Pattern avoidance (up to 10 points)
  local sequential_penalty=0
  local repeated_penalty=0
  
  # Check for sequential characters (like "abc", "123")
  for (( i=0; i<$((length-2)); i++ )); do
    local c1=$(echo "${password:$i:1}" | tr '[:upper:]' '[:lower:]')
    local c2=$(echo "${password:$((i+1)):1}" | tr '[:upper:]' '[:lower:]')
    local c3=$(echo "${password:$((i+2)):1}" | tr '[:upper:]' '[:lower:]')
    
    # ASCII values
    local v1=$(printf "%d" "'$c1" 2>/dev/null || echo 0)
    local v2=$(printf "%d" "'$c2" 2>/dev/null || echo 0)
    local v3=$(printf "%d" "'$c3" 2>/dev/null || echo 0)
    
    # Check for sequential letters or numbers
    if [[ "$v2" -eq "$((v1+1))" && "$v3" -eq "$((v2+1))" ]]; then
      sequential_penalty=$((sequential_penalty + 1))
    fi
  done
  
  # Check for repeated characters
  for (( i=0; i<$((length-2)); i++ )); do
    local c1="${password:$i:1}"
    local c2="${password:$((i+1)):1}"
    local c3="${password:$((i+2)):1}"
    
    if [[ "$c1" == "$c2" && "$c2" == "$c3" ]]; then
      repeated_penalty=$((repeated_penalty + 1))
    fi
  done
  
  # Apply penalties (max 10 points)
  local pattern_penalty=$((sequential_penalty + repeated_penalty))
  if [ "$pattern_penalty" -gt 5 ]; then pattern_penalty=5; fi
  score=$((score - (pattern_penalty * 2)))
  
  # Calculate final strength
  local strength=""
  if [ "$score" -ge 85 ]; then
    strength="very-strong"
  elif [ "$score" -ge 70 ]; then
    strength="strong"
  elif [ "$score" -ge 50 ]; then
    strength="medium"
  else
    strength="weak"
  fi
  
  # Return the strength level and score
  echo "$strength:$score"
}

# Format the strength as a colored text
format_strength() {
  local strength="$1"
  local score="$2"
  
  case "$strength" in
    "very-strong")
      echo -e "\033[1;32mVery Strong ($score)\033[0m"
      ;;
    "strong")
      echo -e "\033[0;32mStrong ($score)\033[0m"
      ;;
    "medium")
      echo -e "\033[1;33mMedium ($score)\033[0m"
      ;;
    "weak")
      echo -e "\033[1;31mWeak ($score)\033[0m"
      ;;
    *)
      echo -e "Unknown ($score)"
      ;;
  esac
}

# Check if password meets minimum strength requirement
meets_minimum_strength() {
  local password_strength="$1"
  local min_required="$MIN_STRENGTH"
  
  case "$min_required" in
    "weak")
      return 0  # All passwords meet this
      ;;
    "medium")
      if [[ "$password_strength" == "weak" ]]; then
        return 1
      else
        return 0
      fi
      ;;
    "strong")
      if [[ "$password_strength" == "very-strong" || "$password_strength" == "strong" ]]; then
        return 0
      else
        return 1
      fi
      ;;
    "very-strong")
      if [[ "$password_strength" == "very-strong" ]]; then
        return 0
      else
        return 1
      fi
      ;;
  esac
}

#=====================================================================
# OUTPUT FUNCTIONS
#=====================================================================
# Copy to clipboard (if available)
copy_to_clipboard() {
  local password="$1"
  
  # Try different clipboard commands based on OS
  if command -v pbcopy >/dev/null 2>&1; then
    # macOS
    echo -n "$password" | pbcopy
    return 0
  elif command -v xclip >/dev/null 2>&1; then
    # Linux with xclip
    echo -n "$password" | xclip -selection clipboard
    return 0
  elif command -v xsel >/dev/null 2>&1; then
    # Linux with xsel
    echo -n "$password" | xsel --clipboard
    return 0
  elif command -v clip >/dev/null 2>&1; then
    # Windows
    echo -n "$password" | clip
    return 0
  else
    format-echo "ERROR" "No clipboard command found. Install pbcopy (macOS), xclip/xsel (Linux), or clip (Windows)."
    return 1
  fi
}

# Save passwords to file
save_to_file() {
  local output_file="$1"
  local passwords=("${@:2}")
  
  # Create or truncate the file
  > "$output_file"
  
  # Set secure permissions
  chmod 600 "$output_file"
  
  # Write passwords to file
  for password in "${passwords[@]}"; do
    echo "$password" >> "$output_file"
  done
  
  format-echo "SUCCESS" "Passwords saved to: $output_file"
}

# Display a password with formatting
display_password() {
  local password="$1"
  local strength_info="$2"
  local mode="$3"
  
  # Only display if not in no-display mode
  if [[ "$NO_DISPLAY" == "false" ]]; then
    echo -e "\033[1;36mPassword:\033[0m $password"
    
    if [[ "$SHOW_STRENGTH" == "true" && "$mode" != "passphrase" && "$mode" != "pin" ]]; then
      local strength="${strength_info%:*}"
      local score="${strength_info#*:}"
      echo -e "\033[1;36mStrength:\033[0m $(format_strength "$strength" "$score")"
    fi
    echo
  fi
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  # Configure output file
  if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to output file $OUTPUT_FILE."
      exit 1
    fi
  fi

  print_with_separator "Advanced Password Generator Script"
  format-echo "INFO" "Starting Password Generation..."

  #---------------------------------------------------------------------
  # PASSWORD GENERATION
  #---------------------------------------------------------------------
  local generated_passwords=()
  local charset=""
  
  # Build character set for random mode
  if [[ "$MODE" == "random" ]]; then
    charset=$(build_charset)
    format-echo "INFO" "Using character set with ${#charset} unique characters"
  fi
  
  # Generate the requested number of passwords
  format-echo "INFO" "Generating $COUNT password(s) in '$MODE' mode with length $LENGTH..."
  
  for (( i=1; i<=COUNT; i++ )); do
    local password=""
    local strength_info=""
    local meets_requirement=false
    local max_attempts=25
    local attempt=0
    
    # Keep generating until we meet minimum strength requirement
    while [[ "$meets_requirement" == "false" ]]; do
      attempt=$((attempt + 1))
      
      # Add a safety exit after max attempts
      if [[ $attempt -gt $max_attempts ]]; then
        format-echo "WARNING" "Could not generate password meeting strength requirements after $max_attempts attempts. Using best attempt."
        meets_requirement=true
        continue
      fi
      
      # Generate password based on selected mode
      case "$MODE" in
        "random")
          password=$(generate_random_password "$LENGTH" "$charset")
          ;;
        "memorable")
          password=$(generate_memorable_password "$LENGTH")
          ;;
        "pin")
          password=$(generate_pin "$LENGTH")
          ;;
        "passphrase")
          password=$(generate_passphrase "$PASSPHRASE_WORDS" "$PASSPHRASE_SEPARATOR")
          ;;
      esac
      
      # Evaluate password strength
      if [[ "$MODE" != "passphrase" && "$MODE" != "pin" ]]; then
        strength_info=$(evaluate_password_strength "$password")
        local strength="${strength_info%:*}"
        
        # Check if it meets minimum strength
        if meets_minimum_strength "$strength"; then
          meets_requirement=true
        else
          format-echo "INFO" "Generated password doesn't meet minimum strength requirement. Regenerating..."
        fi
      else
        # Passphrases and PINs bypass strength requirements
        meets_requirement=true
        strength_info="not-applicable:0"
      fi
    done
    
    # Add to list of generated passwords
    generated_passwords+=("$password")
    
    # Display password (unless no-display is enabled)
    display_password "$password" "$strength_info" "$MODE"
    
    # Copy to clipboard if requested (only for single password)
    if [[ "$CLIPBOARD" == "true" && "$COUNT" -eq 1 ]]; then
      if copy_to_clipboard "$password"; then
        format-echo "SUCCESS" "Password copied to clipboard"
      fi
    fi
  done
  
  # Save to output file if requested
  if [[ -n "$OUTPUT_FILE" ]]; then
    save_to_file "$OUTPUT_FILE" "${generated_passwords[@]}"
  fi

  #---------------------------------------------------------------------
  # SUMMARY
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "Generated $COUNT password(s) successfully."
  
  if [[ "$CLIPBOARD" == "true" && "$COUNT" -eq 1 ]]; then
    echo -e "\033[1;33mNote:\033[0m Password has been copied to clipboard and will be overwritten when you copy something else."
  fi
  
  print_with_separator "End of Password Generator Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
