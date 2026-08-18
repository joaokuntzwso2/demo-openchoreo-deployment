import { coreServices, createBackendPlugin } from '@backstage/backend-plugin-api';
import { createRouter } from './router';

export const platformArtifactsPlugin = createBackendPlugin({
  pluginId: 'platform-artifacts',
  register(env) {
    env.registerInit({
      deps: {
        logger: coreServices.logger,
        httpRouter: coreServices.httpRouter,
        config: coreServices.rootConfig,
      },
      async init({ logger, httpRouter, config }) {
        const openchoreo = config.getOptionalConfig('openchoreo');
        if (!openchoreo) {
          logger.warn('platform-artifacts disabled: openchoreo configuration is missing');
          return;
        }
        const baseUrl = openchoreo.getString('baseUrl').replace(/\/$/, '');
        httpRouter.use(await createRouter({ logger, baseUrl }));
      },
    });
  },
});
