#!/bin/bash
# TMT: ExecStartPre gate for the OpenBao primary (8200).
# The primary auto-unseals via the transit instance (8201), which is shamir-sealed
# and unsealed MANUALLY after every boot. Without this gate the primary starts before
# the transit is unsealed, exits 1 ("Vault is sealed") and burns the bounded start
# limit in 99-selfheal.conf within ~25s -> systemd marks it `failed` -> needs a manual
# `reset-failed && start`. Instead we WAIT here in start-pre (which does NOT count as a
# crash and does not trip the crash-loop alert) until the transit reports unsealed,
# then let bao start and auto-unseal. Bounded by TimeoutStartSec in the drop-in.
set -euo pipefail
ADDR="${OPENBAO_TRANSIT_ADDR:-https://127.0.0.1:8201}"
# bao status rc: 0 = unsealed/ready, 2 = sealed, 1 = not reachable yet.
while true; do
  if BAO_ADDR="$ADDR" bao status -tls-skip-verify >/dev/null 2>&1; then
    exit 0
  fi
  sleep 5
done
