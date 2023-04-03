#!/bin/bash
set -eo pipefail

source "${BASH_SOURCE%/*}/_common.sh"

run-script() {
	normalize-env-vars

	local PASSWORD="$(extract-password)"
	local PASSWORD_OPT=()
	if [ -n "$PASSWORD" ]; then
		PASSWORD_OPT=(--password "$PASSWORD")
	fi

	check-required-etherscan-api-key

	# Log the command being issued, making sure not to expose the password
	log "forge script --json --sender $ETH_FROM --keystores="$FOUNDRY_ETH_KEYSTORE_FILE" $(sed 's/ .*$/ [REDACTED]/' <<<"${PASSWORD_OPT[@]}")" $(printf ' %q' "$@")
	# Currently `forge script` sends the logs to stdout instead of stderr.
	# This makes it hard to compose its output with other commands, so here we are:
	# 1. Duplicating stdout to stderr through `tee`
	# 2. Extracting only the address of the deployed contract to stdout
	forge script --json --sender $ETH_FROM --keystores="$FOUNDRY_ETH_KEYSTORE_FILE" "${PASSWORD_OPT[@]}" "$@"
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
forge-script.sh [<src>:]<contract> [...options]

Examples:

    # simulate deployment
    forge-script.sh script/DeployGoerli.s.sol:Goerli

    # deploy
    forge-script.sh script/DeployGoerli.s.sol:Goerli --broadcast
MSG
}

if [ "$0" = "$BASH_SOURCE" ]; then
	[ "$1" = "-h" -o "$1" = "--help" ] && {
		echo -e "\n$(usage)\n"
		exit 0
	}

	run-script "$@"
fi
