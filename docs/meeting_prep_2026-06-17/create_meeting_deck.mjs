import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Presentation, PresentationFile } from "file:///C:/Users/abuj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..", "..");
const outDir = path.join(root, "outputs", "meeting_update_2026-06-17");
const finalPptx = path.join(outDir, "furuta_rl_update_2026-06-17_voltage_comparison.pptx");
const previewDir = path.join(outDir, "deck_preview");

const W = 1280;
const H = 720;
const C = {
  ink: "#25313d",
  muted: "#596b7a",
  faint: "#e8edf2",
  panel: "#f5f8fb",
  blue: "#0b4f6c",
  teal: "#2a9d8f",
  amber: "#f2a541",
  red: "#d1495b",
  white: "#ffffff",
};

function textbox(slide, text, position, style = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position,
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontSize: 22,
    color: C.ink,
    typeface: "Aptos",
    ...style,
  };
  return shape;
}

function rect(slide, position, fill = C.panel, line = C.faint, radius = "rounded-lg") {
  return slide.shapes.add({
    geometry: "roundRect",
    position,
    fill,
    line: { style: "solid", fill: line, width: 1 },
    borderRadius: radius,
  });
}

function title(slide, text, kicker = "Furuta RL update | 2026-06-17") {
  textbox(slide, kicker.toUpperCase(), { left: 64, top: 42, width: 680, height: 24 }, {
    fontSize: 12,
    bold: true,
    color: C.muted,
  });
  textbox(slide, text, { left: 64, top: 74, width: 1040, height: 82 }, {
    fontSize: 36,
    bold: true,
    color: C.ink,
  });
}

function footer(slide, source = "Sources: meeting handoff, MathWorks-style TD3 notes, saved run CSVs") {
  textbox(slide, source, { left: 64, top: 686, width: 1040, height: 20 }, {
    fontSize: 10,
    color: "#7b8b99",
  });
}

function bullet(slide, text, x, y, w = 520, color = C.ink) {
  slide.shapes.add({
    geometry: "ellipse",
    position: { left: x, top: y + 8, width: 8, height: 8 },
    fill: C.teal,
    line: { style: "solid", fill: C.teal, width: 0 },
  });
  textbox(slide, text, { left: x + 22, top: y, width: w, height: 56 }, {
    fontSize: 21,
    color,
  });
}

function kpi(slide, label, value, note, x, y, w, color = C.blue) {
  rect(slide, { left: x, top: y, width: w, height: 148 }, C.white, "#d5dde5");
  textbox(slide, value, { left: x + 24, top: y + 24, width: w - 48, height: 55 }, {
    fontSize: 44,
    bold: true,
    color,
  });
  textbox(slide, label, { left: x + 24, top: y + 84, width: w - 48, height: 28 }, {
    fontSize: 18,
    bold: true,
    color: C.ink,
  });
  textbox(slide, note, { left: x + 24, top: y + 112, width: w - 48, height: 24 }, {
    fontSize: 13,
    color: C.muted,
  });
}

function compactKpi(slide, label, value, note, x, y, w, color = C.blue) {
  rect(slide, { left: x, top: y, width: w, height: 116 }, C.white, "#d5dde5");
  textbox(slide, value, { left: x + 22, top: y + 18, width: w - 44, height: 44 }, {
    fontSize: 36,
    bold: true,
    color,
  });
  textbox(slide, label, { left: x + 22, top: y + 66, width: w - 44, height: 24 }, {
    fontSize: 16,
    bold: true,
    color: C.ink,
  });
  textbox(slide, note, { left: x + 22, top: y + 91, width: w - 44, height: 18 }, {
    fontSize: 11,
    color: C.muted,
  });
}

async function image(slide, filename, position, alt) {
  const bytes = await fs.readFile(path.join(outDir, filename));
  slide.images.add({
    blob: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength),
    contentType: "image/png",
    alt,
    fit: "contain",
    position,
  });
}

function notes(slide, text) {
  slide.speakerNotes.textFrame.setText(text);
}

async function main() {
  await fs.mkdir(outDir, { recursive: true });
  await fs.mkdir(previewDir, { recursive: true });

  const presentation = Presentation.create({ slideSize: { width: W, height: H } });
  presentation.theme.colorScheme = {
    name: "Furuta update",
    themeColors: {
      accent1: C.blue,
      accent2: C.teal,
      accent3: C.amber,
      accent4: C.red,
      bg1: C.white,
      bg2: C.panel,
      tx1: C.ink,
      tx2: C.muted,
      dk1: "#000000",
      dk2: C.ink,
      lt1: C.white,
      lt2: C.faint,
      hlink: C.blue,
      folHlink: C.teal,
    },
  };

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    textbox(s, "Furuta inverted pendulum RL", { left: 70, top: 88, width: 960, height: 80 }, {
      fontSize: 54,
      bold: true,
      color: C.ink,
    });
    textbox(s, "Update meeting: what worked, what did not, and what needs a careful dry run next", { left: 72, top: 178, width: 840, height: 70 }, {
      fontSize: 26,
      color: C.muted,
    });
    rect(s, { left: 72, top: 310, width: 1080, height: 220 }, C.panel, "#d5dde5");
    textbox(s, "Current honest headline", { left: 112, top: 348, width: 340, height: 30 }, {
      fontSize: 18,
      bold: true,
      color: C.blue,
    });
    textbox(s, "RL learned a useful swing-up/stabilization policy in simulation, but robustness and sim-to-real behavior depend strongly on reward design, actuator interface, and plant-model consistency.", { left: 112, top: 392, width: 950, height: 92 }, {
      fontSize: 29,
      bold: true,
      color: C.ink,
    });
    footer(s, "Prepared from project notes and saved TD3 run artifacts");
    notes(s, "Open naturally: this is not a victory-lap talk. The useful result is that the project moved from fragile training attempts to a controller we can actually evaluate and discuss scientifically.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Where we are in the project plan");
    const phases = [
      ["Days 1-7", "Model, signals, simulation setup, baseline context"],
      ["Days 8-12", "RL training worked after moving away from the fragile curriculum path"],
      ["Days 13-16", "Current phase: robustness, fixed evaluation, actuator and plant diagnostics"],
      ["Days 17-20", "Meeting story, plots, demo choice, hardware dry-run preparation"],
    ];
    phases.forEach((p, i) => {
      const x = 86 + i * 292;
      rect(s, { left: x, top: 235, width: 240, height: 220 }, i === 2 ? "#e8f4f2" : C.panel, i === 2 ? C.teal : "#d5dde5");
      textbox(s, p[0], { left: x + 20, top: 260, width: 190, height: 34 }, {
        fontSize: 24,
        bold: true,
        color: i === 2 ? C.teal : C.blue,
      });
      textbox(s, p[1], { left: x + 20, top: 314, width: 200, height: 112 }, {
        fontSize: 18,
        color: C.ink,
      });
    });
    textbox(s, "Meeting framing: show the controller as useful in simulation, not solved for hardware.", { left: 92, top: 520, width: 980, height: 42 }, {
      fontSize: 24,
      bold: true,
      color: C.ink,
    });
    footer(s);
    notes(s, "This slide is mostly orientation. Say that the project has entered the evaluation and decision-gate phase.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Before Furuta: the Water Tank project became the workflow prototype");
    const items = [
      ["Base example", "Started from MathWorks rlwatertank DDPG: compact example, single training run, random starts."],
      ["Curriculum version", "Extended it into four stages: local correction, medium transient, global robustness, precision fine-tuning."],
      ["Reward lesson", "Moved from tolerance-band success toward normalized tracking error, action effort, and action smoothness."],
      ["Evaluation lesson", "Saved per-stage artifacts and used fixed/deterministic evaluations so results were not dominated by random initial conditions."],
    ];
    items.forEach((it, i) => {
      const x = i % 2 === 0 ? 78 : 670;
      const y = i < 2 ? 188 : 398;
      rect(s, { left: x, top: y, width: 520, height: 150 }, i % 2 === 0 ? C.panel : "#e8f4f2", i % 2 === 0 ? "#d5dde5" : "#b7d8d3");
      textbox(s, it[0], { left: x + 28, top: y + 24, width: 440, height: 28 }, {
        fontSize: 22,
        bold: true,
        color: i % 2 === 0 ? C.blue : C.teal,
      });
      textbox(s, it[1], { left: x + 28, top: y + 64, width: 450, height: 62 }, {
        fontSize: 18,
        color: C.ink,
      });
    });
    textbox(s, "Carry-over to Furuta: define the task, shape the reset distribution, log the signals, and evaluate fixed cases before believing training reward.", { left: 105, top: 585, width: 1050, height: 48 }, {
      fontSize: 23,
      bold: true,
      color: C.ink,
    });
    footer(s, "Sources: RL-Water-Tank README and curriculum docs; docs/chat_handoff_2026-06-09.md");
    notes(s, "This is the bridge slide. The water tank work was valuable because it built the project discipline: staged difficulty, reward scaling, fixed evaluation, and organized results.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Where the curriculum idea came from");
    rect(s, { left: 80, top: 190, width: 330, height: 300 }, C.panel, "#d5dde5");
    rect(s, { left: 475, top: 190, width: 330, height: 300 }, "#e8f4f2", "#b7d8d3");
    rect(s, { left: 870, top: 190, width: 330, height: 300 }, "#fff8eb", "#ecd49d");
    textbox(s, "Practical source", { left: 112, top: 222, width: 260, height: 32 }, { fontSize: 24, bold: true, color: C.blue });
    textbox(s, "Water Tank: learn small corrections first, then widen the initial-condition distribution and reduce exploration for precision.", { left: 112, top: 275, width: 255, height: 126 }, { fontSize: 20, color: C.ink });
    textbox(s, "Control reason", { left: 507, top: 222, width: 260, height: 32 }, { fontSize: 24, bold: true, color: C.teal });
    textbox(s, "A nonlinear controller should not be judged only on random starts. Each stage should answer a narrower control question.", { left: 507, top: 275, width: 255, height: 126 }, { fontSize: 20, color: C.ink });
    textbox(s, "Pendulum transfer", { left: 902, top: 222, width: 260, height: 32 }, { fontSize: 24, bold: true, color: C.amber });
    textbox(s, "For Furuta, the natural curriculum was angle/velocity range: near-upright balance, medium recovery, large-angle recovery, full swing-up.", { left: 902, top: 275, width: 255, height: 126 }, { fontSize: 20, color: C.ink });
    bullet(s, "Important lesson: if the reward or reset distribution changes a lot, old replay/critic information can become misleading.", 150, 545, 920);
    footer(s, "Sources: RL-Water-Tank curriculum docs; docs/rl_task_definition.md; docs/direct_td3_swingup_plan_2026-06-11.md");
    notes(s, "This slide gives a natural-language explanation. The curriculum idea was not just copied blindly; it came from trying to make learning and evaluation scientifically staged.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Water Tank reward: from MATLAB's band reward to control-shaped tracking");
    rect(s, { left: 82, top: 178, width: 510, height: 290 }, C.panel, "#d5dde5");
    textbox(s, "MathWorks example reward", { left: 118, top: 212, width: 390, height: 30 }, { fontSize: 24, bold: true, color: C.blue });
    textbox(s, "+10 if |e| < 0.1\n-1 otherwise\n-100 if the tank hits unsafe height", { left: 118, top: 270, width: 400, height: 100 }, { fontSize: 24, bold: true, color: C.ink });
    textbox(s, "Good for teaching the agent to enter the acceptable band. Weak for precise steady-state tracking, because 0.09 error and near-zero error can receive the same reward.", { left: 118, top: 390, width: 410, height: 62 }, { fontSize: 17, color: C.muted });
    rect(s, { left: 690, top: 178, width: 510, height: 290 }, "#e8f4f2", "#b7d8d3");
    textbox(s, "Final project reward direction", { left: 726, top: 212, width: 390, height: 30 }, { fontSize: 24, bold: true, color: C.teal });
    textbox(s, "normalized error\nintegral-error / PI-like terms\naction effort\naction-difference smoothness\nunsafe-level penalty", { left: 726, top: 260, width: 420, height: 132 }, { fontSize: 23, bold: true, color: C.ink });
    textbox(s, "Potential shaping was used as curriculum assistance, but the base objective was kept as consistent as possible.", { left: 726, top: 405, width: 400, height: 45 }, { fontSize: 17, color: C.muted });
    textbox(s, "Lesson: reward scale is part of the controller design. A sudden reward rewrite can invalidate the critic and replay buffer.", { left: 130, top: 545, width: 1000, height: 54 }, { fontSize: 25, bold: true, color: C.ink });
    footer(s, "Sources: MathWorks rlwatertank example; RL-Water-Tank README; scripts/rewardFcn.m; scripts/makeStageConfig.m");
    notes(s, "This slide explains why the Water Tank work went beyond the MATLAB example. The key phrase: the original reward taught acceptable behavior, but not precision.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Why the Water Tank was harder than it looked");
    rect(s, { left: 90, top: 190, width: 500, height: 285 }, "#fff8eb", "#ecd49d");
    textbox(s, "One-sided actuation", { left: 126, top: 228, width: 360, height: 34 }, { fontSize: 28, bold: true, color: C.amber });
    textbox(s, "The agent controls inlet flow. It can add water quickly, but when the tank is too high it cannot actively pull water out. The best action is often near-zero flow plus waiting for passive drainage.", { left: 126, top: 290, width: 410, height: 118 }, { fontSize: 22, color: C.ink });
    rect(s, { left: 690, top: 190, width: 500, height: 285 }, "#fff5f6", "#ecc1c8");
    textbox(s, "Asymmetric learning problem", { left: 726, top: 228, width: 390, height: 34 }, { fontSize: 28, bold: true, color: C.red });
    textbox(s, "A reward that helps rising cases can punish draining cases, and a reward that keeps action smooth can make downward corrections look slow or inactive.", { left: 726, top: 290, width: 410, height: 118 }, { fontSize: 22, color: C.ink });
    textbox(s, "This is why random average reward was not enough. Raising, draining, and already-at-reference cases had to be inspected separately.", { left: 130, top: 545, width: 1010, height: 58 }, { fontSize: 25, bold: true, color: C.ink });
    footer(s, "Sources: RL-Water-Tank exports and evaluation metrics");
    notes(s, "This slide tees up the next three plots. The water tank is simple but asymmetric, which makes reward shaping surprisingly brittle.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Water Tank runs: the best result depended on the slice");
    const rows = [
      ["Run 3, stage 1", "easy reset / strong shaping", "excellent local and at-reference behavior", "h0 = hRef = 5: Final MAE 0.0013, case cost 0.0973"],
      ["Run 4, final stage", "full reset / no shaping / low noise", "better final-curriculum candidate", "works well in many raising cases, but still weak for some draining/high-start cases"],
    ];
    rows.forEach((r, i) => {
      const y = 205 + i * 170;
      rect(s, { left: 88, top: y, width: 1090, height: 126 }, i === 0 ? "#e8f4f2" : C.panel, i === 0 ? "#b7d8d3" : "#d5dde5");
      textbox(s, r[0], { left: 126, top: y + 24, width: 240, height: 32 }, { fontSize: 25, bold: true, color: i === 0 ? C.teal : C.blue });
      textbox(s, r[1], { left: 390, top: y + 24, width: 300, height: 32 }, { fontSize: 20, bold: true, color: C.ink });
      textbox(s, r[2], { left: 720, top: y + 20, width: 390, height: 32 }, { fontSize: 20, color: C.ink });
      textbox(s, r[3], { left: 390, top: y + 70, width: 710, height: 28 }, { fontSize: 18, color: C.muted });
    });
    textbox(s, "Meeting phrasing: there was no single clean 'solved' Water Tank agent. The best run depended on whether we cared about local precision, broad curriculum coverage, or asymmetric draining cases.", { left: 105, top: 555, width: 1050, height: 60 }, { fontSize: 23, bold: true, color: C.ink });
    footer(s, "Sources: run 3 and run 4 allMetrics_prec4.csv");
    notes(s, "This is the honest summary: the water tank produced useful behaviors, but the reward design never became universally satisfying.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Water Tank example: raising case");
    await image(s, "water_tank_case_positive.png", { left: 92, top: 140, width: 1080, height: 470 }, "Water Tank raising case: height and action");
    textbox(s, "Here the one-sided actuator helps: the agent can actively add water, then back off once the height is near the reference.", { left: 130, top: 626, width: 1010, height: 42 }, { fontSize: 21, bold: true, color: C.ink });
    footer(s, "Source: run 4 exported trajectory: New_Export_positive.xlsx");
    notes(s, "The image intentionally only shows height/reference and action. This is the easy direction for the actuator.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Water Tank example: draining case");
    await image(s, "water_tank_case_negative.png", { left: 92, top: 140, width: 1080, height: 470 }, "Water Tank draining case: height and action");
    textbox(s, "Here the agent cannot actively drain. It mostly closes the inlet and waits, so reward shaping can easily treat a physical limitation as a policy failure.", { left: 130, top: 626, width: 1010, height: 42 }, { fontSize: 21, bold: true, color: C.ink });
    footer(s, "Source: run 4 exported trajectory: New_Export_negative.xlsx");
    notes(s, "This is the contrast with the raising case. The one-direction actuator explains why reward tuning was not symmetric.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Water Tank example: already at the reference");
    await image(s, "water_tank_at_reference.png", { left: 98, top: 145, width: 1080, height: 470 }, "Water Tank at-reference evaluation case");
    textbox(s, "This case explains why precision mattered: if the tank already starts at the target, the controller should avoid unnecessary action and not create its own transient.", { left: 130, top: 625, width: 1010, height: 42 }, { fontSize: 21, bold: true, color: C.ink });
    footer(s, "Source: run 3 stage 1 metrics; trajectory is a labeled sketch because this exact case was not exported");
    notes(s, "Be explicit that the exact at-reference trajectory was not exported. The saved metrics are real; the plotted line is a simple sketch to communicate the desired behavior.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Why I moved away from Water Tank");
    bullet(s, "Every reward shape seemed to make one part of the grid better while making another part worse.", 86, 190, 990);
    bullet(s, "The one-direction actuator made the tradeoff especially visible: raising, draining, and already-at-reference behavior wanted different incentives.", 86, 290, 990);
    bullet(s, "The project had already served its purpose as a workflow prototype: curriculum, reset design, reward scaling, fixed evaluation, saved artifacts.", 86, 390, 990);
    bullet(s, "Furuta was the real target system, so the Water Tank lessons were carried forward instead of spending the whole project tuning a toy example.", 86, 490, 990);
    footer(s, "Sources: RL-Water-Tank README and curriculum docs");
    notes(s, "This should sound natural: I moved on because reward shaping started feeling like whack-a-mole across cases, not because the water tank was useless.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Furuta method search: what options were on the table?");
    const methods = [
      ["Analytical swing-up", "Energy control, Lyapunov/passivity, feedback linearization, optimal control. Strong control literature; useful baseline/context."],
      ["Hybrid RL + classical", "MathWorks QUBE Servo2 repo: SAC for swing-up, PPO for mode selection, feedback controller for balance."],
      ["Near-upright DDPG", "First direct RL attempt: simplest continuous-action framing, but actor/critic training was fragile."],
      ["Direct TD3", "Kept the same normalized action idea but added twin critics, delayed actor updates, and target smoothing."],
      ["MathWorks-style TD3", "Later simplified toward the QUBE TD3 example: no curriculum, 200 Hz agent, sin/cos observations, large replay buffer."],
    ];
    methods.forEach((m, i) => {
      const y = 172 + i * 88;
      rect(s, { left: 82, top: y, width: 1070, height: 68 }, i === 4 ? "#e8f4f2" : C.panel, i === 4 ? C.teal : "#d5dde5");
      textbox(s, m[0], { left: 110, top: y + 18, width: 260, height: 28 }, {
        fontSize: 22,
        bold: true,
        color: i === 4 ? C.teal : C.blue,
      });
      textbox(s, m[1], { left: 390, top: y + 15, width: 720, height: 38 }, {
        fontSize: 17,
        color: C.ink,
      });
    });
    footer(s, "Sources: Furuta swing-up literature note; MathWorks QUBE Servo2 refs; TD3 transition notes");
    notes(s, "Use this to show that TD3 was a deliberate choice, not just the algorithm at hand. SAC/PPO hybrid was known, but it would have changed the architecture more radically.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Early Furuta approach: good engineering, fragile learning");
    bullet(s, "Started conservatively with near-upright stabilization: controller-facing errors, normalized current/torque action, explicit safety limits.", 86, 185, 980);
    bullet(s, "Built fixed-case post-stage evaluation, reward-diagnosis logging, signal extraction, and result organization before chasing a big demo.", 86, 275, 980);
    bullet(s, "DDPG did not reliably learn even local balance; TD3 was better, but fixed evaluation still showed arm-limit failures and action oscillations.", 86, 365, 980);
    bullet(s, "The staged direct swing-up TD3 branch showed partial learning, but reward scale and arm management were still weak.", 86, 455, 980);
    rect(s, { left: 710, top: 520, width: 420, height: 112 }, "#fff5f6", "#ecc1c8");
    textbox(s, "Drawback that changed direction", { left: 742, top: 543, width: 330, height: 24 }, { fontSize: 18, bold: true, color: C.red });
    textbox(s, "Training reward could look better than fixed-case control quality.", { left: 742, top: 575, width: 340, height: 48 }, { fontSize: 17, color: C.ink });
    footer(s, "Sources: docs/td3_transition_2026-06-10.md; docs/td3_overnight_results_2026-06-11.md; docs/direct_td3_stage1_results_2026-06-11.md");
    notes(s, "This is a 'what I learned' slide. The early approach was not wasted: it uncovered signal, reward, timing, and evaluation problems.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "What changed: from fragile curriculum to MathWorks-style TD3");
    bullet(s, "Earlier staged direct TD3 helped debug reward and evaluation signals, but training was slow and fragile.", 82, 205, 980);
    bullet(s, "The stronger path matches the MathWorks QUBE pattern more closely: no curriculum, TD3, 200 Hz agent sample time, 64-unit networks, async parallel training.", 82, 295, 1010);
    bullet(s, "The big process improvement was fixed-case evaluation. Training reward and episode survival alone were misleading.", 82, 405, 1010);
    rect(s, { left: 710, top: 475, width: 420, height: 122 }, "#fff8eb", "#f0c778");
    textbox(s, "Reward idea", { left: 742, top: 500, width: 180, height: 26 }, { fontSize: 18, bold: true, color: C.amber });
    textbox(s, "survival reward - weighted angle, velocity, action, and action-smoothing costs", { left: 742, top: 536, width: 340, height: 42 }, { fontSize: 18, color: C.ink });
    footer(s, "Sources: docs/direct_td3_stage1_results_2026-06-11.md; docs/mathworks_style_td3_runs_2026-06-16.md");
    notes(s, "Do not dwell too long on the formula unless asked. The important point is that the setup became stable enough to learn, then the evaluation revealed what was still weak.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Evaluation matrix: 297 cases, but only four dimensions");
    const cols = [
      ["Arm offset", "3 values", "-45, 0, +45 deg", C.blue],
      ["Pendulum error", "11 values", "-180 to +180 deg", C.teal],
      ["Arm velocity", "3 values", "-5, 0, +5 rad/s", C.amber],
      ["Pendulum velocity", "3 values", "-10, 0, +10 rad/s", C.red],
    ];
    cols.forEach((c, i) => {
      const x = 72 + i * 300;
      rect(s, { left: x, top: 180, width: 250, height: 150 }, C.white, "#d5dde5");
      textbox(s, c[0], { left: x + 24, top: 205, width: 200, height: 26 }, { fontSize: 21, bold: true, color: c[3] });
      textbox(s, c[1], { left: x + 24, top: 245, width: 180, height: 38 }, { fontSize: 34, bold: true, color: C.ink });
      textbox(s, c[2], { left: x + 24, top: 292, width: 190, height: 24 }, { fontSize: 16, color: C.muted });
    });
    textbox(s, "3 x 11 x 3 x 3 = 297 fixed initial-condition cases", { left: 170, top: 370, width: 850, height: 44 }, {
      fontSize: 32,
      bold: true,
      color: C.ink,
      alignment: "center",
    });
    const bands = [
      ["Easy/core", "theta1 = 0, small theta2, low velocities"],
      ["Swing-up stress", "large theta2 errors, including downward starts"],
      ["Arm management", "same pendulum cases with +/-45 deg arm offset"],
      ["Velocity stress", "same angles with arm/pendulum initial momentum"],
    ];
    bands.forEach((b, i) => {
      const x = i % 2 === 0 ? 125 : 675;
      const y = i < 2 ? 455 : 545;
      textbox(s, b[0], { left: x, top: y, width: 160, height: 24 }, { fontSize: 20, bold: true, color: C.blue });
      textbox(s, b[1], { left: x + 170, top: y, width: 360, height: 34 }, { fontSize: 17, color: C.ink });
    });
    footer(s, "Source: full_eval_cases.csv for run_20260616_012625_td3_mathworks_style_wide");
    notes(s, "This slide lets you avoid listing 297 cases. Say the matrix is a Cartesian product of four interpretable stress axes.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Evaluation matrix is being upgraded for oscillation and energy");
    const groups = [
      ["End theta2 behavior", "Theta2EndRMS\nTheta2EndOscRMS\nTheta2EndPeakToPeak\nTheta2EndOscFreqHz", C.blue],
      ["End action behavior", "ActionEndRMS\nActionEndOscRMS\nActionEndPeakToPeak\nActionEndOscFreqHz\nActionDiffRMS", C.teal],
      ["Electrical effort", "ElectricalAbsEnergy\nMeanAbsElectricalPower", C.amber],
    ];
    groups.forEach((g, i) => {
      const x = 86 + i * 382;
      rect(s, { left: x, top: 190, width: 320, height: 280 }, i === 2 ? "#fff8eb" : i === 1 ? "#e8f4f2" : C.panel, "#d5dde5");
      textbox(s, g[0], { left: x + 28, top: 222, width: 250, height: 32 }, { fontSize: 23, bold: true, color: g[2] });
      textbox(s, g[1], { left: x + 28, top: 282, width: 250, height: 145 }, { fontSize: 20, color: C.ink });
    });
    textbox(s, "Why this matters: the old summary could say a controller survived and ended near upright, while hiding small final oscillations, action chatter, or high electrical effort.", { left: 118, top: 530, width: 1040, height: 58 }, {
      fontSize: 23,
      bold: true,
      color: C.ink,
    });
    textbox(s, "Status: columns are now present in the PI/current analytical-active and Simscape-active rerun CSVs.", { left: 118, top: 615, width: 980, height: 30 }, {
      fontSize: 20,
      color: C.red,
      bold: true,
    });
    footer(s, "Sources: scripts/computeFurutaMetrics.m; scripts/evaluateFurutaController.m");
    notes(s, "Use this to explain the user's newest evaluation improvement. The key is the last-second window and detrending: separate bias from oscillation amplitude.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Training result: usable, but not magic");
    await image(s, "training_progress_summary.png", { left: 60, top: 150, width: 1160, height: 390 }, "Training reward and episode length curve for the best MathWorks-style wide TD3 run");
    compactKpi(s, "Final average reward", "740", "episode 3000 snapshot", 92, 555, 250, C.blue);
    compactKpi(s, "Last 50 full-length", "43/50", "late training stability", 378, 555, 250, C.teal);
    compactKpi(s, "Training episodes", "3000", "wide randomization run", 664, 555, 250, C.amber);
    compactKpi(s, "Main caveat", "spiky", "occasional collapses remain", 950, 555, 250, C.red);
    footer(s, "Source: results/TD3/run_20260616_012625_td3_mathworks_style_wide/training_progress.csv");
    notes(s, "Say: this is the first run that feels genuinely usable. But the late spikes remind us not to claim robustness just from training reward.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Best current controller: PI/current path TD3");
    kpi(s, "Full fixed eval", "297", "initial-condition cases", 78, 185, 250, C.blue);
    kpi(s, "Failure rate", "14.48%", "43/297 cases", 368, 185, 250, C.red);
    kpi(s, "Median final MAE", "0.35 deg", "tight when it succeeds", 658, 185, 250, C.teal);
    kpi(s, "Mean final MAE", "7.23 deg", "mean pulled by failures", 948, 185, 250, C.amber);
    await image(s, "pi_eval_distribution.png", { left: 70, top: 350, width: 1140, height: 305 }, "Distribution of final pendulum error for non-failed PI current path evaluation cases");
    footer(s, "Source: full_final_summary.csv and full_final_metrics.csv for run_20260616_012625_td3_mathworks_style_wide");
    notes(s, "This is the best positive result. Make the nuance clear: successful cases are often very good, but broad robustness is incomplete.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Failure mode is specific: arm management");
    rect(s, { left: 80, top: 185, width: 500, height: 300 }, "#fff5f6", "#ecc1c8");
    textbox(s, "43 failures", { left: 120, top: 225, width: 380, height: 65 }, {
      fontSize: 52,
      bold: true,
      color: C.red,
    });
    textbox(s, "All were arm-angle limit failures. No pendulum-limit failures. No angular-velocity-limit failures.", { left: 122, top: 310, width: 390, height: 92 }, {
      fontSize: 24,
      color: C.ink,
    });
    rect(s, { left: 650, top: 185, width: 500, height: 300 }, "#f7fbfc", "#bfd7e2");
    textbox(s, "Exceedance margins", { left: 690, top: 225, width: 370, height: 36 }, {
      fontSize: 27,
      bold: true,
      color: C.blue,
    });
    textbox(s, "min 0.012 deg\nmedian 0.312 deg\nmax 2.277 deg", { left: 690, top: 285, width: 360, height: 120 }, {
      fontSize: 30,
      bold: true,
      color: C.ink,
    });
    textbox(s, "Interpretation: the controller can swing up and stabilize in many practical cases, but the objective still tolerates arm travel too much.", { left: 140, top: 535, width: 980, height: 54 }, {
      fontSize: 25,
      bold: true,
      color: C.ink,
    });
    footer(s, "Source: meeting handoff and full_final_metrics.csv");
    notes(s, "This is a good informal slide. It turns the failure story from vague to actionable: reward and arm constraints need attention.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Voltage command: quieter, but less robust on the analytical grid");
    await image(s, "voltage_pi_analytical_summary.png", { left: 58, top: 138, width: 1165, height: 455 }, "Summary comparison of PI current and voltage command analytical-active evaluations");
    textbox(s, "Descriptive takeaway: PI/current covers more of the fixed grid. Voltage command removes almost all final theta2 oscillation in easy cases, but loses robustness on the broad analytical-active evaluation.", { left: 100, top: 612, width: 1060, height: 52 }, {
      fontSize: 22,
      bold: true,
      color: C.ink,
    });
    footer(s, "Sources: pi_current_analytical_active summaries; voltage_analytical_active_2 summaries");
    notes(s, "This is the clean tradeoff slide. Say: PI/current is the safer overall policy, voltage is a useful clue about the final oscillation problem.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Matched analytical cases show the tradeoff directly");
    await image(s, "voltage_pi_matched_cases.png", { left: 58, top: 135, width: 1165, height: 455 }, "Matched-case metrics for theta0 equals zero zero and zero pi");
    textbox(s, "theta0 = (0, 0): both survive, voltage is nearly motionless at the end. theta0 = (0, pi): PI/current survives with a small oscillation, voltage fails early.", { left: 105, top: 612, width: 1060, height: 52 }, {
      fontSize: 22,
      bold: true,
      color: C.ink,
    });
    footer(s, "Source: full_final_metrics.csv rows with theta1=0, theta2 in {0, pi}, omega1=omega2=0");
    notes(s, "The per-case CSVs are metrics tables, not trajectory logs. The plot uses exact matched rows from both evaluations.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "Plant mismatch is not just a voltage-path issue");
    await image(s, "actuator_plant_comparison.png", { left: 72, top: 160, width: 1136, height: 420 }, "Comparison of PI current and voltage policies under analytical and Simscape-active evaluation");
    textbox(s, "Cautious conclusion: PI/current is robust on the analytical-active plant, but Simscape-active feedback collapses broad robustness. Direct voltage is still useful diagnostically, not yet as the winner.", { left: 105, top: 598, width: 1040, height: 58 }, {
      fontSize: 22,
      bold: true,
      color: C.ink,
    });
    footer(s, "Sources: PI/current analytical/Simscape rerun summaries; voltage analytical/Simscape summaries");
    notes(s, "Phrase carefully: the new PI/current rerun proves the Simscape-active problem is not only caused by the voltage command path.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "PI/current rerun: analytical reproduces, Simscape collapses");
    const rows = [
      ["Analytical-active", "14.48% failure", "43/297 cases"],
      ["Simscape-active", "86.53% failure", "257/297 cases"],
    ];
    textbox(s, "Feedback plant", { left: 130, top: 210, width: 240, height: 28 }, { fontSize: 20, bold: true, color: C.muted });
    textbox(s, "Failure rate", { left: 510, top: 210, width: 220, height: 28 }, { fontSize: 20, bold: true, color: C.muted });
    textbox(s, "Failures", { left: 840, top: 210, width: 220, height: 28 }, { fontSize: 20, bold: true, color: C.muted });
    rows.forEach((r, i) => {
      const y = 260 + i * 130;
      rect(s, { left: 100, top: y, width: 300, height: 85 }, C.panel, "#d5dde5");
      rect(s, { left: 470, top: y, width: 260, height: 85 }, "#e8f4f2", "#b7d8d3");
      rect(s, { left: 810, top: y, width: 260, height: 85 }, "#fff8eb", "#ecd49d");
      textbox(s, r[0], { left: 126, top: y + 25, width: 240, height: 30 }, { fontSize: 22, bold: true, color: C.ink });
      textbox(s, r[1], { left: 492, top: y + 25, width: 220, height: 30 }, { fontSize: 20, color: C.ink });
      textbox(s, r[2], { left: 832, top: y + 25, width: 220, height: 30 }, { fontSize: 20, color: C.ink });
    });
    bullet(s, "The old PI/current result was effectively analytical-active; the explicit rerun reproduced it exactly.", 120, 535, 990);
    bullet(s, "The smaller Simscape mean final theta2 MAE is misleading because most hard cases fail. Lead with failure rate and breakdown.", 120, 585, 990);
    textbox(s, "Hardware note: this argues for plant/interface validation before hardware-oriented claims.", { left: 120, top: 648, width: 980, height: 34 }, {
      fontSize: 22,
      bold: true,
      color: C.red,
    });
    footer(s, "Sources: pi_current_analytical_active/full_final_summary.csv; pi_current_simscape_active/full_final_summary.csv");
    notes(s, "This is the updated decision-gate slide. It replaces the pending rerun with the actual plant-mismatch result.");
  }

  {
    const s = presentation.slides.add();
    s.background.fill = C.white;
    title(s, "New metrics clarify what changed and what did not");
    rect(s, { left: 92, top: 190, width: 500, height: 270 }, "#e8f4f2", "#b7d8d3");
    textbox(s, "Short/easy cases", { left: 126, top: 225, width: 400, height: 34 }, { fontSize: 25, bold: true, color: C.teal });
    textbox(s, "Analytical and Simscape are very similar:\nTheta2EndOscRMS about 0.0067 rad\nTheta2EndPeakToPeak about 0.02 rad\nOscillation frequency about 7 Hz", { left: 126, top: 292, width: 410, height: 135 }, { fontSize: 20, color: C.ink });
    rect(s, { left: 680, top: 190, width: 500, height: 270 }, "#fff8eb", "#ecd49d");
    textbox(s, "Broad/full matrix", { left: 714, top: 225, width: 340, height: 34 }, { fontSize: 25, bold: true, color: C.amber });
    textbox(s, "Simscape-active fails much earlier/more often:\nomega 5 rad/s: 66/66 failed\nomega 10 rad/s: 188/198 failed\nFailure rate is the headline.", { left: 714, top: 292, width: 410, height: 135 }, { fontSize: 20, color: C.ink });
    textbox(s, "Meeting phrasing: the final-second oscillation metric says easy upright behavior transfers, but the full matrix says recovery robustness does not.", { left: 130, top: 540, width: 1010, height: 58 }, { fontSize: 24, bold: true, color: C.ink });
    footer(s, "Sources: PI/current analytical-active and Simscape-active rerun summaries; user-provided breakdown");
    notes(s, "This is the clean takeaway: the new metrics did their job by separating final oscillation behavior from broad robustness.");
  }

  const sourceNotes = `Sources used:
- docs/meeting_handoff_2026-06-17.md
- docs/mathworks_style_td3_runs_2026-06-16.md
- Notes for Documentation/rl_project_lessons_from_setup.md
- results/TD3/run_20260616_012625_td3_mathworks_style_wide/training_progress.csv
- results/TD3/run_20260616_012625_td3_mathworks_style_wide/evaluation/full_final_summary.csv
- results/TD3/run_20260616_012625_td3_mathworks_style_wide/evaluation/full_final_metrics.csv
- results/TD3/run_20260616_012625_td3_mathworks_style_wide/analysis/pi_current_analytical_active/*.csv
- results/TD3/run_20260616_012625_td3_mathworks_style_wide/analysis/pi_current_simscape_active/*.csv
- results/TD3/run_20260616_233822_td3_mathworks_style_voltage/evaluation/full_final_summary.csv
- results/TD3/run_20260616_233822_td3_mathworks_style_voltage/evaluation/full_simscape_model_active_summary.csv
- results/TD3/run_20260616_233822_td3_mathworks_style_voltage/analysis/voltage_analytical_active_2/*.csv
- C:/Users/abuj/Code/Work/RL/RL-Water-Tank/README.md
- C:/Users/abuj/Code/Work/RL/RL-Water-Tank/watertank_curriculum_docs/*.md
- C:/Users/abuj/Code/Work/RL/RL-Water-Tank/scripts/rewardFcn.m
- C:/Users/abuj/Code/Work/RL/RL-Water-Tank/scripts/makeStageConfig.m
- C:/Users/abuj/Code/Work/RL/RL-Water-Tank/data/run 3 - 20260526_1/allMetrics_prec4.csv
- C:/Users/abuj/Code/Work/RL/RL-Water-Tank/data/run 4 - 20260526_2 - full run/allMetrics_prec4.csv
- C:/Users/abuj/Code/Work/RL/RL-Water-Tank/data/run 4 - 20260526_2 - full run/New_Export_positive.xlsx
- C:/Users/abuj/Code/Work/RL/RL-Water-Tank/data/run 4 - 20260526_2 - full run/New_Export_negative.xlsx
- references/zhaw_rotary_pendulum_lab/lab_model/furuta_pendulum_swingup_literature.md
- references/Reinforcement-Learning-Inverted-Pendulum-with-QUBE-Servo2/README.md
- references/Reinforcement-Learning-Inverted-Pendulum-with-QUBE-Servo2/RL/design_RL_multi_control_SAC_md.md
- references/Reinforcement-Learning-Inverted-Pendulum-with-QUBE-Servo2/RL/RL_design_difficulty_md.md
- references/MATLAB-Train-Default-TD3-Agent-to-Control-Quanser-QUBE-Pendulum/TrainAgentsToControlQuanserQUBEPendulumExample.m
- scripts/computeFurutaMetrics.m
- scripts/evaluateFurutaController.m
`;
  await fs.writeFile(path.join(outDir, "source_notes.txt"), sourceNotes, "utf8");
  await fs.writeFile(path.join(outDir, "slide_plan.txt"), "Create mode; 24-slide informal update deck; palette: blue/teal/amber/red on white; fonts: Aptos/Aptos Display fallback. Expanded with a Water Tank mini-section, Furuta method choices, evaluation-matrix grouping, new metrics, completed PI/current analytical-vs-Simscape rerun results, and PI/current versus voltage-command analytical-active comparison slides.\n", "utf8");

  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await presentation.export({ slide, format: "png", scale: 1 });
    await fs.writeFile(path.join(previewDir, `${stem}.png`), new Uint8Array(await png.arrayBuffer()));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(previewDir, `${stem}.layout.json`), await layout.text(), "utf8");
  }

  const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
  await fs.writeFile(path.join(previewDir, "deck_montage.webp"), new Uint8Array(await montage.arrayBuffer()));

  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(finalPptx);
  console.log(finalPptx);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
