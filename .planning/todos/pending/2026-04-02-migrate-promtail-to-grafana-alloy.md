---
created: 2026-04-02T22:03:23.061Z
title: Migrate Promtail to Grafana Alloy
area: general
files:
  - ansible/inventory/group_vars/monitoring_servers/promtail.yml
  - ansible/inventory/group_vars/monitoring_servers/loki.yml
  - ansible/playbooks/monitoring.yml
---

## Problem

Loki 3.7.1 is already installed on the server. Promtail was removed from Loki 3.x releases — `promtail_3.7.1_arm64.deb` does not exist on GitHub (returns "Not found"). The `grafana.grafana.promtail` Ansible role attempts to download the `.deb` from GitHub releases and fails with a corrupt package error.

Downgrading Loki to 2.9.14 is an option but wastes the already-installed 3.7.1 and puts us on an EOL path.

## Solution

Replace Promtail with Grafana Alloy, the official successor:

1. Remove `grafana.grafana.promtail` role from the monitoring playbook
2. Add `grafana.grafana.alloy` role (already in the `grafana.grafana` collection)
3. Rewrite the scrape config from Promtail YAML format to Alloy's River syntax
4. Update `ansible/inventory/group_vars/monitoring_servers/` — remove `promtail.yml`, add `alloy.yml`
5. Verify Alloy ships logs to Loki at `http://127.0.0.1:3100/loki/api/v1/push`

Alloy handles the same log sources (syslog, auth, nginx, php-fpm, mariadb, wordpress, fail2ban) using `local.file_match` + `loki.source.file` + `loki.write` components in River syntax.

Reference: https://grafana.com/docs/alloy/latest/reference/components/
