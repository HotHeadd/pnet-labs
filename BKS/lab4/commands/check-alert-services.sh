#!/bin/bash
set -eu
date -Is
systemctl is-active bks4-snmptrap.service bks4-security-alerts.service
sudo ss -lunp 'sport = :162'
