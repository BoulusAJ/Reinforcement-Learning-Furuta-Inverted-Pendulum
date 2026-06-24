# Meeting Brief

## Goal

Use the meeting to get expert feedback on the next technical step for a simulation-trained TD3 Furuta controller that now transfers partially to hardware but jitters near upright.

## Suggested 8-Minute Talk Flow

1. Problem: Furuta inverted pendulum, continuous current command, TD3 policy.
2. What changed: earlier approach was fragile; MathWorks-style TD3 gave stable learning and fixed evaluation.
3. Evidence: 200 Hz full eval, 500 Hz hardware attempt, model-vs-hardware Test 1.
4. Honest limitation: upright jitter/current chatter and plant mismatch.
5. Decision request: domain randomization vs residual dynamics vs hardware fine-tuning.
6. Ask for feedback on reward tuning and control guarantees.

## Compact Current-State Slide Text

"A TD3 policy trained in simulation transferred far enough to attempt swing-up on hardware. The remaining problem is not gross sign or wiring failure; it is robustness and smoothness under real friction, dead zones, actuator limits, and current-loop mismatch."

## Files In This Prep Folder

- `project_knowledge_review.md`: main project review notes.
- `questions_for_weinmann.md`: questions, open issues, and historical questions you asked.
- `agent_short_eval_comparison.csv`: direct 200 Hz vs 500 Hz long short-case comparison.
- `plots/short_eval_iae_cost.svg`: short eval transient comparison.
- `plots/short_eval_action_diff.svg`: short eval action-difference comparison.
- `plots/plant_mismatch_failure.svg`: analytical vs Simscape-active broad failure comparison.
- `slides.html`: browser-ready slide deck.
- `slides.md`: editable slide outline/source.

## Evidence To Bring Up Carefully

The 500 Hz long agent's full 297-case evaluation is not committed in the same way as the 200 Hz run. For the meeting, say: shared short cases pass for both; hardware transfer was encouraging; broader 500 Hz robustness still needs a matching full evaluation.
