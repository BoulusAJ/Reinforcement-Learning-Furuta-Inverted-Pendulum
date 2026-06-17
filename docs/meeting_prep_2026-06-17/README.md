# Meeting Prep Scripts - 2026-06-17

This folder archives the scripts used to generate the quick meeting assets and
slide deck for the Furuta RL project update.

## Files

- `create_meeting_assets.py`
  - Reads saved TD3 CSV results.
  - Generates quick PNG plots.
  - Writes `meeting_brief_2026-06-17.md`.

- `create_meeting_deck.mjs`
  - Uses the Codex bundled `@oai/artifact-tool` package.
  - Builds the editable PowerPoint deck.
  - Renders slide previews for visual QA.

## Output Location

Both scripts write to:

```text
outputs/meeting_update_2026-06-17
```

The current expanded generated deck is:

```text
outputs/meeting_update_2026-06-17/furuta_rl_update_2026-06-17_voltage_comparison.pptx
```

## Current Revision

The current deck is a 24-slide meeting update. It includes:

- the early Water Tank example and the curriculum-learning lesson that carried over;
- an expanded Water Tank section on reward evolution, one-direction actuation, best run slices, and example plots;
- the initial Furuta approach, swing-up method search, and why TD3 became the main RL path;
- a grouped view of the 297-case evaluation matrix;
- the new oscillation, action-chatter, and electrical-energy metrics added to the evaluation workflow;
- the completed PI/current-path TD3 run 2 comparison on analytical-active versus Simscape-active feedback plants.
- the voltage-command analytical-active comparison against the PI/current analytical-active path, including matched cases at theta0 = (0, 0) and theta0 = (0, pi).

## Runtime Note

In this Codex desktop environment, the default `python` and `node` commands were
not available on PATH. The scripts were run with the bundled runtime:

```text
C:\Users\abuj\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe
C:\Users\abuj\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe
```

Example commands from the project root:

```bat
C:\Users\abuj\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe docs\meeting_prep_2026-06-17\create_meeting_assets.py
C:\Users\abuj\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe docs\meeting_prep_2026-06-17\create_meeting_deck.mjs
```

## Notes

- No MATLAB scripts were newly written for the deck generation in this chat.
- The plots are quick meeting visuals, not publication-grade figures.
- The original working copies also remain in `tools/meeting_prep`.
