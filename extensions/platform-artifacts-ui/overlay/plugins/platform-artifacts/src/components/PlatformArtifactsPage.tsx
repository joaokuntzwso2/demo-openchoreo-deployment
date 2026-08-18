import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Box,
  Card,
  CardActionArea,
  CardContent,
  Chip,
  CircularProgress,
  FormControlLabel,
  Grid,
  IconButton,
  InputAdornment,
  makeStyles,
  MenuItem,
  Paper,
  Select,
  Switch,
  TextField,
  Tooltip,
  Typography,
} from '@material-ui/core';
import SearchIcon from '@material-ui/icons/Search';
import RefreshIcon from '@material-ui/icons/Refresh';
import AccountTreeIcon from '@material-ui/icons/AccountTree';
import SecurityIcon from '@material-ui/icons/Security';
import StorageIcon from '@material-ui/icons/Storage';
import PlaylistAddCheckIcon from '@material-ui/icons/PlaylistAddCheck';
import SettingsEthernetIcon from '@material-ui/icons/SettingsEthernet';
import { Content, ContentHeader, Header, Page, WarningPanel } from '@backstage/core-components';
import { discoveryApiRef, fetchApiRef, useApi } from '@backstage/core-plugin-api';
import { ArtifactDrawer } from './ArtifactDrawer';
import type { PlatformArtifact, PlatformArtifactsResponse } from '../types';

const REFRESH_MS = 12_000;

const useStyles = makeStyles(theme => ({
  hero: {
    marginBottom: theme.spacing(3),
    padding: theme.spacing(2.5),
    border: `1px solid ${theme.palette.divider}`,
    borderRadius: 10,
    background: theme.palette.background.paper,
  },
  controls: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: theme.spacing(1.5),
    alignItems: 'center',
    marginBottom: theme.spacing(3),
  },
  search: { minWidth: 280, flex: '1 1 320px' },
  namespace: { minWidth: 180 },
  kind: { minWidth: 210 },
  metric: { height: '100%', borderTop: `3px solid ${theme.palette.primary.main}` },
  metricContent: { display: 'flex', alignItems: 'center', gap: theme.spacing(1.5) },
  metricNumber: { fontWeight: 700 },
  card: { height: '100%' },
  cardAction: { height: '100%', alignItems: 'stretch' },
  cardContent: { height: '100%', display: 'flex', flexDirection: 'column' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', gap: theme.spacing(1) },
  name: { fontWeight: 600, wordBreak: 'break-word' },
  kindName: { fontFamily: 'monospace', fontSize: '0.75rem' },
  chips: { display: 'flex', flexWrap: 'wrap', gap: theme.spacing(0.75), marginTop: theme.spacing(2) },
  description: { marginTop: theme.spacing(1), flex: 1 },
  footer: { marginTop: theme.spacing(2), color: theme.palette.text.secondary },
  empty: { padding: theme.spacing(6), textAlign: 'center' },
  live: { display: 'inline-flex', alignItems: 'center', gap: theme.spacing(0.75) },
  liveDot: { width: 8, height: 8, borderRadius: '50%', background: theme.palette.success.main },
}));

const categoryIcon = (category: string) => {
  const c = category.toLowerCase();
  if (c.includes('security') || c.includes('access')) return <SecurityIcon />;
  if (c.includes('resource')) return <StorageIcon />;
  if (c.includes('workflow') || c.includes('govern')) return <PlaylistAddCheckIcon />;
  if (c.includes('delivery') || c.includes('observ')) return <SettingsEthernetIcon />;
  return <AccountTreeIcon />;
};

const countBy = (items: PlatformArtifact[], predicate: (a: PlatformArtifact) => boolean) =>
  items.filter(predicate).length;

export const PlatformArtifactsPage = () => {
  const classes = useStyles();
  const discoveryApi = useApi(discoveryApiRef);
  const fetchApi = useApi(fetchApiRef);
  const [namespaceInput, setNamespaceInput] = useState(() => localStorage.getItem('platformArtifacts.namespace') || 'platform-demo');
  const [namespaceName, setNamespaceName] = useState(namespaceInput);
  const [data, setData] = useState<PlatformArtifactsResponse>();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>();
  const [search, setSearch] = useState('');
  const [kind, setKind] = useState('all');
  const [customOnly, setCustomOnly] = useState(true);
  const [selected, setSelected] = useState<PlatformArtifact>();

  const load = useCallback(async (quiet = false) => {
    if (!quiet) setLoading(true);
    try {
      const baseUrl = await discoveryApi.getBaseUrl('platform-artifacts');
      const response = await fetchApi.fetch(`${baseUrl}/artifacts?namespaceName=${encodeURIComponent(namespaceName)}`);
      if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${await response.text()}`);
      const payload = (await response.json()) as PlatformArtifactsResponse;
      setData(payload);
      setError(undefined);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      if (!quiet) setLoading(false);
    }
  }, [discoveryApi, fetchApi, namespaceName]);

  useEffect(() => {
    load(false);
    const timer = window.setInterval(() => load(true), REFRESH_MS);
    return () => window.clearInterval(timer);
  }, [load]);

  const applyNamespace = () => {
    const next = namespaceInput.trim() || 'platform-demo';
    localStorage.setItem('platformArtifacts.namespace', next);
    setNamespaceName(next);
  };

  const all = data?.artifacts ?? [];
  const kinds = useMemo(() => Array.from(new Set(all.map(a => a.kind))).sort(), [all]);
  const filtered = useMemo(() => {
    const needle = search.toLowerCase().trim();
    return all.filter(a => {
      if (customOnly && !a.custom) return false;
      if (kind !== 'all' && a.kind !== kind) return false;
      if (!needle) return true;
      return [a.displayName, a.name, a.kind, a.category, a.description ?? '', a.namespace ?? '']
        .some(value => value.toLowerCase().includes(needle));
    });
  }, [all, customOnly, kind, search]);

  const custom = all.filter(a => a.custom);
  const metrics = [
    ['Golden paths', countBy(custom, a => /ProjectType|ComponentType/.test(a.kind))],
    ['Traits & access', countBy(custom, a => /Trait|Authz/.test(a.kind))],
    ['Managed resources', countBy(custom, a => /Resource(Type)?$/.test(a.kind))],
    ['Workflows & delivery', countBy(custom, a => /Workflow|Pipeline|Environment|NotificationChannel/.test(a.kind))],
  ] as const;

  return (
    <Page themeId="tool">
      <Header title="Platform Artifacts" subtitle="Live OpenChoreo platform engineering definitions" />
      <Content>
        <Box className={classes.hero}>
          <ContentHeader title="Your platform, explained">
            <Box className={classes.live}><span className={classes.liveDot} /><Typography variant="body2">Live · refreshes every 12 seconds</Typography></Box>
          </ContentHeader>
          <Typography color="textSecondary">
            Explore golden paths, Traits, managed resource types, workflows, delivery policy and access-control artifacts as structured platform concepts. The raw Kubernetes/OpenChoreo definition is still available when you need it.
          </Typography>
        </Box>

        <Grid container spacing={2} style={{ marginBottom: 20 }}>
          {metrics.map(([label, value]) => (
            <Grid item xs={12} sm={6} md={3} key={label}>
              <Paper variant="outlined" className={classes.metric}>
                <Box p={2} className={classes.metricContent}>
                  <AccountTreeIcon color="primary" />
                  <Box><Typography variant="h4" className={classes.metricNumber}>{value}</Typography><Typography variant="body2" color="textSecondary">{label}</Typography></Box>
                </Box>
              </Paper>
            </Grid>
          ))}
        </Grid>

        <Box className={classes.controls}>
          <TextField
            className={classes.search}
            variant="outlined"
            size="small"
            placeholder="Search name, kind, category or description"
            value={search}
            onChange={e => setSearch(e.target.value)}
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }}
          />
          <TextField
            className={classes.namespace}
            label="Namespace"
            variant="outlined"
            size="small"
            value={namespaceInput}
            onChange={e => setNamespaceInput(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter') applyNamespace(); }}
            onBlur={applyNamespace}
          />
          <Select className={classes.kind} variant="outlined" value={kind} onChange={e => setKind(String(e.target.value))}>
            <MenuItem value="all">All artifact kinds</MenuItem>
            {kinds.map(value => <MenuItem key={value} value={value}>{value}</MenuItem>)}
          </Select>
          <FormControlLabel control={<Switch checked={customOnly} onChange={e => setCustomOnly(e.target.checked)} color="primary" />} label="Custom only" />
          <Tooltip title="Refresh now"><IconButton onClick={() => load(false)}><RefreshIcon /></IconButton></Tooltip>
        </Box>

        {error && <WarningPanel title="Could not load live OpenChoreo artifacts"><Typography>{error}</Typography></WarningPanel>}
        {data?.warnings?.length ? <WarningPanel title="Some artifact collections could not be read"><Typography component="pre">{data.warnings.join('\n')}</Typography></WarningPanel> : null}

        {loading && !data ? (
          <Box className={classes.empty}><CircularProgress /><Typography style={{ marginTop: 16 }}>Reading live platform definitions…</Typography></Box>
        ) : filtered.length === 0 ? (
          <Paper variant="outlined" className={classes.empty}>
            <Typography variant="h6">No artifacts match this view</Typography>
            <Typography color="textSecondary">
              {customOnly ? 'Turn off “Custom only”, or mark a resource with demo.openchoreo.dev/custom-artifact=true.' : 'Try another search or namespace.'}
            </Typography>
          </Paper>
        ) : (
          <Grid container spacing={2}>
            {filtered.map(artifact => (
              <Grid item xs={12} sm={6} lg={4} key={artifact.id}>
                <Card variant="outlined" className={classes.card}>
                  <CardActionArea className={classes.cardAction} onClick={() => setSelected(artifact)}>
                    <CardContent className={classes.cardContent}>
                      <Box className={classes.cardHeader}>
                        <Box>
                          <Typography className={classes.kindName} color="textSecondary">{artifact.kind}</Typography>
                          <Typography variant="h6" className={classes.name}>{artifact.displayName}</Typography>
                        </Box>
                        <Box color="primary.main">{categoryIcon(artifact.category)}</Box>
                      </Box>
                      <Typography variant="body2" color="textSecondary" className={classes.description}>
                        {artifact.description || `Live ${artifact.kind} definition ${artifact.name}`}
                      </Typography>
                      <Box className={classes.chips}>
                        {artifact.custom ? <Chip size="small" color="primary" label="Custom Platform" /> : <Chip size="small" label="OpenChoreo Native" />}
                        <Chip size="small" label={artifact.category} />
                        <Chip size="small" label={artifact.scope === 'cluster' ? 'Cluster' : artifact.namespace || 'Namespace'} />
                      </Box>
                      <Typography variant="caption" className={classes.footer}>{artifact.name}</Typography>
                    </CardContent>
                  </CardActionArea>
                </Card>
              </Grid>
            ))}
          </Grid>
        )}

        <ArtifactDrawer artifact={selected} onClose={() => setSelected(undefined)} />
      </Content>
    </Page>
  );
};
