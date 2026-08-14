#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${OPENCHOREO_NAMESPACE:-platform-demo}"
CLUSTER="${K3D_CLUSTER_NAME:-openchoreo}"

log(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn(){ printf '\n\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die(){ printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

demo_context(){ printf 'k3d-%s' "$CLUSTER"; }

ensure_demo_context(){
  local ctx current
  ctx="$(demo_context)"
  kubectl config get-contexts -o name 2>/dev/null | grep -Fxq "$ctx" \
    || die "Kubernetes context $ctx does not exist. Run ./demo.sh up (fresh install) or ./demo.sh reset (clean rebuild)."
  current="$(kubectl config current-context 2>/dev/null || true)"
  if [[ "$current" != "$ctx" ]]; then
    warn "Switching kubectl context from ${current:-<none>} to $ctx"
    kubectl config use-context "$ctx" >/dev/null
  fi
}

wait_exists(){
  local kind="$1" name="$2" ns="${3:-$NS}" timeout="${4:-120}" start=$SECONDS
  while (( SECONDS - start < timeout )); do
    kubectl get "$kind/$name" -n "$ns" >/dev/null 2>&1 && return 0
    sleep 2
  done
  warn "$kind/$name was not created in namespace $ns within ${timeout}s"
  return 1
}

print_conditions(){
  local kind="$1" name="$2" ns="${3:-$NS}"
  kubectl get "$kind/$name" -n "$ns" -o json 2>/dev/null | python3 -c '
import json,sys
try: x=json.load(sys.stdin)
except Exception: raise SystemExit(0)
print("  generation={} observedGeneration={}".format(x.get("metadata",{}).get("generation"), x.get("status",{}).get("observedGeneration")))
for c in x.get("status",{}).get("conditions",[]) or []:
    print("  {}: {} reason={} message={}".format(c.get("type"), c.get("status"), c.get("reason","") or "-", c.get("message","") or "-"))
' || true
}

wait_ready(){
  local kind="$1" name="$2" ns="${3:-$NS}" timeout="${4:-300}" start=$SECONDS last_report=0
  wait_exists "$kind" "$name" "$ns" "$timeout" || return 1
  while (( SECONDS - start < timeout )); do
    if kubectl get "$kind/$name" -n "$ns" -o json 2>/dev/null | python3 -c '
import json,sys
x=json.load(sys.stdin)
gen=x.get("metadata",{}).get("generation",0) or 0
obs=x.get("status",{}).get("observedGeneration")
ready=any(c.get("type")=="Ready" and c.get("status")=="True" for c in (x.get("status",{}).get("conditions") or []))
current=(obs is None or int(obs) >= int(gen))
raise SystemExit(0 if ready and current else 1)
'; then
      return 0
    fi
    if (( SECONDS - last_report >= 20 )); then
      printf '  waiting for %s/%s ... (%ss)\n' "$kind" "$name" "$((SECONDS-start))"
      print_conditions "$kind" "$name" "$ns"
      last_report=$SECONDS
    fi
    sleep 2
  done
  warn "$kind/$name did not reconcile Ready for its current generation within ${timeout}s"
  print_conditions "$kind" "$name" "$ns"
  kubectl describe "$kind/$name" -n "$ns" 2>/dev/null | tail -n 45 >&2 || true
  return 1
}

project_binding_matrix(){
  kubectl get projectreleasebinding -n "$NS" -o json | python3 -c '
import json,sys
D=json.load(sys.stdin)
want={f"{p}-{e}" for p in ["experience","payments","risk","customer","compliance","telco-core","telco-network","telco-commercial","telco-experience","platform-ops"] for e in ["development","staging","production"]}
print("{:<42} {:<28} {:<9} {:<11} {:<11} {:<9} {}".format(
    "BINDING", "RELEASE", "SYNCED", "NAMESPACE", "RESOURCES", "READY", "REASON / MESSAGE"
))
print("-"*145)
for x in sorted(D.get("items",[]), key=lambda z:z["metadata"]["name"]):
    n=x["metadata"]["name"]
    if n not in want: continue
    cond={c.get("type"):c for c in x.get("status",{}).get("conditions",[]) or []}
    def s(t): return (cond.get(t) or {}).get("status","-")
    bad=next((cond[t] for t in ["Synced","NamespaceReady","ResourcesReady","Ready"] if t in cond and cond[t].get("status")!="True"), {})
    detail=((bad.get("reason") or "-")+": "+(bad.get("message") or "-")).replace("\n"," ")
    rel=x.get("spec",{}).get("projectRelease") or "<unset>"
    print("{:<42} {:<28} {:<9} {:<11} {:<11} {:<9} {}".format(
        n, rel, s("Synced"), s("NamespaceReady"), s("ResourcesReady"), s("Ready"), detail[:110]
    ))
'
}

auto_pin_project_bindings(){
  local timeout="${1:-240}" start=$SECONDS
  local p e latest current missing
  local projects=(experience payments risk customer compliance telco-core telco-network telco-commercial telco-experience platform-ops)
  local envs=(development staging production)

  while (( SECONDS - start < timeout )); do
    missing=0

    for p in "${projects[@]}"; do
      latest="$(kubectl get project "$p" -n "$NS" -o jsonpath='{.status.latestRelease.name}' 2>/dev/null || true)"
      if [[ -z "$latest" ]]; then
        missing=$((missing + 3))
        continue
      fi

      for e in "${envs[@]}"; do
        current="$(kubectl get projectreleasebinding "${p}-${e}" -n "$NS" -o jsonpath='{.spec.projectRelease}' 2>/dev/null || true)"
        if [[ -z "$current" ]]; then
          kubectl patch projectreleasebinding "${p}-${e}" -n "$NS" --type=merge \
            -p "{\"spec\":{\"projectRelease\":\"$latest\"}}" >/dev/null
          current="$latest"
        fi
        [[ -n "$current" ]] || missing=$((missing + 1))
      done
    done

    if (( missing == 0 )); then
      log "All 30 ProjectReleaseBindings are pinned"
      return 0
    fi

    printf '  waiting for ProjectReleases / pins: %d binding(s) still unresolved after %ss\n' \
      "$missing" "$((SECONDS-start))"
    sleep 3
  done

  warn "Project releases/bindings did not become pinnable within ${timeout}s"
  printf '\nProjects and latest releases:\n' >&2
  kubectl get project -n "$NS" -o custom-columns='NAME:.metadata.name,LATEST:.status.latestRelease.name' >&2 || true
  printf '\nProjectReleaseBindings:\n' >&2
  kubectl get projectreleasebinding -n "$NS" >&2 || true
  return 1
}

wait_all_project_cells(){
  local timeout="${1:-240}" start=$SECONDS last_report=0
  local expected=30
  while (( SECONDS - start < timeout )); do
    local state
    state="$(kubectl get projectreleasebinding -n "$NS" -o json | python3 -c '
import json,sys
D=json.load(sys.stdin)
want={f"{p}-{e}" for p in ["experience","payments","risk","customer","compliance","telco-core","telco-network","telco-commercial","telco-experience","platform-ops"] for e in ["development","staging","production"]}
ready=0; present=0
for x in D.get("items",[]):
    if x["metadata"]["name"] not in want: continue
    present+=1
    gen=x.get("metadata",{}).get("generation",0) or 0
    obs=x.get("status",{}).get("observedGeneration")
    c={q.get("type"):q for q in x.get("status",{}).get("conditions",[]) or []}
    current=(obs is None or int(obs)>=int(gen))
    if current and (c.get("Ready") or {}).get("status")=="True": ready+=1
print(f"{present} {ready}")
')"
    local present="${state%% *}" ready="${state##* }"
    if [[ "$present" == "$expected" && "$ready" == "$expected" ]]; then
      log "All 30 project cells are Ready"
      project_binding_matrix
      return 0
    fi
    if (( SECONDS - last_report >= 10 )); then
      printf '\nProject cells: %s/%s Ready after %ss\n' "$ready" "$expected" "$((SECONDS-start))"
      project_binding_matrix
      last_report=$SECONDS
    fi
    sleep 5
  done
  warn "Project cells did not all become Ready within ${timeout}s"
  project_binding_matrix
  printf '\nRenderedReleases related to project cells:\n' >&2
  kubectl get renderedrelease -A 2>/dev/null || true
  printf '\nRecent controller warnings/errors:\n' >&2
  kubectl logs -n openchoreo-control-plane deploy/controller-manager --since=10m 2>/dev/null | grep -Ei 'error|failed|projectrelease|renderedrelease' | tail -n 120 >&2 || true
  return 1
}

latest_resource_release(){
  kubectl get resource "$1" -n "$NS" -o jsonpath='{.status.latestRelease.name}' 2>/dev/null || true
}

pin_resource(){
  local resource="$1" env="$2" rel="" start=$SECONDS
  wait_exists resource "$resource" "$NS" 120 || return 1
  while (( SECONDS - start < 180 )); do
    rel="$(latest_resource_release "$resource")"
    [[ -n "$rel" ]] && break
    sleep 2
  done
  [[ -n "$rel" ]] || die "No ResourceRelease generated for $resource"
  wait_exists resourcereleasebinding "${resource}-${env}" "$NS" 120 || return 1
  log "Pinning $resource/$env to $rel"
  kubectl patch resourcereleasebinding "${resource}-${env}" -n "$NS" --type=merge \
    -p "{\"spec\":{\"resourceRelease\":\"$rel\"}}" >/dev/null
  wait_ready resourcereleasebinding "${resource}-${env}" "$NS" 300
}

external_url(){
  local component="$1"
  kubectl get httproute -A -o json | python3 -c '
import json,sys
component=sys.argv[1]; d=json.load(sys.stdin)
for x in d.get("items",[]):
    meta=x.get("metadata",{}); labels=meta.get("labels",{}); name=meta.get("name","")
    if component not in name and component not in json.dumps(labels): continue
    spec=x.get("spec",{}); hosts=spec.get("hostnames") or []
    if not hosts: continue
    path="/"; rules=spec.get("rules") or []
    if rules:
      matches=rules[0].get("matches") or []
      if matches: path=(matches[0].get("path") or {}).get("value") or "/"
    print(f"http://{hosts[0]}:19080{path.rstrip(chr(47))}")
    break
' "$component"
}
