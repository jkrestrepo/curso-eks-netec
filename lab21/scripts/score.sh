#!/usr/bin/env bash
set -u

NS="${NS:-ckad-reto}"

PASS=0
TOTAL=100

say() { printf "%s\n" "$*"; }
ok()  { say "✅ $*"; }
bad() { say "❌ $*"; }
note(){ say "ℹ️  $*"; }

add() { PASS=$((PASS + $1)); }

exists_ns() { kubectl get ns "$1" >/dev/null 2>&1; }
exists() { kubectl -n "$NS" get "$1" "$2" >/dev/null 2>&1; }

score_item() {
  local pts="$1" name="$2" cmd="$3"
  if eval "$cmd" >/dev/null 2>&1; then
    add "$pts"; ok "[$pts] $name"
  else
    bad "[$pts] $name"
  fi
}

say "===== CKAD RETO SCORE ====="
say "Namespace: $NS"
say "Generated: $(date -Iseconds)"
say

# =========================
# R1 (4 pts): namespace + contexto
# =========================
score_item 2 "R1: Namespace exists" "exists_ns $NS"
# namespace en contexto (si no está, suele salir vacío)
CTX_NS="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)"
if [[ "$CTX_NS" == "$NS" ]]; then
  add 2; ok "[2] R1: Context namespace is $NS"
else
  bad "[2] R1: Context namespace is '$CTX_NS' (expected '$NS')"
fi

# =========================
# R2 (12 pts): Deployment listo con 2 réplicas
# =========================
score_item 4 "R2: Deployment webapp exists" "exists deploy webapp"
if exists deploy webapp; then
  READY="$(kubectl -n "$NS" get deploy webapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
  if [[ "${READY:-0}" =~ ^[0-9]+$ ]] && (( READY >= 2 )); then
    add 8; ok "[8] R2: webapp readyReplicas >= 2 (readyReplicas=$READY)"
  else
    bad "[8] R2: webapp readyReplicas >= 2 (readyReplicas=${READY:-0})"
  fi
else
  bad "[8] R2: webapp readyReplicas (deployment missing)"
fi

# =========================
# R3 (6 pts): Service correcto
# =========================
score_item 4 "R3: Service webapp-svc exists" "exists svc webapp-svc"
if exists svc webapp-svc; then
  PORT="$(kubectl -n "$NS" get svc webapp-svc -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"
  TPORT="$(kubectl -n "$NS" get svc webapp-svc -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || true)"
  # targetPort vacío equivale a port; aceptamos 80/80 o 80/(vacío)
  if [[ "$PORT" == "80" && ( "$TPORT" == "80" || -z "$TPORT" ) ]]; then
    add 2; ok "[2] R3: Service port 80 -> targetPort 80"
  else
    bad "[2] R3: Service port/targetPort expected 80/80 (got ${PORT:-?}/${TPORT:-empty})"
  fi
else
  bad "[2] R3: Service port check (service missing)"
fi

# =========================
# R4 (10 pts): ConfigMap + Secret consumidos
# =========================
score_item 2 "R4: ConfigMap app-config exists" "exists cm app-config"
score_item 2 "R4: Secret app-secret exists" "exists secret app-secret"

if exists deploy webapp; then
  # envFrom contiene app-config
  CMREFS="$(kubectl -n "$NS" get deploy webapp -o jsonpath='{range .spec.template.spec.containers[0].envFrom[*]}{.configMapRef.name}{" "}{end}' 2>/dev/null || true)"
  if echo "$CMREFS" | grep -qw "app-config"; then
    add 3; ok "[3] R4: Deployment envFrom includes app-config"
  else
    bad "[3] R4: Deployment envFrom includes app-config"
  fi

  # volumen secretName incluye app-secret
  SECRETS="$(kubectl -n "$NS" get deploy webapp -o jsonpath='{.spec.template.spec.volumes[*].secret.secretName}' 2>/dev/null || true)"
  MOUNTS="$(kubectl -n "$NS" get deploy webapp -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].mountPath}' 2>/dev/null || true)"
  if echo "$SECRETS" | grep -qw "app-secret" && echo "$MOUNTS" | grep -qw "/etc/secret"; then
    add 3; ok "[3] R4: app-secret volume + mounted at /etc/secret"
  else
    bad "[3] R4: app-secret volume + mounted at /etc/secret"
  fi
else
  bad "[3] R4: Deployment checks (deployment missing)"
  bad "[3] R4: Secret mount checks (deployment missing)"
fi

# =========================
# R5 (6 pts): Probes
# =========================
if exists deploy webapp; then
  RPATH="$(kubectl -n "$NS" get deploy webapp -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null || true)"
  LPATH="$(kubectl -n "$NS" get deploy webapp -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null || true)"
  RPORT="$(kubectl -n "$NS" get deploy webapp -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null || true)"
  LPORT="$(kubectl -n "$NS" get deploy webapp -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}' 2>/dev/null || true)"

  if [[ "$RPATH" == "/" && "$RPORT" == "80" ]]; then add 3; ok "[3] R5: readinessProbe httpGet /:80"; else bad "[3] R5: readinessProbe httpGet /:80"; fi
  if [[ "$LPATH" == "/" && "$LPORT" == "80" ]]; then add 3; ok "[3] R5: livenessProbe httpGet /:80"; else bad "[3] R5: livenessProbe httpGet /:80"; fi
else
  bad "[3] R5: readinessProbe (deployment missing)"
  bad "[3] R5: livenessProbe (deployment missing)"
fi

# =========================
# R6 (8 pts): Rollout history >=2
# =========================
if exists deploy webapp; then
  REVCOUNT="$(kubectl -n "$NS" rollout history deploy/webapp 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {c++} END{print c+0}')"
  if [[ "${REVCOUNT:-0}" =~ ^[0-9]+$ ]] && (( REVCOUNT >= 2 )); then
    add 8; ok "[8] R6: rollout history has >=2 revisions"
  else
    bad "[8] R6: rollout history has >=2 revisions (found ${REVCOUNT:-0})"
  fi
else
  bad "[8] R6: rollout history (deployment missing)"
fi

# =========================
# R7 (10 pts): Sidecar
# =========================
score_item 4 "R7: sidecar-demo pod exists" "exists pod sidecar-demo"
if exists pod sidecar-demo; then
  NAMES="$(kubectl -n "$NS" get pod sidecar-demo -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)"
  if echo "$NAMES" | grep -qw "app" && echo "$NAMES" | grep -qw "sidecar"; then
    add 3; ok "[3] R7: pod has containers app + sidecar"
  else
    bad "[3] R7: pod has containers app + sidecar"
  fi

  if kubectl -n "$NS" logs sidecar-demo -c sidecar --tail=50 2>/dev/null | grep -qi 'msg'; then
    add 3; ok "[3] R7: sidecar logs contain 'msg'"
  else
    bad "[3] R7: sidecar logs contain 'msg'"
  fi
else
  bad "[3] R7: container names check (pod missing)"
  bad "[3] R7: sidecar logs check (pod missing)"
fi

# =========================
# R8 (6 pts): Ingress
# =========================
score_item 4 "R8: Ingress webapp-ing exists" "exists ingress webapp-ing"
if exists ingress webapp-ing; then
  HOST="$(kubectl -n "$NS" get ingress webapp-ing -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  SVCN="$(kubectl -n "$NS" get ingress webapp-ing -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || true)"
  SVCP="$(kubectl -n "$NS" get ingress webapp-ing -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || true)"
  if [[ "$HOST" == "webapp.ckad.local" && "$SVCN" == "webapp-svc" && "$SVCP" == "80" ]]; then
    add 2; ok "[2] R8: host+backend correct"
  else
    bad "[2] R8: expected webapp.ckad.local -> webapp-svc:80 (got $HOST -> $SVCN:$SVCP)"
  fi
else
  bad "[2] R8: host+backend check (ingress missing)"
fi

# =========================
# R9 (6 pts): NetPol (YAML existence)
# =========================
score_item 3 "R9: NetPol deny exists" "exists networkpolicy webapp-deny-ingress"
score_item 3 "R9: NetPol allow exists" "exists networkpolicy webapp-allow-from-tester"
note "R9: enforcement depende del CNI; aquí solo evaluamos existencia/estructura básica."

# =========================
# R10 (8 pts): Job/CronJob
# =========================
if exists job pi; then
  if kubectl -n "$NS" get job pi -o jsonpath='{.status.succeeded}' 2>/dev/null | grep -qE '^[1-9]'; then
    add 4; ok "[4] R10: Job pi succeeded"
  else
    bad "[4] R10: Job pi succeeded"
  fi
else
  bad "[4] R10: Job pi exists"
fi

score_item 2 "R10: CronJob heartbeat exists" "exists cronjob heartbeat"
if exists cronjob heartbeat; then
  SCHED="$(kubectl -n "$NS" get cronjob heartbeat -o jsonpath='{.spec.schedule}' 2>/dev/null || true)"
  if [[ "$SCHED" == "*/1 * * * *" ]]; then
    add 2; ok "[2] R10: heartbeat schedule is */1 * * * *"
  else
    bad "[2] R10: heartbeat schedule is */1 * * * * (got '$SCHED')"
  fi
  if kubectl -n "$NS" get jobs 2>/dev/null | awk '{print $1}' | grep -q '^heartbeat-'; then
    add 0; ok "[0] R10: heartbeat has created jobs (info)"
  fi
else
  bad "[2] R10: heartbeat schedule check (cronjob missing)"
fi

# =========================
# R11 (10 pts): PVC
# =========================
if exists pvc data-pvc; then
  PHASE="$(kubectl -n "$NS" get pvc data-pvc -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "$PHASE" == "Bound" ]]; then
    add 6; ok "[6] R11: PVC data-pvc is Bound"
  else
    bad "[6] R11: PVC data-pvc is Bound (phase=$PHASE)"
  fi
else
  bad "[6] R11: PVC data-pvc exists"
fi

if exists pod pvc-writer; then
  if kubectl -n "$NS" exec pvc-writer -- sh -c 'test -f /data/hello.txt' >/dev/null 2>&1; then
    add 4; ok "[4] R11: pvc-writer wrote /data/hello.txt"
  else
    bad "[4] R11: pvc-writer wrote /data/hello.txt"
  fi
else
  bad "[4] R11: pvc-writer pod exists"
fi

# =========================
# R12 (14 pts): RBAC
# =========================
score_item 2 "R12: ServiceAccount app-sa exists" "exists sa app-sa"
score_item 2 "R12: Role app-reader exists" "exists role app-reader"
score_item 2 "R12: RoleBinding app-reader-binding exists" "exists rolebinding app-reader-binding"

if kubectl -n "$NS" auth can-i list pods --as="system:serviceaccount:$NS:app-sa" 2>/dev/null | grep -qi '^yes$'; then
  add 3; ok "[3] R12: can list pods"
else
  bad "[3] R12: can list pods"
fi

if kubectl -n "$NS" auth can-i delete pods --as="system:serviceaccount:$NS:app-sa" 2>/dev/null | grep -qi '^no$'; then
  add 3; ok "[3] R12: cannot delete pods (least privilege)"
else
  bad "[3] R12: cannot delete pods (should be no)"
fi

if kubectl -n "$NS" auth can-i get pods --subresource=log --as="system:serviceaccount:$NS:app-sa" 2>/dev/null | grep -qi '^yes$'; then
  add 4; ok "[4] R12: can get pods/log"
else
  bad "[4] R12: can get pods/log"
fi

say
say "===== SCORE ====="
say "Total: $PASS / $TOTAL"
if (( PASS == TOTAL )); then
  say "Result: PERFECT ✅"
elif (( PASS >= 80 )); then
  say "Result: PASS ✅ (>=80)"
else
  say "Result: NEEDS WORK ❌ (<80)"
fi
