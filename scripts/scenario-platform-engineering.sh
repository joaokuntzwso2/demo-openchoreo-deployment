#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl
ensure_demo_context

heading(){ printf '\n============================================================\n%s\n============================================================\n' "$1"; }

heading "OPENCHOREO DEPLOYMENT PIPELINE"
kubectl get deploymentpipeline platform-standard -n "$NS" -o yaml | sed -n '1,140p'

heading "CLUSTER-SCOPED GOLDEN PATH"
kubectl get clustercomponenttype regulated-service -o jsonpath='name={.metadata.name}{"\n"}workloadType={.spec.workloadType}{"\n"}{range .spec.traits[*]}embeddedTrait={.name} instance={.instanceName}{"\n"}{end}{range .spec.allowedWorkflows[*]}allowedWorkflow={.name}{"\n"}{end}'

echo
heading "BANK RUNTIME HARDENING CLUSTERTRAIT"
kubectl get clustertrait bank-runtime-hardening -o jsonpath='name={.metadata.name}{"\n"}{range .spec.patches[*]}patchTarget={.target.kind}{"\n"}{end}{range .spec.creates[*]}creates={.template.kind}{"\n"}{end}'

echo
heading "REGULATED RELEASE CLUSTERWORKFLOW"
kubectl get clusterworkflow regulated-release-gate -o jsonpath='name={.metadata.name}{"\n"}workflowPlane={.spec.workflowPlaneRef.name}{"\n"}ttl={.spec.ttlAfterCompletion}{"\n"}'

echo
heading "PAYMENTS COMPONENT / GOLDEN PATH"
ctype="$(kubectl get component payments-service -n "$NS" -o jsonpath='{.spec.componentType.name}')"
kubectl get component payments-service -n "$NS" -o jsonpath='component={.metadata.name}{"\n"}project={.spec.owner.projectName}{"\n"}componentType={.spec.componentType.name}{"\n"}latestRelease={.status.latestRelease.name}{"\n"}'

if [[ "$ctype" == "deployment/regulated-service" ]]; then
  echo
  heading "RENDERED KUBERNETES SECURITY EVIDENCE"
  dpns="$(kubectl get deploy -A -l openchoreo.dev/component=payments-service -o jsonpath='{.items[0].metadata.namespace}')"
  deploy="$(kubectl get deploy -n "$dpns" -l openchoreo.dev/component=payments-service -o jsonpath='{.items[0].metadata.name}')"
  [[ -n "$dpns" && -n "$deploy" ]] || die "Could not locate rendered payments-service Deployment"
  kubectl get deploy "$deploy" -n "$dpns" -o jsonpath='namespace={.metadata.namespace}{"\n"}deployment={.metadata.name}{"\n"}complianceProfile={.spec.template.metadata.annotations.platform\.openchoreo\.dev/compliance-profile}{"\n"}managedBaseline={.spec.template.metadata.annotations.platform\.openchoreo\.dev/managed-security-baseline}{"\n"}automountServiceAccountToken={.spec.template.spec.automountServiceAccountToken}{"\n"}seccomp={.spec.template.spec.securityContext.seccompProfile.type}{"\n"}{range .spec.template.spec.containers[?(@.name=="main")]}allowPrivilegeEscalation={.securityContext.allowPrivilegeEscalation}{"\n"}droppedCapabilities={.securityContext.capabilities.drop}{"\n"}{end}'
  echo
  kubectl get pdb -n "$dpns" -l openchoreo.dev/component=payments-service -o custom-columns='NAME:.metadata.name,MANAGED-BY:.metadata.annotations.platform\.openchoreo\.dev/managed-by-trait,MAX-UNAVAILABLE:.spec.maxUnavailable' || true
else
  echo
  echo "INFO: This live payments-service predates the golden-path upgrade and its componentType is immutable."
  echo "INFO: Repository desired state is deployment/regulated-service; run ./scripts/verify-platform-engineering.sh for canary proof or ./demo.sh reset to enact the migration cleanly."
fi
