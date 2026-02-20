#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-ckad-reto}"

echo "== NS =="
kubectl get ns "$NS"

echo "== WORKLOADS =="
kubectl -n "$NS" get deploy,po,svc,ingress || true

echo "== CONFIG =="
kubectl -n "$NS" get cm,secret || true

echo "== SECURITY/NET =="
kubectl -n "$NS" get networkpolicy,sa,role,rolebinding || true

echo "== BATCH =="
kubectl -n "$NS" get job,cronjob || true

echo "== STORAGE =="
kubectl -n "$NS" get pvc || true

echo "OK"
