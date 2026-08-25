/**
 * Causal Recap Graph Generator for ECHO//LINE (أصداء)
 * Transforms flat causal logs into an interactive timeline branch hierarchy.
 */

class CausalRecapBuilder {
  static buildRecap(causalLog, matchSummary) {
    const nodes = [];
    const timelineBranches = {
      past: [],
      present: [],
      future: []
    };

    causalLog.forEach((entry, idx) => {
      const node = {
        id: `node_${entry.seq}`,
        echo_id: entry.echo_id,
        source_timeline: entry.source_timeline,
        loc_key: entry.loc_key,
        triggered_by: entry.triggered_by,
        timestamp_relative_sec: Math.floor((entry.timestamp - matchSummary.start_time) / 1000),
        affected_timelines: [...new Set(entry.deltas.map(d => d.timeline))],
        impact_summary: entry.deltas.map(d => ({
          target_timeline: d.timeline,
          entity: d.entity,
          property: d.property,
          value: d.value
        }))
      };

      nodes.push(node);
      if (timelineBranches[entry.source_timeline]) {
        timelineBranches[entry.source_timeline].push(node.id);
      }
    });

    return {
      match_id: matchSummary.match_id,
      outcome_id: matchSummary.outcome_id,
      outcome_key: matchSummary.outcome_key,
      outcome_grade: matchSummary.outcome_grade,
      duration_seconds: Math.floor((matchSummary.end_time - matchSummary.start_time) / 1000),
      total_echoes: nodes.length,
      nodes,
      timeline_branches: timelineBranches
    };
  }
}

module.exports = {
  CausalRecapBuilder
};
