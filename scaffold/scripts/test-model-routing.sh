#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Test fonctionnel : passage entre modèles sur toute la chaîne
# Teste la création de sessions à chaque niveau hiérarchique
# et vérifie que engine/model sont correctement assignés
# ═══════════════════════════════════════════════════════════════

API="http://0.0.0.0:7778/api"
PASS=0
FAIL=0
SESSIONS=()

green() { printf "\033[32m✓ %s\033[0m\n" "$1"; PASS=$((PASS+1)); }
red()   { printf "\033[31m✗ %s\033[0m\n" "$1"; FAIL=$((FAIL+1)); }
check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then green "$label"; else red "$label (got: $actual, expected: $expected)"; fi
}

echo "═══════════════════════════════════════════════"
echo " Test: Model Routing Across Org Hierarchy"
echo "═══════════════════════════════════════════════"
echo ""

# ── 0. Verify gateway is up ──
STATUS=$(curl -s "$API/status" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
check "Gateway is running" "$STATUS" "ok"

# ── 1. Verify org is loaded with all levels ──
echo ""
echo "── Org Structure ──"

NOXIS_RANK=$(curl -s "$API/org/employees/noxis" | python3 -c "import sys,json; print(json.load(sys.stdin).get('rank',''))" 2>/dev/null)
check "Level 0 — Noxis (executive)" "$NOXIS_RANK" "executive"

PLANNER_RANK=$(curl -s "$API/org/employees/planner" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('rank',''))" 2>/dev/null)
check "Level 1 — Planner (director)" "$PLANNER_RANK" "director"

BUGMASTER_RANK=$(curl -s "$API/org/employees/bugmaster" | python3 -c "import sys,json; print(json.load(sys.stdin).get('rank',''))" 2>/dev/null)
check "Level 1 — Bugmaster (manager)" "$BUGMASTER_RANK" "manager"

IDEATOR_RANK=$(curl -s "$API/org/employees/ideator" | python3 -c "import sys,json; print(json.load(sys.stdin).get('rank',''))" 2>/dev/null)
check "Level 2 — Ideator (lead)" "$IDEATOR_RANK" "lead"

ARTIST_RANK=$(curl -s "$API/org/employees/artist" | python3 -c "import sys,json; print(json.load(sys.stdin).get('rank',''))" 2>/dev/null)
check "Level 3 — Artist (member)" "$ARTIST_RANK" "member"

# ── 2. Verify engine/model per employee ──
echo ""
echo "── Engine/Model Assignment ──"

NOXIS_ENGINE=$(curl -s "$API/org/employees/noxis" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine',''))" 2>/dev/null)
check "Noxis engine = claude" "$NOXIS_ENGINE" "claude"

PLANNER_MODEL=$(curl -s "$API/org/employees/planner" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model',''))" 2>/dev/null)
check "Planner model = claude-sonnet-4-6" "$PLANNER_MODEL" "claude-sonnet-4-6"

BUGMASTER_ENGINE=$(curl -s "$API/org/employees/bugmaster" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine',''))" 2>/dev/null)
BUGMASTER_MODEL=$(curl -s "$API/org/employees/bugmaster" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model',''))" 2>/dev/null)
check "Bugmaster engine = claude" "$BUGMASTER_ENGINE" "claude"

IDEATOR_MODEL=$(curl -s "$API/org/employees/ideator" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model',''))" 2>/dev/null)
check "Ideator model = claude-sonnet-4-6" "$IDEATOR_MODEL" "claude-sonnet-4-6"

# ── 3. Session creation: each level with correct engine/model ──
echo ""
echo "── Session Creation Per Level ──"

# Level 0: Executive session (opus)
S0=$(curl -s -X POST "$API/sessions" -H 'Content-Type: application/json' \
  -d '{"prompt":"test exec session","employee":"noxis"}')
S0_ID=$(echo "$S0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
S0_ENGINE=$(echo "$S0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine',''))" 2>/dev/null)
S0_MODEL=$(echo "$S0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model','') or '')" 2>/dev/null)
S0_EMP=$(echo "$S0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('employee',''))" 2>/dev/null)
SESSIONS+=("$S0_ID")
check "Exec session — employee=noxis" "$S0_EMP" "noxis"
check "Exec session — engine=claude" "$S0_ENGINE" "claude"

# Level 1: Director session (sonnet) — child of executive
S1=$(curl -s -X POST "$API/sessions" -H 'Content-Type: application/json' \
  -d "{\"prompt\":\"test director session\",\"employee\":\"planner\",\"parentSessionId\":\"$S0_ID\"}")
S1_ID=$(echo "$S1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
S1_ENGINE=$(echo "$S1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine',''))" 2>/dev/null)
S1_MODEL=$(echo "$S1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model','') or '')" 2>/dev/null)
S1_PARENT=$(echo "$S1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('parentSessionId','') or '')" 2>/dev/null)
SESSIONS+=("$S1_ID")
check "Director session — employee=planner" "$(echo "$S1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('employee',''))")" "planner"
check "Director session — engine=claude" "$S1_ENGINE" "claude"
check "Director session — model=claude-sonnet-4-6" "$S1_MODEL" "claude-sonnet-4-6"
check "Director session — parent=exec" "$S1_PARENT" "$S0_ID"

# Level 2: Lead session (sonnet) — child of director
S2=$(curl -s -X POST "$API/sessions" -H 'Content-Type: application/json' \
  -d "{\"prompt\":\"test lead session\",\"employee\":\"ideator\",\"parentSessionId\":\"$S1_ID\"}")
S2_ID=$(echo "$S2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
S2_ENGINE=$(echo "$S2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine',''))" 2>/dev/null)
S2_MODEL=$(echo "$S2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model','') or '')" 2>/dev/null)
S2_PARENT=$(echo "$S2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('parentSessionId','') or '')" 2>/dev/null)
SESSIONS+=("$S2_ID")
check "Lead session — employee=ideator" "$(echo "$S2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('employee',''))")" "ideator"
check "Lead session — engine=claude" "$S2_ENGINE" "claude"
check "Lead session — model=claude-sonnet-4-6" "$S2_MODEL" "claude-sonnet-4-6"
check "Lead session — parent=director" "$S2_PARENT" "$S1_ID"

# Level 3: Member session (default) — child of lead
S3=$(curl -s -X POST "$API/sessions" -H 'Content-Type: application/json' \
  -d "{\"prompt\":\"test member session\",\"employee\":\"artist\",\"parentSessionId\":\"$S2_ID\"}")
S3_ID=$(echo "$S3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
S3_ENGINE=$(echo "$S3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine',''))" 2>/dev/null)
S3_PARENT=$(echo "$S3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('parentSessionId','') or '')" 2>/dev/null)
SESSIONS+=("$S3_ID")
check "Member session — employee=artist" "$(echo "$S3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('employee',''))")" "artist"
check "Member session — engine=claude" "$S3_ENGINE" "claude"
check "Member session — parent=lead" "$S3_PARENT" "$S2_ID"

# ── 4. Chain integrity: verify parent→child links ──
echo ""
echo "── Chain Integrity (4 levels) ──"

CHILDREN_0=$(curl -s "$API/sessions/$S0_ID/children" | python3 -c "import sys,json; ids=[s['id'] for s in json.load(sys.stdin)]; print(','.join(ids))" 2>/dev/null)
[[ "$CHILDREN_0" == *"$S1_ID"* ]] && green "Exec children includes director" || red "Exec children missing director"

CHILDREN_1=$(curl -s "$API/sessions/$S1_ID/children" | python3 -c "import sys,json; ids=[s['id'] for s in json.load(sys.stdin)]; print(','.join(ids))" 2>/dev/null)
[[ "$CHILDREN_1" == *"$S2_ID"* ]] && green "Director children includes lead" || red "Director children missing lead"

CHILDREN_2=$(curl -s "$API/sessions/$S2_ID/children" | python3 -c "import sys,json; ids=[s['id'] for s in json.load(sys.stdin)]; print(','.join(ids))" 2>/dev/null)
[[ "$CHILDREN_2" == *"$S3_ID"* ]] && green "Lead children includes member" || red "Lead children missing member"

# ── 5. Cross-engine delegation ──
echo ""
echo "── Cross-Engine Delegation ──"

# Bugmaster uses a different model — child of executive
S_BUG=$(curl -s -X POST "$API/sessions" -H 'Content-Type: application/json' \
  -d "{\"prompt\":\"test cross-engine\",\"employee\":\"bugmaster\",\"parentSessionId\":\"$S0_ID\"}")
S_BUG_ENGINE=$(echo "$S_BUG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine',''))" 2>/dev/null)
S_BUG_MODEL=$(echo "$S_BUG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model','') or '')" 2>/dev/null)
S_BUG_ID=$(echo "$S_BUG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
SESSIONS+=("$S_BUG_ID")
check "Bugmaster session — engine=claude" "$S_BUG_ENGINE" "claude"
check "Bugmaster session — model=claude-sonnet-4-6" "$S_BUG_MODEL" "claude-sonnet-4-6"

# ── 6. Cross-service request ──
echo ""
echo "── Cross-Service Request ──"

CROSS=$(curl -s -X POST "$API/org/cross-request" -H 'Content-Type: application/json' \
  -d '{"fromEmployee":"ironcraft","service":"game-design","prompt":"Need design review"}')
CROSS_TARGET=$(echo "$CROSS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('targetDepartment','') or d.get('error','no endpoint'))" 2>/dev/null)
if [ "$CROSS_TARGET" = "nexamon-studio/design" ]; then
  green "Cross-request routes ironcraft→design (game-design service)"
elif [[ "$CROSS_TARGET" == *"error"* ]] || [[ "$CROSS_TARGET" == *"no endpoint"* ]]; then
  red "Cross-request endpoint not available yet (expected)"
else
  check "Cross-request target department" "$CROSS_TARGET" "nexamon-studio/design"
fi

# ── 7. Services registry ──
echo ""
echo "── Services Registry ──"

SVC_COUNT=$(curl -s "$API/org/services" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('services',d.get('error',[]))))" 2>/dev/null)
if [ "$SVC_COUNT" -gt 0 ] 2>/dev/null; then
  green "Services registry has $SVC_COUNT entries"
else
  red "Services registry empty or endpoint missing"
fi

# ── Cleanup test sessions ──
echo ""
echo "── Cleanup ──"
for sid in "${SESSIONS[@]}"; do
  curl -s -X DELETE "$API/sessions/$sid" > /dev/null 2>&1
done
green "Cleaned up ${#SESSIONS[@]} test sessions"

# ── Summary ──
echo ""
echo "═══════════════════════════════════════════════"
printf " Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n" "$PASS" "$FAIL"
echo "═══════════════════════════════════════════════"

exit $FAIL
