import React, { useMemo, useState } from 'react';
import {
  Box,
  Chip,
  Divider,
  Drawer,
  IconButton,
  makeStyles,
  Paper,
  Tab,
  Tabs,
  Table,
  TableBody,
  TableCell,
  TableRow,
  Typography,
} from '@material-ui/core';
import CloseIcon from '@material-ui/icons/Close';
import { CodeSnippet } from '@backstage/core-components';
import YAML from 'yaml';
import type { PlatformArtifact } from '../types';
import { StructuredValue } from './StructuredDefinition';

const useStyles = makeStyles(theme => ({
  paper: { width: 'min(920px, 92vw)' },
  header: { padding: theme.spacing(3), paddingBottom: theme.spacing(2) },
  titleRow: { display: 'flex', justifyContent: 'space-between', gap: theme.spacing(2) },
  chips: { display: 'flex', flexWrap: 'wrap', gap: theme.spacing(1), marginTop: theme.spacing(1.5) },
  body: { padding: theme.spacing(3), overflowY: 'auto' },
  section: { marginBottom: theme.spacing(3) },
  metadataKey: { width: 180, fontWeight: 600, verticalAlign: 'top' },
  empty: { padding: theme.spacing(4), textAlign: 'center', color: theme.palette.text.secondary },
  code: { maxHeight: '60vh', overflow: 'auto' },
  badge: { fontFamily: 'monospace' },
}));

const objectAt = (root: Record<string, unknown>, key: string) => {
  const spec = (root.spec ?? {}) as Record<string, unknown>;
  return spec[key];
};

const parameterSchema = (artifact: PlatformArtifact) => {
  const candidates = [
    objectAt(artifact.definition, 'parameters'),
    objectAt(artifact.definition, 'environmentConfigs'),
  ];
  return candidates.filter(Boolean);
};

const composition = (artifact: PlatformArtifact) => {
  const spec = (artifact.definition.spec ?? {}) as Record<string, unknown>;
  const keys = ['resources', 'traits', 'outputs', 'steps', 'templates', 'workflow', 'environmentConfigs', 'conditions', 'roleMappings', 'actions'];
  const picked: Record<string, unknown> = {};
  for (const key of keys) {
    if (spec[key] !== undefined) picked[key] = spec[key];
  }
  return picked;
};

export const ArtifactDrawer = ({
  artifact,
  onClose,
}: {
  artifact?: PlatformArtifact;
  onClose: () => void;
}) => {
  const classes = useStyles();
  const [tab, setTab] = useState(0);
  const yaml = useMemo(() => artifact ? YAML.stringify(artifact.definition, { lineWidth: 0 }) : '', [artifact]);
  const schemas = useMemo(() => artifact ? parameterSchema(artifact) : [], [artifact]);
  const composed = useMemo(() => artifact ? composition(artifact) : {}, [artifact]);
  const kubectlCommand = artifact
    ? `kubectl get ${artifact.collection} ${artifact.name}${artifact.namespace ? ` -n ${artifact.namespace}` : ''} -o yaml`
    : '';

  return (
    <Drawer anchor="right" open={Boolean(artifact)} onClose={onClose} classes={{ paper: classes.paper }}>
      {artifact && (
        <>
          <Box className={classes.header}>
            <Box className={classes.titleRow}>
              <Box>
                <Typography variant="overline" color="textSecondary">{artifact.kind}</Typography>
                <Typography variant="h4">{artifact.displayName}</Typography>
                {artifact.description && (
                  <Typography variant="body1" color="textSecondary">{artifact.description}</Typography>
                )}
              </Box>
              <IconButton onClick={onClose} aria-label="Close artifact details"><CloseIcon /></IconButton>
            </Box>
            <Box className={classes.chips}>
              {artifact.custom ? <Chip size="small" color="primary" label="Custom Platform" /> : <Chip size="small" label="OpenChoreo Native" />}
              <Chip size="small" label={artifact.category} />
              <Chip size="small" label={artifact.scope === 'cluster' ? 'Cluster scoped' : `Namespace: ${artifact.namespace}`} />
              {artifact.apiVersion && <Chip size="small" className={classes.badge} label={artifact.apiVersion} />}
            </Box>
          </Box>
          <Divider />
          <Tabs value={tab} onChange={(_, next) => setTab(next)} indicatorColor="primary" textColor="primary" variant="scrollable">
            <Tab label="Overview" />
            <Tab label="Parameters" />
            <Tab label="Composition" />
            <Tab label="Structured definition" />
            <Tab label="Raw YAML" />
          </Tabs>
          <Divider />
          <Box className={classes.body}>
            {tab === 0 && (
              <>
                <Paper variant="outlined" className={classes.section}>
                  <Table size="small"><TableBody>
                    <TableRow><TableCell className={classes.metadataKey}>Kind</TableCell><TableCell>{artifact.kind}</TableCell></TableRow>
                    <TableRow><TableCell className={classes.metadataKey}>Name</TableCell><TableCell>{artifact.name}</TableCell></TableRow>
                    <TableRow><TableCell className={classes.metadataKey}>Scope</TableCell><TableCell>{artifact.scope}</TableCell></TableRow>
                    {artifact.namespace && <TableRow><TableCell className={classes.metadataKey}>Namespace</TableCell><TableCell>{artifact.namespace}</TableCell></TableRow>}
                    {artifact.apiVersion && <TableRow><TableCell className={classes.metadataKey}>API version</TableCell><TableCell>{artifact.apiVersion}</TableCell></TableRow>}
                    <TableRow><TableCell className={classes.metadataKey}>Collection</TableCell><TableCell>{artifact.collection}</TableCell></TableRow>
                  </TableBody></Table>
                </Paper>
                <Box mb={3}>
                  <Typography variant="h6" gutterBottom>Equivalent kubectl</Typography>
                  <CodeSnippet text={kubectlCommand} language="bash" />
                </Box>
                <Typography variant="h6" gutterBottom>Labels</Typography>
                {Object.keys(artifact.labels).length ? <StructuredValue value={artifact.labels} /> : <Typography color="textSecondary">No labels</Typography>}
                <Box mt={3}><Typography variant="h6" gutterBottom>Annotations</Typography>
                  {Object.keys(artifact.annotations).length ? <StructuredValue value={artifact.annotations} /> : <Typography color="textSecondary">No annotations</Typography>}
                </Box>
              </>
            )}
            {tab === 1 && (
              schemas.length ? (
                <Box>{schemas.map((schema, index) => (
                  <Box key={index} className={classes.section}>
                    <Typography variant="h6" gutterBottom>{index === 0 ? 'Parameters' : `Parameter schema ${index + 1}`}</Typography>
                    <StructuredValue value={schema} />
                  </Box>
                ))}</Box>
              ) : <Box className={classes.empty}>This artifact does not declare a parameter schema.</Box>
            )}
            {tab === 2 && (
              Object.keys(composed).length ? <StructuredValue value={composed} /> : <Box className={classes.empty}>No composition-oriented fields were detected.</Box>
            )}
            {tab === 3 && <StructuredValue value={artifact.definition} />}
            {tab === 4 && <Box className={classes.code}><CodeSnippet text={yaml} language="yaml" showLineNumbers customStyle={{ fontSize: '0.82rem' }} /></Box>}
          </Box>
        </>
      )}
    </Drawer>
  );
};
