import type { LoggerService } from '@backstage/backend-plugin-api';
import Router from 'express-promise-router';
import type { Request, Response } from 'express';

type Scope = 'cluster' | 'namespace';

type Collection = {
  collection: string;
  kind: string;
  scope: Scope;
  category: string;
  path: (namespaceName: string) => string;
};

const COLLECTIONS: Collection[] = [
  { collection: 'clusterprojecttypes', kind: 'ClusterProjectType', scope: 'cluster', category: 'Golden Path', path: () => '/clusterprojecttypes' },
  { collection: 'clustercomponenttypes', kind: 'ClusterComponentType', scope: 'cluster', category: 'Golden Path', path: () => '/clustercomponenttypes' },
  { collection: 'clustertraits', kind: 'ClusterTrait', scope: 'cluster', category: 'Security & Runtime Policy', path: () => '/clustertraits' },
  { collection: 'clusterresourcetypes', kind: 'ClusterResourceType', scope: 'cluster', category: 'Managed Resource', path: () => '/clusterresourcetypes' },
  { collection: 'clusterworkflows', kind: 'ClusterWorkflow', scope: 'cluster', category: 'Governance Workflow', path: () => '/clusterworkflows' },
  { collection: 'clusterauthzroles', kind: 'ClusterAuthzRole', scope: 'cluster', category: 'Access Control', path: () => '/clusterauthzroles' },
  { collection: 'clusterauthzrolebindings', kind: 'ClusterAuthzRoleBinding', scope: 'cluster', category: 'Access Control', path: () => '/clusterauthzrolebindings' },
  { collection: 'projecttypes', kind: 'ProjectType', scope: 'namespace', category: 'Golden Path', path: ns => `/namespaces/${encodeURIComponent(ns)}/projecttypes` },
  { collection: 'componenttypes', kind: 'ComponentType', scope: 'namespace', category: 'Golden Path', path: ns => `/namespaces/${encodeURIComponent(ns)}/componenttypes` },
  { collection: 'traits', kind: 'Trait', scope: 'namespace', category: 'Security & Runtime Policy', path: ns => `/namespaces/${encodeURIComponent(ns)}/traits` },
  { collection: 'resourcetypes', kind: 'ResourceType', scope: 'namespace', category: 'Managed Resource', path: ns => `/namespaces/${encodeURIComponent(ns)}/resourcetypes` },
  { collection: 'workflows', kind: 'Workflow', scope: 'namespace', category: 'Governance Workflow', path: ns => `/namespaces/${encodeURIComponent(ns)}/workflows` },
  { collection: 'deploymentpipelines', kind: 'DeploymentPipeline', scope: 'namespace', category: 'Delivery', path: ns => `/namespaces/${encodeURIComponent(ns)}/deploymentpipelines` },
  { collection: 'environments', kind: 'Environment', scope: 'namespace', category: 'Delivery Environment', path: ns => `/namespaces/${encodeURIComponent(ns)}/environments` },
  { collection: 'resources', kind: 'Resource', scope: 'namespace', category: 'Managed Resource Instance', path: ns => `/namespaces/${encodeURIComponent(ns)}/resources` },
  { collection: 'observabilityalertsnotificationchannels', kind: 'ObservabilityAlertsNotificationChannel', scope: 'namespace', category: 'Observability', path: ns => `/namespaces/${encodeURIComponent(ns)}/observabilityalertsnotificationchannels` },
  { collection: 'authzroles', kind: 'AuthzRole', scope: 'namespace', category: 'Access Control', path: ns => `/namespaces/${encodeURIComponent(ns)}/authzroles` },
  { collection: 'authzrolebindings', kind: 'AuthzRoleBinding', scope: 'namespace', category: 'Access Control', path: ns => `/namespaces/${encodeURIComponent(ns)}/authzrolebindings` },
];

const CUSTOM_LABEL = 'demo.openchoreo.dev/custom-artifact';
const DISPLAY_ANNOTATION = 'demo.openchoreo.dev/display-name';
const DESCRIPTION_ANNOTATION = 'demo.openchoreo.dev/description';
const CATEGORY_ANNOTATION = 'demo.openchoreo.dev/category';

const record = (value: unknown): Record<string, any> =>
  value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, any> : {};

const getItems = (payload: any): any[] => {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.items)) return payload.items;
  if (Array.isArray(payload?.data?.items)) return payload.data.items;
  if (Array.isArray(payload?.data)) return payload.data;
  return [];
};

const getNextCursor = (payload: any): string | undefined =>
  payload?.pagination?.nextCursor ?? payload?.nextCursor ?? payload?.data?.pagination?.nextCursor ?? payload?.data?.nextCursor;

const getName = (item: any): string | undefined => item?.metadata?.name ?? item?.name;

const titleCase = (value: string) => value
  .replace(/[-_.]+/g, ' ')
  .replace(/\b\w/g, c => c.toUpperCase());

const redactSensitive = (value: unknown, key = ''): unknown => {
  if (/^(authorization|api[-_]?key|token|password|clientsecret|secretvalue)$/i.test(key)) return '***REDACTED***';
  if (Array.isArray(value)) return value.map(item => redactSensitive(item));
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, redactSensitive(v, k)]));
  }
  return value;
};

async function fetchJson(url: string, token?: string) {
  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!response.ok) {
    const body = (await response.text()).slice(0, 500);
    const error = new Error(`${response.status} ${response.statusText}${body ? `: ${body}` : ''}`) as Error & { status?: number };
    error.status = response.status;
    throw error;
  }
  return response.json();
}

async function listCollection(baseUrl: string, collectionPath: string, token?: string) {
  const items: any[] = [];
  let cursor: string | undefined;
  for (let page = 0; page < 20; page += 1) {
    const url = new URL(`${baseUrl}${collectionPath}`);
    url.searchParams.set('limit', '100');
    if (cursor) url.searchParams.set('cursor', cursor);
    const payload = await fetchJson(url.toString(), token);
    items.push(...getItems(payload));
    const next = getNextCursor(payload);
    if (!next || next === cursor) break;
    cursor = next;
  }
  return items;
}

async function fullDefinition(baseUrl: string, collectionPath: string, name: string, fallback: any, token?: string) {
  const definitionAlreadyFull = fallback?.apiVersion && fallback?.kind && fallback?.metadata && fallback?.spec !== undefined;
  if (definitionAlreadyFull) return fallback;
  try {
    return await fetchJson(`${baseUrl}${collectionPath}/${encodeURIComponent(name)}`, token);
  } catch {
    return fallback;
  }
}

export async function createRouter({ logger, baseUrl }: { logger: LoggerService; baseUrl: string }) {
  const router = Router();

  router.get('/health', (_req, res) => res.json({ status: 'ok' }));

  router.get('/artifacts', async (req: Request, res: Response) => {
    const namespaceName = String(req.query.namespaceName || 'platform-demo').trim() || 'platform-demo';
    const tokenHeader = req.header('x-openchoreo-token');
    const token = tokenHeader || undefined;
    const warnings: string[] = [];
    const artifacts: any[] = [];
    let authFailures = 0;

    await Promise.all(COLLECTIONS.map(async collection => {
      const path = collection.path(namespaceName);
      try {
        const listed = await listCollection(baseUrl, path, token);
        const definitions = await Promise.all(listed.map(async item => {
          const name = getName(item);
          if (!name) return undefined;
          const raw = await fullDefinition(baseUrl, path, name, item, token);
          const definition = record(redactSensitive(raw));
          const metadata = record(definition.metadata);
          // Most platform resources use Kubernetes metadata. Authz resources are
          // intentionally normalized as well because their REST list models expose
          // name/namespace/labels at the top level.
          const labels = record(metadata.labels ?? definition.labels) as Record<string, string>;
          const annotations = record(metadata.annotations ?? definition.annotations) as Record<string, string>;
          const actualKind = String(definition.kind || collection.kind);
          const actualNamespace = String(metadata.namespace || definition.namespace || (collection.scope === 'namespace' ? namespaceName : '')) || undefined;
          return {
            id: `${collection.scope}:${actualNamespace || '_cluster'}:${actualKind}:${name}`,
            collection: collection.collection,
            kind: actualKind,
            name,
            namespace: actualNamespace,
            scope: collection.scope,
            displayName: annotations[DISPLAY_ANNOTATION] || annotations['backstage.io/title'] || titleCase(name),
            description: String(annotations[DESCRIPTION_ANNOTATION] || annotations.description || record(definition.spec).description || '' ) || undefined,
            category: annotations[CATEGORY_ANNOTATION] || collection.category,
            custom: labels[CUSTOM_LABEL] === 'true' || annotations[CUSTOM_LABEL] === 'true',
            apiVersion: definition.apiVersion ? String(definition.apiVersion) : undefined,
            labels,
            annotations,
            definition,
          };
        }));
        artifacts.push(...definitions.filter(Boolean));
      } catch (e) {
        const status = (e as any)?.status;
        if (status === 401 || status === 403) authFailures += 1;
        const warning = `${collection.kind}: ${e instanceof Error ? e.message : String(e)}`;
        warnings.push(warning);
        logger.debug(`platform-artifacts collection skipped: ${warning}`);
      }
    }));

    if (artifacts.length === 0 && authFailures === COLLECTIONS.length) {
      res.status(401).json({
        namespaceName,
        generatedAt: new Date().toISOString(),
        artifacts: [],
        warnings,
        error: 'The current OpenChoreo identity could not read any platform artifact collections.',
      });
      return;
    }

    artifacts.sort((a, b) => `${a.category}:${a.kind}:${a.name}`.localeCompare(`${b.category}:${b.kind}:${b.name}`));
    res.json({ namespaceName, generatedAt: new Date().toISOString(), artifacts, warnings });
  });

  return router;
}
