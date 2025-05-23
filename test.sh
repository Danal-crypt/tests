#!/bin/bash

# === CONFIGURABLE VARIABLES ===
ADMINUID=""

GET_ADMINPW_ES=""
GET_ADMINPW_IDM=""
GET_ADMINPW_QMULOS=""
GET_ADMINPW_AH=""

SCRIPT_DIR=$(dirname "$0")
LOG_DIR="$SCRIPT_DIR"
KO_SUMMARY_BASE_DIR="$SCRIPT_DIR"

get_admin_password() {
    case "$1" in
        *es.xxxxxxxx.splunkcloudgc.com*) echo $(eval "$GET_ADMINPW_ES") ;;
        *idm.xxxxxxx.splunkcloudgc.com*) echo $(eval "$GET_ADMINPW_IDM") ;;
        *qmulos.xxxxxxx.splunkcloudgc.com*) echo $(eval "$GET_ADMINPW_QMULOS") ;;
        *xxxxxxx.splunkcloudgc.com*) echo $(eval "$GET_ADMINPW_AH") ;;
        *) echo "UNKNOWN SITE PASSWORD COMMAND" && exit 1 ;;
    esac
}

# === PRE-VALIDATE PASSWORD COMMANDS ===
echo "Validating password retrieval commands for all servers..."
for SERVER_LABEL in ES IDM QMULOS AH; do
    CMD_VAR="GET_ADMINPW_$SERVER_LABEL"
    CMD="${!CMD_VAR}"
    PW=$(eval "$CMD" 2>/dev/null)
    if [ -z "$PW" ]; then
        echo "ERROR: Failed to retrieve password for $SERVER_LABEL server."
        exit 1
    fi
    echo "Password retrieval for $SERVER_LABEL successful (value not shown)."
done

# === RESTRICTIONS & LOCK ===
RUNNING_USER=$(whoami)
if [[ "$RUNNING_USER" == "root" || "$RUNNING_USER" == "splunk" || ! "$RUNNING_USER" =~ -A$ ]]; then
    echo "ERROR: This script must be run by a user account ending in -A. (You are: $RUNNING_USER)"
    exit 1
fi
LOCKFILE="/tmp/delete_splunk_users.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Script is already running. Lock held by: $(lsof "$LOCKFILE" | awk 'NR==2 {print $3}')"
    exit 1
fi
trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT

# === LOGGING ===
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="$LOG_DIR/user_deletion_log_$TIMESTAMP.log"
touch "$LOGFILE"
DRY_RUN_LIST=()
DELETED_USERS=()

log() {
    echo "$1" | tee -a "$LOGFILE"
}

# === DRY RUN PROMPT ===
DRY_RUN=false
read -p "Run in dry run mode? (y/n): " DRY_MODE
[ "$DRY_MODE" == "y" ] && DRY_RUN=true && log "[DRY_RUN] Dry run mode enabled. No users will be deleted."

# === USER INPUT ===
echo "Enter comma-separated usernames (example for multiple: user1,user2,user3 example for single user: user1):"
read -p "User(s) to process: " user_input
IFS=',' read -ra USERS <<< "$user_input"

# === SERVER SELECTION ===
declare -A SITES=(
    [1]="es.xxxxxxx.splunkcloudgc.com"
    [2]="idm.xxxxxxx.splunkcloudgc.com"
    [3]="qmulos.xxxxxxx.splunkcloudgc.com"
    [4]="xxxxxxx.splunkcloudgc.com"
)
echo "Enter 0 for ALL, 1 for ES, 2 for IDM, 3 for Qmulos, 4 for AH (4 is default):"
read SERVER
if [ "$SERVER" == "0" ]; then
    SELECTED_SITES=("${SITES[@]}")
else
    SELECTED_SITES=("${SITES[$SERVER]}")
fi

KO_ENDPOINTS=(
    "data/ui/views" "saved/searches" "data/lookup-table-files" "data/models"
    "data/macros" "data/eventtypes" "data/tags" "data/props/extractions" "data/ui/nav"
)

log "===== SCRIPT STARTED $TIMESTAMP ====="
log "Run by: $RUNNING_USER"
log "Users: ${USERS[*]}"
log "Servers: ${SELECTED_SITES[*]}"

# === STEP 1: CHECK USER EXISTENCE ===
declare -A USER_EXISTS
for SITE in "${SELECTED_SITES[@]}"; do
    ADMINPW=$(get_admin_password "$SITE")
    for USER in "${USERS[@]}"; do
        for i in {1..3}; do
            OUT=$(curl -s -u "$ADMINUID:$ADMINPW" "https://$SITE:8089/services/authentication/users/$USER?output_mode=json")
            echo "$OUT" | grep -q '"username":' && break
            sleep 2
        done
        [[ "$OUT" == *'"username":'* ]] && USER_EXISTS[$USER,$SITE]="yes"
    done
done

log "\n=== User Existence Summary ==="
for USER in "${USERS[@]}"; do
    for SITE in "${SELECTED_SITES[@]}"; do
        [[ "${USER_EXISTS[$USER,$SITE]}" == "yes" ]] && log "$USER exists on $SITE" || log "$USER not found on $SITE"
    done
done

read -p "Continue with KO check for existing users only? (y/n): " CONFIRM_EXIST
[ "$CONFIRM_EXIST" != "y" ] && log "Aborted." && exit 0

# === STEP 2: CHECK FOR KNOWLEDGE OBJECTS ===
declare -A USER_HAS_KO
KO_SUMMARY_DIR="$KO_SUMMARY_BASE_DIR/KO_Summaries_$TIMESTAMP"
mkdir -p "$KO_SUMMARY_DIR"

for USER in "${USERS[@]}"; do
    for SITE in "${SELECTED_SITES[@]}"; do
        [[ "${USER_EXISTS[$USER,$SITE]}" != "yes" ]] && continue
        ADMINPW=$(get_admin_password "$SITE")
        for ENDPOINT in "${KO_ENDPOINTS[@]}"; do
            for i in {1..3}; do
                RESPONSE=$(curl -s -u "$ADMINUID:$ADMINPW" "https://$SITE:8089/servicesNS/-/-/$ENDPOINT?search=owner=$USER&output_mode=json")
                [ $? -eq 0 ] && break
                sleep 2
            done
            echo "$RESPONSE" | grep -q '"entry":\[' && ! echo "$RESPONSE" | grep -q '"entry":\[\]' && {
                USER_HAS_KO[$USER,$SITE]="yes"
                echo "$RESPONSE" >> "$KO_SUMMARY_DIR/${USER}_${SITE}_KOs.json"
            }
        done
    done
done

log "\n=== KO Summary ==="
for USER in "${USERS[@]}"; do
    for SITE in "${SELECTED_SITES[@]}"; do
        [[ "${USER_EXISTS[$USER,$SITE]}" == "yes" ]] || continue
        if [[ "${USER_HAS_KO[$USER,$SITE]}" == "yes" ]]; then
            log "$USER has KOs on $SITE"
        else
            log "$USER has NO KOs on $SITE"
        fi
    done
done

# === STEP 2.5: SUMMARIZE DELETION OPTIONS ===
if [ "${#USERS[@]}" -eq 1 ]; then
    USER_LABEL="${USERS[0]}"
    echo ""
    if [[ "${USER_HAS_KO[$USER_LABEL,${SELECTED_SITES[0]}]}" == "yes" ]]; then
        echo "$USER_LABEL has knowledge objects on ${SELECTED_SITES[0]}"
    else
        echo "$USER_LABEL has no knowledge objects on ${SELECTED_SITES[0]}"
    fi
    echo ""
    echo "Options for $USER_LABEL:"
    echo "1) Delete $USER_LABEL ONLY if they have NO knowledge objects"
    echo "2) Delete $USER_LABEL even if they have knowledge objects"
    echo "3) Cancel"
else
    echo "\n=== Users WITH Knowledge Objects ==="
    for USER in "${USERS[@]}"; do
        for SITE in "${SELECTED_SITES[@]}"; do
            if [[ "${USER_EXISTS[$USER,$SITE]}" == "yes" && "${USER_HAS_KO[$USER,$SITE]}" == "yes" ]]; then
                echo "  - $USER on $SITE"
                log "User with KOs: $USER on $SITE"
            fi
        done
    done

    echo "\n=== Users WITHOUT Knowledge Objects ==="
    for USER in "${USERS[@]}"; do
        for SITE in "${SELECTED_SITES[@]}"; do
            if [[ "${USER_EXISTS[$USER,$SITE]}" == "yes" && "${USER_HAS_KO[$USER,$SITE]}" != "yes" ]]; then
                echo "  - $USER on $SITE"
                log "User without KOs: $USER on $SITE"
            fi
        done
    done

    echo ""
    echo "Options:"
    echo "1) Delete ONLY users with NO knowledge objects"
    echo "2) Delete ALL users (even those with knowledge objects)"
    echo "3) Cancel"
fi
read -p "Choose an option: " ACTION

if [ "$ACTION" == "3" ]; then
    log "Action cancelled."
    exit 0
fi

# === STEP 3: DELETE USERS ===
for USER in "${USERS[@]}"; do
    for SITE in "${SELECTED_SITES[@]}"; do
        [[ "${USER_EXISTS[$USER,$SITE]}" == "yes" ]] || continue
        if [[ "$ACTION" == "1" && "${USER_HAS_KO[$USER,$SITE]}" == "yes" ]]; then
            log "[SKIP] $USER on $SITE (has KOs, option 1 selected)"
            continue
        fi
        ADMINPW=$(get_admin_password "$SITE")
        if $DRY_RUN; then
            log "[DRY_RUN] Would delete $USER from $SITE"
            DRY_RUN_LIST+=("$USER on $SITE")
        else
            curl -k -u "$ADMINUID:$ADMINPW" -X DELETE "https://$SITE:8089/services/admin/SAML-user-role-map/$USER"
            log "[DELETE] $USER removed from $SITE"
            DELETED_USERS+=("$USER on $SITE")
        fi
    done
done

log "\n===== SCRIPT COMPLETE ====="
if $DRY_RUN; then
    log "[DRY_RUN SUMMARY] Users that would have been deleted:"
    for ITEM in "${DRY_RUN_LIST[@]}"; do
        log "  [DRY_RUN] $ITEM"
    done
else
    log "[DELETION SUMMARY] Users deleted:"
    for ITEM in "${DELETED_USERS[@]}"; do
        log "  [DELETE] $ITEM"
    done
fi
log "KO summary saved in: $KO_SUMMARY_DIR"
log "Log saved to: $LOGFILE"
