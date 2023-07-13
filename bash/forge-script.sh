#!/bin/bash
set -eo pipefail

source "${BASH_SOURCE%/*}/_common.sh"

run_script() {
	normalize-env-vars

	local PASSWORD="$(extract-password)"
	local PASSWORD_OPT=()
	if [ -n "$PASSWORD" ]; then
		PASSWORD_OPT=(--password "$PASSWORD")
	fi

	check-required-etherscan-api-key "$@"

	local RESPONSE=
	# Log the command being issued, making sure not to expose the password
	log "forge script --json --sender "$FOUNDRY_ETH_FROM" --keystore "$FOUNDRY_ETH_KEYSTORE_FILE" $(sed 's/ .*$/ [REDACTED]/' <<<"${PASSWORD_OPT[@]}")" $(printf ' %q' "$@")
	# Currently `forge create` sends the logs to stdout instead of stderr.
	# This makes it hard to compose its output with other commands, so here we are:
	# 1. Duplicating stdout to stderr through `tee`
	# 2. Extracting only the address of the deployed contract to stdout
	RESPONSE=$(forge script --json --sender "$FOUNDRY_ETH_FROM" --keystore "$FOUNDRY_ETH_KEYSTORE_FILE" "${PASSWORD_OPT[@]}" "$@" | tee >(cat 1>&2))

	jq -Rr 'fromjson?' <<<"$RESPONSE"
}

check-required-etherscan-api-key() {
	# Require the Etherscan API Key if --verify option is enabled
	set +e
	if grep -- '--verify' <<<"$@" >/dev/null; then
		[ -n "$ETHERSCAN_API_KEY" ] || die "$(err-msg-etherscan-api-key)"
	fi
	set -e
}

usage() {
	cat <<MSG
forge-script.sh [<file>:]<contract> [ --fork-url RPC_URL --broadcast ] [ --sig <signature> ] [ --verify ]

Examples:
    # Simulate running the script
    forge-script.sh MyContract

    # Simulate running the script in a fork
    forge-script.sh MyContract --fork-url http://localhost:8545

    # Broadcast a transaction to the network
    forge-script.sh MyContract --fork-url http://localhost:8545 --broadcast

    # Call a different method in the contract
    forge-script.sh MyContract --sig 'deploy()'
MSG
}

if [ "$0" = "$BASH_SOURCE" ]; then
	[ "$1" = "-h" -o "$1" = "--help" ] && {
		echo -e "\n$(usage)\n"
		exit 0
	}

	run_script "$@"
fi
