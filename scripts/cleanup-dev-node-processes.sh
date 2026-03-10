#!/bin/bash
# Dev node process cleanup - kills zombie node processes from tests, lint, and build
# Run after pnpm test, pnpm lint, or pnpm build to free RAM and reduce CPU usage

pkill -f vitest 2>/dev/null || true
pkill -f vac-vitest 2>/dev/null || true
pkill -f tinypool 2>/dev/null || true
pkill -f "node.*vitest" 2>/dev/null || true
pkill -f "pnpm lint:check" 2>/dev/null || true
pkill -f "turbo run lint:check" 2>/dev/null || true
pkill -f "node_modules.*eslint/bin/eslint" 2>/dev/null || true
pkill -f "vac-vite build" 2>/dev/null || true
pkill -f "node.*vite" 2>/dev/null || true
