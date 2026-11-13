#!/usr/bin/env bash
# Fake agent: touches a protected path under .agents/ (must be flagged even if listed).
mkdir -p .agents
echo x > .agents/hooks.json
