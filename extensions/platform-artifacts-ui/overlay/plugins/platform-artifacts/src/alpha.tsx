import React from 'react';
import { createFrontendPlugin, PageBlueprint } from '@backstage/frontend-plugin-api';
import { rootRouteRef } from './routes';

const platformArtifactsPage = PageBlueprint.make({
  name: 'platform-artifacts-page',
  params: {
    path: '/platform-artifacts',
    routeRef: rootRouteRef,
    loader: () =>
      import('./components/PlatformArtifactsPage').then(m => (
        <m.PlatformArtifactsPage />
      )),
  },
});

export default createFrontendPlugin({
  pluginId: 'platform-artifacts',
  routes: { root: rootRouteRef },
  extensions: [platformArtifactsPage],
});
