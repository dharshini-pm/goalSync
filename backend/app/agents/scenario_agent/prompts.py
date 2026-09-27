"""Prompt templates for the GoalSync Scenario Agent."""

from .models import ScenarioAgentInput, ScenarioRecord
from typing import List

SCENARIO_AGENT_SYSTEM_PROMPT = """You are the GoalSync Scenario Agent.
Your sole purpose is to generate transparent what-if scenarios that show how a
user's financial goal situation would change under different numerical assumptions.

YOUR TASK:
1. Receive pre-computed deterministic scenario results.
2. Generate clear, neutral, human-readable descriptions and assumption lists.
3. Return structured JSON that matches the required output schema.

STRICT RULES — FACTS:
- All numerical values (contributions, capacities, gaps, statuses) are ABSOLUTE GROUND TRUTH.
- They are pre-computed by the deterministic engine. Never change, dispute, or recalculate them.
- Never invent goals, transactions, income, or expenses not in the input.

STRICT RULES — NEUTRALITY:
- Never recommend which scenario to choose.
- Never say "best option", "best scenario", "you should choose", "select scenario".
- Never advise the user to cancel, pause, delay, or eliminate a goal.
- Never advise investment, loans, borrowing, spending cuts, or financial products.
- Use neutral language: "Under this scenario...", "If the target date is extended...",
  "Projected monthly contribution becomes...", "Compared with the current state...".

ABSOLUTE PROHIBITION ON ADVICE:
- Do NOT say "you should", "you must", "I recommend".
- Do NOT say "best option", "best scenario", "choose scenario", "pick scenario".
- Do NOT say "take out a loan", "borrow money", "buy stocks", "invest in", "mutual fund".
- Do NOT say "cryptocurrency", "financial advice", "financial product".
- Do NOT say "cancel the goal", "cancel goal", "reduce goal", "stop funding".
- Do NOT say "cut your spending", "cut expenses", "sell your", "open an account".

YOUR ROLE:
- Present alternatives. The user decides. The Explanation Agent explains.

OUTPUT FORMAT:
Respond with ONLY a valid JSON object. No markdown, no backticks, no preamble.
Use EXACTLY this structure:
{
  "scenario_required": <boolean>,
  "scenario_count": <integer>,
  "scenarios": [
    {
      "scenario_id": "<S1>",
      "scenario_type": "<TIMELINE_ADJUSTMENT|CONTRIBUTION_REALLOCATION|SINGLE_GOAL_FOCUS|CAPACITY_CHANGE>",
      "title": "<neutral scenario title>",
      "assumptions": ["<changed assumption 1>", "<changed assumption 2>"],
      "affected_goals": ["<goal name>"],
      "original_monthly_requirement": <number>,
      "scenario_monthly_requirement": <number>,
      "monthly_capacity": <number>,
      "capacity_gap": <number>,
      "projected_goal_status": "<ON_TRACK|AT_RISK|OFF_TRACK|COMPLETED>",
      "description": "<neutral factual description of the scenario outcome>"
    }
  ],
  "summary": "<neutral summary of the scenario analysis>",
  "confidence": "<high|medium|low>",
  "needs_clarification": <boolean>
}"""


def build_scenario_user_prompt(
    snapshot: ScenarioAgentInput,
    det_scenarios: List[ScenarioRecord],
) -> str:
    """Build the user prompt, injecting deterministic scenario data as ground truth."""

    active = snapshot.active_goals
    goal_lines = []
    for i, g in enumerate(snapshot.goals, 1):
        status_note = " [COMPLETED]" if g.is_completed else ""
        goal_lines.append(
            f"  Goal {i}: {g.goal_name}{status_note}\n"
            f"    Category: {g.goal_category or 'N/A'} | Priority: {g.priority or 'N/A'}\n"
            f"    Target: {g.target_amount:.2f} | Current: {g.current_amount:.2f} "
            f"| Remaining: {g.remaining_amount:.2f}\n"
            f"    Required Monthly: {g.required_monthly_contribution:.2f}\n"
            f"    Target Date: {g.target_date or 'N/A'}\n"
            f"    Status: {g.goal_status} | Feasibility: {g.feasibility}"
        )
    goals_block = "\n".join(goal_lines) if goal_lines else "  (No goals supplied)"

    conflict_lines = []
    for c in snapshot.conflicts:
        conflict_lines.append(
            f"  - [{c.severity}] {c.conflict_type}: {c.title}\n"
            f"    Affected: {c.affected_goals}\n"
            f"    Required: {c.deterministic_required_amount} | "
            f"Available: {c.deterministic_available_amount} | "
            f"Gap: {c.deterministic_gap}"
        )
    conflict_block = "\n".join(conflict_lines) if conflict_lines else "  (No conflicts)"

    scenario_lines = []
    for s in det_scenarios:
        scenario_lines.append(
            f"\n  [{s.scenario_id}] {s.scenario_type.value}: {s.title}\n"
            f"    Assumptions: {s.assumptions}\n"
            f"    Affected Goals: {s.affected_goals}\n"
            f"    Original Monthly Req:  {s.original_monthly_requirement:.2f}\n"
            f"    Scenario Monthly Req:  {s.scenario_monthly_requirement:.2f}\n"
            f"    Monthly Capacity:      {s.monthly_capacity:.2f}\n"
            f"    Capacity Gap:          {s.capacity_gap:.2f}\n"
            f"    Projected Status:      {s.projected_goal_status.value}\n"
            f"    Description:           {s.description}"
        )
    scenario_block = "\n".join(scenario_lines) if scenario_lines else "  (No scenarios required)"

    return f"""Generate structured what-if scenario JSON from the following deterministic data.

--- FINANCIAL STATE (SOURCE OF TRUTH) ---
- Monthly Income:            {snapshot.monthly_income:.2f}
- Monthly Expenses:          {snapshot.monthly_expenses:.2f}
- Monthly Surplus:           {snapshot.monthly_surplus:.2f}
- Available Monthly Amount:  {snapshot.available_monthly_amount:.2f}
- Total EMI:                 {snapshot.total_emi:.2f}
- Current Savings:           {snapshot.current_savings:.2f}
- Savings Rate:              {snapshot.savings_rate:.1f}%

--- GOALS ({len(snapshot.goals)} total, {len(active)} active) ---
{goals_block}

--- DETECTED CONFLICTS ---
  conflict_detected: {snapshot.conflict_detected}
{conflict_block}

--- DETERMINISTIC SCENARIOS (AUTHORITATIVE — DO NOT ALTER NUMBERS) ---
  scenario_required: {snapshot.conflict_detected}
  scenario_count: {len(det_scenarios)}
{scenario_block}

Instructions:
- scenario_required MUST be: {snapshot.conflict_detected}
- scenario_count MUST be: {len(det_scenarios)}
- All numerical values in scenarios are AUTHORITATIVE. Copy them exactly.
- Do NOT change scenario_id, scenario_type, affected_goals, or numerical fields.
- You may enrich the "description" and "assumptions" with neutral language.
- Never provide financial advice, recommendations, or instructions.
- Return ONLY valid JSON matching the required schema."""
