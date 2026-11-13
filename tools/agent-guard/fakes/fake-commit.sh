#!/usr/bin/env bash
# Fake agent: commits an allowlisted change (must be flagged: HEAD moved).
echo ok > allowed.txt
git add allowed.txt
git -c user.email=test@example.com -c user.name=guard-test commit -qm "agent commit"
