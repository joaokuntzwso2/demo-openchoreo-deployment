export type ArtifactScope = 'cluster' | 'namespace';

export interface PlatformArtifact {
  id: string;
  collection: string;
  kind: string;
  name: string;
  namespace?: string;
  scope: ArtifactScope;
  displayName: string;
  description?: string;
  category: string;
  custom: boolean;
  apiVersion?: string;
  labels: Record<string, string>;
  annotations: Record<string, string>;
  definition: Record<string, unknown>;
}

export interface PlatformArtifactsResponse {
  namespaceName: string;
  generatedAt: string;
  artifacts: PlatformArtifact[];
  warnings: string[];
}
