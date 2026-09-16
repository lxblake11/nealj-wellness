#!/bin/bash

# HEREDOC SCRIPT PARSER — STRICT VERSION
# Converts megachunk heredoc dumps into project files.
#
# Usage:
#   ./heredoc-parser.sh RITUAL_MEGACHUNK_1_FOUNDATION.txt --force
#   ./heredoc-parser.sh RITUAL_MEGACHUNK_1_FOUNDATION.txt --dry-run
#
# Supported heredoc format:
#   cat > path/to/file.tsx << 'EOF'
#   file contents
#   EOF
#
# This parser intentionally only matches lines that START with:
#   cat >
#
# This prevents false positives from footer instructions like:
#   grep -c "^cat > " file.txt

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FILES_CREATED=0
DIRS_CREATED=0
ERRORS=0

VERBOSE=false
DRY_RUN=false
FORCE=false
BACKUP=false
INPUT_FILE=""

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  ERRORS=$((ERRORS + 1))
}

show_help() {
  cat << 'EOF'
HEREDOC SCRIPT PARSER

Usage:
  ./heredoc-parser.sh <input-file> [options]

Options:
  -h, --help       Show help
  -v, --verbose    Verbose output
  -d, --dry-run    Show what would be created without writing
  -f, --force      Overwrite existing files
  --backup         Back up existing files before overwrite

Expected block format:
  cat > path/to/file.tsx << 'EOF'
  file contents
  EOF
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -d|--dry-run|--dryrun)
      DRY_RUN=true
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    --backup)
      BACKUP=true
      shift
      ;;
    -*)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
      else
        log_error "Multiple input files specified: '$INPUT_FILE' and '$1'"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$INPUT_FILE" ]]; then
  log_error "No input file specified."
  show_help
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  log_error "Input file '$INPUT_FILE' does not exist."
  exit 1
fi

validate_structure() {
  local input_file="$1"

  log_info "Validating heredoc structure..."

  local cat_count
  local eof_count

  # Strict: only real commands at start of line.
  cat_count=$(grep -c "^cat > .\\+ << 'EOF'$" "$input_file" || true)

  # Strict: EOF must be alone on its own line.
  eof_count=$(grep -c "^EOF$" "$input_file" || true)

  if [[ "$cat_count" -ne "$eof_count" ]]; then
    log_error "Mismatched heredoc blocks: $cat_count real 'cat >' blocks vs $eof_count 'EOF' closers"
    log_info "Debug real cat blocks:"
    grep -n "^cat > " "$input_file" || true
    log_info "Debug EOF closers:"
    grep -n "^EOF$" "$input_file" || true
    return 1
  fi

  if [[ "$cat_count" -eq 0 ]]; then
    log_error "No heredoc blocks found. Expected lines like: cat > path/file.ts << 'EOF'"
    return 1
  fi

  log_success "Structure validation passed ($cat_count blocks found)"
  return 0
}

parse_heredoc_dump() {
  local input_file="$1"

  log_info "Parsing heredoc blocks..."

  local in_block=false
  local filepath=""
  local tmpfile=""
  local line_num=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    if [[ "$in_block" == false ]]; then
      if [[ "$line" =~ ^cat\ \>\ (.+)\ \<\<\ \'EOF\'$ ]]; then
        filepath="${BASH_REMATCH[1]}"

        if [[ -z "$filepath" ]]; then
          log_error "Empty filepath at line $line_num"
          continue
        fi

        if [[ "$filepath" == /* ]]; then
          log_error "Absolute paths are not allowed: $filepath"
          continue
        fi

        if [[ "$filepath" == *".."* ]]; then
          log_error "Parent directory traversal is not allowed: $filepath"
          continue
        fi

        tmpfile="$(mktemp)"

        if [[ "$VERBOSE" == true ]]; then
          log_info "Opened block for $filepath at line $line_num"
        fi

        in_block=true
      fi

      continue
    fi

    if [[ "$line" == "EOF" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log_success "Would create: $filepath"
        rm -f "$tmpfile"
      else
        local dir_path
        dir_path="$(dirname "$filepath")"

        if [[ ! -d "$dir_path" ]]; then
          mkdir -p "$dir_path"
          DIRS_CREATED=$((DIRS_CREATED + 1))
          if [[ "$VERBOSE" == true ]]; then
            log_success "Directory: $dir_path"
          fi
        fi

        if [[ -f "$filepath" && "$FORCE" == false ]]; then
          if [[ "$BACKUP" == true ]]; then
            cp "$filepath" "${filepath}.backup"
            log_warning "Backed up existing file: ${filepath}.backup"
          else
            log_warning "File exists, skipping: $filepath (use --force to overwrite)"
            rm -f "$tmpfile"
            in_block=false
            filepath=""
            tmpfile=""
            continue
          fi
        fi

        if [[ -f "$filepath" && "$BACKUP" == true && "$FORCE" == true ]]; then
          cp "$filepath" "${filepath}.backup"
          log_warning "Backed up existing file: ${filepath}.backup"
        fi

        mv "$tmpfile" "$filepath"
        FILES_CREATED=$((FILES_CREATED + 1))
        log_success "Created: $filepath"
      fi

      in_block=false
      filepath=""
      tmpfile=""
      continue
    fi

    printf '%s\n' "$line" >> "$tmpfile"
  done < "$input_file"

  if [[ "$in_block" == true ]]; then
    log_error "Unclosed heredoc block for $filepath"
    [[ -n "$tmpfile" ]] && rm -f "$tmpfile"
    return 1
  fi

  return 0
}

show_summary() {
  echo
  log_info "=== EXECUTION SUMMARY ==="
  echo "Directories created: $DIRS_CREATED"
  echo "Files created: $FILES_CREATED"
  echo "Errors: $ERRORS"

  if [[ "$ERRORS" -eq 0 ]]; then
    log_success "All operations completed successfully."
  else
    log_warning "Completed with $ERRORS error(s)."
  fi
}

main() {
  log_info "Starting Heredoc Script Parser"
  log_info "Input file: $INPUT_FILE"

  if [[ "$DRY_RUN" == true ]]; then
    log_warning "DRY RUN MODE — no files will be written"
  fi

  if ! validate_structure "$INPUT_FILE"; then
    show_summary
    exit 1
  fi

  if ! parse_heredoc_dump "$INPUT_FILE"; then
    show_summary
    exit 1
  fi

  show_summary

  if [[ "$ERRORS" -gt 0 ]]; then
    exit 1
  fi
}

main