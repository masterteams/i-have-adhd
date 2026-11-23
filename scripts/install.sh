#!/usr/bin/env bash
# Install the canonical i-have-adhd agent skill with the skills CLI.
# Default: current project, Codex. Never edits agent configuration directly.
set -euo pipefail

SKILL="i-have-adhd"
SOURCE="masterteams/i-have-adhd"
SCOPE="project"
CONFIRM="--yes"
DRY_RUN=false
AGENTS=()

usage() {
  cat <<'HELP'
Install i-have-adhd for an AI coding agent with npx skills.

Usage: bash scripts/install.sh [options]
  -a, --agent NAME      codex, claude-code, cursor, opencode, github-copilot;
                        repeat to install for more than one agent (default: codex)
  -g, --global          Install for the current user (all projects)
      --project         Install into the current project (default)
      --source PATH     Use a local checkout or another skills CLI source
      --interactive     Ask for confirmation in skills CLI (default: automatic)
      --dry-run         Show commands without installing anything
  -h, --help            Show this help

Examples:
  bash scripts/install.sh --agent codex --global
  bash scripts/install.sh -a codex -a claude-code --global
  bash scripts/install.sh -a cursor --project
  bash scripts/install.sh -a codex --source . --dry-run

Requires Node.js/npm (npx) and Git when installing from GitHub.
For the local project, run this command from the project you wish to modify.
HELP
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 2; }

while (($#)); do
  case "$1" in
    -a|--agent)
      (($# >= 2)) || fail "$1 needs an agent name"
      case "$2" in
        codex|claude-code|cursor|opencode|github-copilot) AGENTS+=("$2");;
        *) fail "Unsupported agent: $2";;
      esac
      shift 2;;
    -g|--global) SCOPE="global"; shift;;
    --project) SCOPE="project"; shift;;
    --source)
      (($# >= 2)) || fail "--source needs a path or repository"
      [[ -n "$2" && "$2" != -* ]] || fail "--source must be nonempty and not an option"
      SOURCE="$2"; shift 2;;
    --interactive) CONFIRM=""; shift;;
    --dry-run) DRY_RUN=true; shift;;
    -h|--help) usage; exit 0;;
    *) fail "Unknown option: $1";;
  esac
done

((${#AGENTS[@]})) || AGENTS=(codex)
# Deduplicate agents without changing order.
UNIQUE=()
for agent in "${AGENTS[@]}"; do
  found=false
  for existing in "${UNIQUE[@]}"; do
    if [[ "$existing" == "$agent" ]]; then found=true; break; fi
  done
  if [[ "$found" == false ]]; then UNIQUE+=("$agent"); fi
done

cmd=(npx --yes skills add "$SOURCE" --skill "$SKILL")
for agent in "${UNIQUE[@]}"; do cmd+=(--agent "$agent"); done
[[ "$SCOPE" == global ]] && cmd+=(--global)
[[ -n "$CONFIRM" ]] && cmd+=("$CONFIRM")

printf 'Skill: %s | Agents: %s | Scope: %s | Source: %s\n' \
  "$SKILL" "${UNIQUE[*]}" "$SCOPE" "$SOURCE"
printf 'Command:'
printf ' %q' "${cmd[@]}"
printf '\n'

if [[ "$DRY_RUN" == true ]]; then
  printf 'Dry run: no files changed.\n'
  exit 0
fi

command -v npx >/dev/null 2>&1 || fail "npx not found; install Node.js and npm first"
case "$SOURCE" in
  .|..|/*|./*|../*)
    [[ -d "$SOURCE" ]] || fail "Local source directory does not exist: $SOURCE"
    [[ -f "$SOURCE/skills/$SKILL/SKILL.md" ]] || fail "Skill file missing: $SOURCE/skills/$SKILL/SKILL.md";;
  *) command -v git >/dev/null 2>&1 || fail "git not found; Git is needed for repository sources";;
esac

"${cmd[@]}"
printf '\nInstallation command completed successfully. Verify with: npx skills list'
[[ "$SCOPE" == global ]] && printf ' --global'
printf '\nActivate explicitly in your agent (Codex: $i-have-adhd; Claude Code: /i-have-adhd).\n'
