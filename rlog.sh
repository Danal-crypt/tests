#!/bin/sh

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

OLD_SEEK_FILE=$SPLUNK_HOME/var/run/splunk/unix_audit_seekfile # For handling upgrade scenarios
CURRENT_AUDIT_FILE=/var/log/audit/audit.log # For handling upgrade scenarios
SEEK_FILE=$SPLUNK_HOME/var/run/splunk/unix_audit_seektime
TMP_ERROR_FILTER_FILE=$SPLUNK_HOME/var/run/splunk/unix_rlog_error_tmpfile # For filtering out "no matches" error from stderr
AUDIT_LOG_DIR="/var/log/audit"
AUDIT_FILES=$(ls -1 "${AUDIT_LOG_DIR}"/audit.log "${AUDIT_LOG_DIR}"/audit.log.[0-9]* 2>/dev/null | sort -V)

# ----------------------------
# AuditFilters.txt filtering (PID-based)
# ----------------------------

AUDIT_FILTER_FILE_LOCAL="$SPLUNK_HOME/etc/apps/Splunk_TA_nix/local/AuditFilters.txt"
AUDIT_FILTER_FILE_DEFAULT="$SPLUNK_HOME/etc/apps/Splunk_TA_nix/default/AuditFilters.txt"

TMP_AUSEARCH_OUT="$SPLUNK_HOME/var/run/splunk/unix_audit_ausearch_tmpout"
TMP_FILTER_REGEX_FILE="$SPLUNK_HOME/var/run/splunk/unix_audit_filter_regex_tmp"
TMP_FILTERED_PID_FILE="$SPLUNK_HOME/var/run/splunk/unix_audit_filtered_pids_tmp"

# Build a combined regex from AuditFilters.txt
build_filter_regex() {
    FILTER_FILE=""
    if [ -f "$AUDIT_FILTER_FILE_LOCAL" ]; then
        FILTER_FILE="$AUDIT_FILTER_FILE_LOCAL"
    elif [ -f "$AUDIT_FILTER_FILE_DEFAULT" ]; then
        FILTER_FILE="$AUDIT_FILTER_FILE_DEFAULT"
    fi

    if [ -z "$FILTER_FILE" ]; then
        return 1
    fi

    # Strip blank lines and comments
    sed -e 's/[[:space:]]*$//' \
        -e '/^[[:space:]]*$/d' \
        -e '/^[[:space:]]*#/d' \
        -e 's/\*/.*/g' \
        "$FILTER_FILE" > "$TMP_FILTER_REGEX_FILE"

    # If file ended up empty, treat as no filters
    if [ ! -s "$TMP_FILTER_REGEX_FILE" ]; then
        return 1
    fi

    return 0
}

# Filter ausearch output in a temp file
filter_ausearch_file_keep_separators() {
    INFILE="$1"

    # If no filters present, just emit original content
    if ! build_filter_regex; then
        cat "$INFILE"
        return 0
    fi

    # Create one combined alternation regex for fast matching:
    # pattern1|pattern2|pattern3...
    COMBINED_REGEX=$(paste -sd'|' "$TMP_FILTER_REGEX_FILE")

    # Pass 1: Identify PIDs from events that match the filter patterns.
    # We treat "----" as the event delimiter and operate on whole blocks.
    #
    # Record separator: "----\n"
    # We extract pid=#### from matching blocks and build a unique PID list.
    awk -v RS='----\n' -v re="$COMBINED_REGEX" '
        $0 ~ re {
            if (match($0, /pid=[0-9]+/)) {
                pid = substr($0, RSTART+4, RLENGTH-4)
                print pid
            }
        }
    ' "$INFILE" | sort -u > "$TMP_FILTERED_PID_FILE"

    # If no PIDs matched, output original
    if [ ! -s "$TMP_FILTERED_PID_FILE" ]; then
        cat "$INFILE"
        return 0
    fi

    PID_REGEX=$(paste -sd'|' "$TMP_FILTERED_PID_FILE")

    # Pass 2: Drop entire events whose PID is in the PID list.
    # Keep separators: emit block + "----" after it.
    #
    # NOTE: This expects ausearch blocks include "pid=####" somewhere.
    awk -v RS='----\n' -v ORS='----\n' -v pidre="$PID_REGEX" '
        {
            if (match($0, /pid=[0-9]+/)) {
                pid = substr($0, RSTART+4, RLENGTH-4)
                if (pid ~ ("^(" pidre ")$")) {
                    next
                }
            }
            print $0
        }
    ' "$INFILE"
}

# Helper: run ausearch, capture stdout to temp, keep stderr handling, then apply filtering
run_ausearch_and_filter() {
    # Arguments are the ausearch args except -if which we supply separately
    # Usage: run_ausearch_and_filter "<ausearch args>" "<audit file>"
    AUSEARCH_ARGS="$1"
    AUDIT_FILE="$2"

    # shellcheck disable=SC2086
    /sbin/ausearch -i $AUSEARCH_ARGS -if "$AUDIT_FILE" 2>"$TMP_ERROR_FILTER_FILE" > "$TMP_AUSEARCH_OUT"
    # filter out "<no matches>" noise on stderr
    grep -v "<no matches>" <"$TMP_ERROR_FILTER_FILE" 1>&2

    # Apply filtering
    filter_ausearch_file_keep_separators "$TMP_AUSEARCH_OUT"
}

# ----------------------------
# Main logic
# ----------------------------

if [ "$KERNEL" = "Linux" ] ; then
    assertHaveCommand service
    assertHaveCommandGivenPath /sbin/ausearch

    if [ -n "$(service auditd status 2>/dev/null)" ] && [ "$(service auditd status 2>/dev/null)" ] ; then
        CURRENT_TIME=$(date --date="1 seconds ago"  "+%x %T") # 1 second ago to avoid data loss

        if [ -e "$SEEK_FILE" ] ; then
            SEEK_TIME=$(head -1 "$SEEK_FILE")
            for AUDIT_FILE in $AUDIT_FILES; do
                run_ausearch_and_filter "-ts $SEEK_TIME -te $CURRENT_TIME" "$AUDIT_FILE"
            done

        elif [ -e "$OLD_SEEK_FILE" ] ; then
            rm -rf "$OLD_SEEK_FILE" # remove previous checkpoint
            for AUDIT_FILE in $AUDIT_FILES; do
                # start ingesting from the first entry of current audit file
                run_ausearch_and_filter "-te $CURRENT_TIME" "$AUDIT_FILE"
            done

        else
            # no checkpoint found
            for AUDIT_FILE in $AUDIT_FILES; do
                run_ausearch_and_filter "-te $CURRENT_TIME" "$AUDIT_FILE"
            done
        fi

        echo "$CURRENT_TIME" > "$SEEK_FILE" # Checkpoint+

    else   # Added this condition to get error logs
        echo "error occured while running 'service auditd status' command in rlog.sh script. Output : $(service auditd status). Command exited with exit code $?" 1>&2
    fi

    # remove temporary files if they exist
    rm -f "$TMP_ERROR_FILTER_FILE" "$TMP_AUSEARCH_OUT" "$TMP_FILTER_REGEX_FILE" "$TMP_FILTERED_PID_FILE" 2>/dev/null

elif [ "$KERNEL" = "SunOS" ] ; then
    :
elif [ "$KERNEL" = "Darwin" ] ; then
    :
elif [ "$KERNEL" = "HP-UX" ] ; then
    :
elif [ "$KERNEL" = "FreeBSD" ] ; then
    :
fi
