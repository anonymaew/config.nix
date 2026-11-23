# herdr-keep-awake — hold this Mac awake while a herdr agent is working.
#
#   herdr-keep-awake watch    poll herdr-core, hold on/off as agents come and go
#                             (this is what the launchd agent runs)
#   herdr-keep-awake on       hold off sleep now
#   herdr-keep-awake off      let the Mac sleep again
#   herdr-keep-awake status   say what is happening and why
#
# Two brakes, because they cover different things:
#
#   sudo pmset -a disablesleep 1   the only one that survives a closed lid
#   caffeinate -i -s               user-space assertions, cheap and instant
#
# Both are released together. The sudoers entry in /etc/sudoers.d allows
# exactly `pmset -a disablesleep 0|1` without a password; -n means we never
# prompt (a prompt in a launchd job would just hang).
#
# Knobs (read from the environment, defaults are the interesting ones):
#
#   HERDR_KEEP_AWAKE_STATUSES   which `hc ls` statuses count as busy.
#                               default: "working"
#                               "working blocked"      also while an agent waits on you
#                               "idle working blocked done"   any live agent at all
#                               (with 40+ idle agent terminals open that last one
#                               means the Mac never sleeps — on purpose or not)
#   HERDR_KEEP_AWAKE_CAFFEINATE caffeinate flags, default "-i -s"
#                               add -d to keep the display on (burns battery),
#                               -u to fake user activity for other apps
#   HERDR_KEEP_AWAKE_POLL       seconds between polls, default 10
#   HERDR_KEEP_AWAKE_GRACE      seconds to keep holding after the last agent
#                               stops working, default 120 (stops the brake
#                               from flickering between two short turns)

set -o errexit
set -o nounset
set -o pipefail

readonly PMSET=/usr/bin/pmset
readonly CAFFEINATE=/usr/bin/caffeinate

readonly STATUSES="${HERDR_KEEP_AWAKE_STATUSES:-working}"
readonly CAFFEINATE_FLAGS="${HERDR_KEEP_AWAKE_CAFFEINATE:--i -s}"
readonly POLL_SECONDS="${HERDR_KEEP_AWAKE_POLL:-10}"
readonly GRACE_SECONDS="${HERDR_KEEP_AWAKE_GRACE:-120}"

readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-keep-awake"
readonly PIDFILE="$STATE_DIR/caffeinate.pid"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# true while the caffeinate we started is still running
awake() {
  [[ -s $PIDFILE ]] || return 1
  local pid
  pid=$(cat "$PIDFILE")
  kill -0 "$pid" 2>/dev/null && return 0
  rm -f "$PIDFILE" # died on its own (logout, reboot, kill)
  return 1
}

# is the system-wide brake down?
sleep_disabled() {
  "$PMSET" -g 2>/dev/null | grep -q 'SleepDisabled[[:space:]]*1'
}

hold_on() {
  mkdir -p "$STATE_DIR"
  if ! awake; then
    # shellcheck disable=SC2086 # CAFFEINATE_FLAGS is a flag list on purpose
    nohup "$CAFFEINATE" $CAFFEINATE_FLAGS >/dev/null 2>&1 &
    printf '%s\n' "$!" >"$PIDFILE"
    log "caffeinate $CAFFEINATE_FLAGS up (pid $!)"
  fi
  if ! sleep_disabled; then
    if sudo -n "$PMSET" -a disablesleep 1; then
      log "pmset disablesleep 1"
    else
      log "!! pmset disablesleep 1 refused (sudoers?); caffeinate alone cannot hold a closed lid"
    fi
  fi
}

release() {
  if awake; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    log "caffeinate down"
  fi
  rm -f "$PIDFILE"
  if sleep_disabled; then
    if sudo -n "$PMSET" -a disablesleep 0; then
      log "pmset disablesleep 0"
    else
      log "!! pmset disablesleep 0 refused; set it back by hand"
    fi
  fi
}

# true when at least one live terminal reports a busy status.
#
# `hc server status` first: `hc ls` would start a core if none is up, and a
# core started from launchd would miss the login shell environment herdr-app
# deliberately gives it (PATH, TERMINFO_DIRS). No core, no agents, no hold.
busy() {
  hc server status --json 2>/dev/null | grep -q '"live"' || return 1
  local count
  count=$(
    hc ls --json 2>/dev/null | jq --arg s "$STATUSES" '
      [ .terminals[]
        | select(.state == "live" and .status != null)
        | .status as $st
        | select($s | split(" ") | index($st)) ]
      | length' 2>/dev/null
  ) || return 1
  [[ ${count:-0} -gt 0 ]]
}

watch() {
  local last_busy
  last_busy=$(date +%s)
  trap release EXIT
  trap 'exit 0' INT TERM

  log "watching (statuses: $STATUSES, poll ${POLL_SECONDS}s, grace ${GRACE_SECONDS}s)"
  # self-heal: a hold left behind by a crashed watcher
  if ! busy; then
    release
  fi

  while true; do
    if busy; then
      last_busy=$(date +%s)
      hold_on
    elif (($(date +%s) - last_busy >= GRACE_SECONDS)); then
      release
    fi
    sleep "$POLL_SECONDS" || true
  done
}

status() {
  if awake; then
    echo "holding: caffeinate pid $(cat "$PIDFILE")"
  else
    echo "holding: no"
  fi
  if sleep_disabled; then
    echo "SleepDisabled: 1"
  else
    echo "SleepDisabled: 0"
  fi
  if busy; then
    echo "agents: at least one is busy ($STATUSES)"
  else
    echo "agents: none busy ($STATUSES)"
  fi
}

usage() {
  sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-watch}" in
  watch) watch ;;
  on) hold_on ;;
  off) release ;;
  status) status ;;
  help | -h | --help) usage ;;
  *)
    echo "herdr-keep-awake: unknown command ${1}" >&2
    usage >&2
    exit 64
    ;;
esac
