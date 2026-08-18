import React from 'react';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Box,
  Chip,
  makeStyles,
  Table,
  TableBody,
  TableCell,
  TableRow,
  Typography,
} from '@material-ui/core';
import ExpandMoreIcon from '@material-ui/icons/ExpandMore';

const useStyles = makeStyles(theme => ({
  accordion: {
    boxShadow: 'none',
    border: `1px solid ${theme.palette.divider}`,
    '&:before': { display: 'none' },
    '& + &': { marginTop: theme.spacing(1) },
  },
  summary: {
    minHeight: 44,
    background: theme.palette.background.default,
    '&$expanded': { minHeight: 44 },
  },
  expanded: {},
  details: {
    display: 'block',
    paddingTop: 0,
  },
  key: {
    fontWeight: 600,
    width: 220,
    verticalAlign: 'top',
  },
  primitive: {
    fontFamily: 'monospace',
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-word',
  },
  array: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: theme.spacing(0.75),
  },
}));

const isPrimitive = (value: unknown) =>
  value === null || ['string', 'number', 'boolean'].includes(typeof value);

const primitiveText = (value: unknown) => {
  if (value === null) return 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  return String(value);
};

export const StructuredValue = ({
  value,
  depth = 0,
}: {
  value: unknown;
  depth?: number;
}) => {
  const classes = useStyles();

  if (isPrimitive(value)) {
    return <span className={classes.primitive}>{primitiveText(value)}</span>;
  }

  if (Array.isArray(value)) {
    if (value.length === 0) return <Typography color="textSecondary">Empty list</Typography>;
    if (value.every(isPrimitive) && value.length <= 12) {
      return (
        <Box className={classes.array}>
          {value.map((item, index) => (
            <Chip key={`${index}-${primitiveText(item)}`} size="small" label={primitiveText(item)} />
          ))}
        </Box>
      );
    }
    return (
      <Box>
        {value.map((item, index) => (
          <Accordion key={index} className={classes.accordion} defaultExpanded={depth < 1}>
            <AccordionSummary
              expandIcon={<ExpandMoreIcon />}
              classes={{ root: classes.summary, expanded: classes.expanded }}
            >
              <Typography variant="body2"><strong>Item {index + 1}</strong></Typography>
            </AccordionSummary>
            <AccordionDetails className={classes.details}>
              <StructuredValue value={item} depth={depth + 1} />
            </AccordionDetails>
          </Accordion>
        ))}
      </Box>
    );
  }

  const entries = Object.entries((value ?? {}) as Record<string, unknown>);
  if (entries.length === 0) return <Typography color="textSecondary">Empty object</Typography>;

  if (depth >= 2 || entries.every(([, item]) => isPrimitive(item))) {
    return (
      <Table size="small">
        <TableBody>
          {entries.map(([key, item]) => (
            <TableRow key={key}>
              <TableCell className={classes.key}>{key}</TableCell>
              <TableCell><StructuredValue value={item} depth={depth + 1} /></TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    );
  }

  return (
    <Box>
      {entries.map(([key, item]) => (
        <Accordion key={key} className={classes.accordion} defaultExpanded={depth === 0 && ['metadata', 'spec'].includes(key)}>
          <AccordionSummary
            expandIcon={<ExpandMoreIcon />}
            classes={{ root: classes.summary, expanded: classes.expanded }}
          >
            <Typography variant="body2"><strong>{key}</strong></Typography>
          </AccordionSummary>
          <AccordionDetails className={classes.details}>
            <StructuredValue value={item} depth={depth + 1} />
          </AccordionDetails>
        </Accordion>
      ))}
    </Box>
  );
};
