"""Prompt templates for the GoalSync Explanation Agent."""

from .models import ExplanationAgentInput


EXPLANATION_AGENT_SYSTEM_PROMPT = """You are the GoalSync Explanation Agent.
Your sole purpose is to explain structured financial intelligence to a user in clear, neutral, human-readable language.

YOU RECEIVE:
- Deterministic financial state values (income, expenses, capacity, savings).
- Goal status and feasibility data computed by the GoalFeasibilityEngine.
- Conflict analysis from the Conflict Agent.
- What-if scenarios from the Scenario Agent.

YOUR TASK:
1. Explain what the deterministic analysis shows in plain language.
2. Explain any detected conflicts using only the supplied facts.
3. Explain what each scenario means numerically (without ranking or recommending).
4. Produce a clear headline, summary, and structured output.

ABSOLUTE RULE — NEVER CALCULATE:
- Do NOT compute monthly surplus, savings rate, contributions, or gaps yourself.
- Do NOT recalculate any numerical values from the input.
- All numbers in your output must come directly from the supplied deterministic data.
- If you return a number that differs from the input, it will be overwritten by the system.

ABSOLUTE RULE — NEVER ADVISE:
- Do NOT say "you should", "you must", "I recommend", "I suggest".
- Do NOT say "best option", "best scenario", "choose scenario", "select", "pick".
- Do NOT recommend loans, investments, borrowing, spending cuts, or financial products.
- Do NOT say "you should cancel", "reduce goal", "stop funding", "cut expenses".
- Do NOT rank scenarios. Do NOT say one scenario is better than another.
- Do NOT tell the user what financial action to take.

NEUTRAL LANGUAGE EXAMPLES:
- "The current monthly capacity is X." (not "You need to increase your capacity.")
- "Goal A requires X per month." (not "You should fund Goal A first.")
- "Under Scenario S1, the contribution reduces to X." (not "Choose Scenario S1.")
- "A capacity gap of X exists." (not "This is a problem you need to fix.")

DISTINGUISH CLEARLY:
- FACT: A value computed by GoalSync engines.
- INTERPRETATION: A human-readable explanation of a fact.
- ASSUMPTION: A hypothetical change used in a scenario.

OUTPUT FORMAT:
Respond with ONLY a valid JSON object. No markdown, no backticks, no preamble.
Use EXACTLY this structure:
{
  "headline": "<one-sentence neutral summary for the user>",
  "summary": "<2-4 sentence factual overview>",
  "key_points": ["<fact 1>", "<fact 2>", "<fact 3>"],
  "goal_impacts": [
    {
      "goal_name": "<name>",
      "explanation": "<neutral factual status explanation>",
      "status": "<ON_TRACK|AT_RISK|OFF_TRACK|COMPLETED>"
    }
  ],
  "conflict_explanation": {
    "detected": <boolean>,
    "explanation": "<neutral factual conflict explanation>"
  },
  "scenario_explanations": [
    {
      "scenario_id": "<S1>",
      "explanation": "<neutral factual scenario outcome explanation>"
    }
  ],
  "assumptions": ["<scenario assumption 1>", "<scenario assumption 2>"],
  "confidence": "<high|medium|low>",
  "needs_clarification": <boolean>
}"""


def build_explanation_user_prompt(snapshot: ExplanationAgentInput) -> str:
    """Build the user prompt injecting all deterministic facts."""

    # --- Goals block ---
    goal_lines = []
    for i, g in enumerate(snapshot.goals, 1):
        tag = " [COMPLETED]" if g.is_completed else ""
        goal_lines.append(
            f"  Goal {i}: {g.goal_name}{tag}\n"
            f"    Category: {g.goal_category or 'N/A'} | Priority: {g.priority or 'N/A'}\n"
            f"    Target: {g.target_amount:.2f} | Current: {g.current_amount:.2f} "
            f"| Remaining: {g.remaining_amount:.2f}\n"
            f"    Required Monthly: {g.required_monthly_contribution:.2f}\n"
            f"    Target Date: {g.target_date or 'N/A'}\n"
            f"    Status: {g.goal_status} | Feasibility: {g.feasibility}"
        )
    goals_block = "\n".join(goal_lines) if goal_lines else "  (No goals)"

    # --- Conflicts block ---
    conflict_lines = []
    for c in snapshot.conflicts:
        conflict_lines.append(
            f"  [{c.severity}] {c.conflict_type}: {c.title}\n"
            f"    Description: {c.description}\n"
            f"    Affected Goals: {c.affected_goals}\n"
            f"    Required: {c.deterministic_required_amount} | "
            f"Available: {c.deterministic_available_amount} | "
            f"Gap: {c.deterministic_gap}"
        )
    conflict_block = "\n".join(conflict_lines) if conflict_lines else "  (No conflicts detected)"

    # --- Scenarios block ---
    scenario_lines = []
    for s in snapshot.scenarios:
        scenario_lines.append(
            f"  [{s.scenario_id}] {s.scenario_type}: {s.title}\n"
            f"    Assumptions: {s.assumptions}\n"
            f"    Affected Goals: {s.affected_goals}\n"
            f"    Original Monthly Req: {s.original_monthly_requirement:.2f}\n"
            f"    Scenario Monthly Req: {s.scenario_monthly_requirement:.2f}\n"
            f"    Monthly Capacity:     {s.monthly_capacity:.2f}\n"
            f"    Capacity Gap:         {s.capacity_gap:.2f}\n"
            f"    Projected Status:     {s.projected_goal_status}"
        )
    scenario_block = "\n".join(scenario_lines) if scenario_lines else "  (No scenarios)"

    return f"""Explain the following deterministic GoalSync intelligence to the user. Return structured JSON.

--- FINANCIAL STATE (SOURCE OF TRUTH) ---
- Monthly Income:            {snapshot.monthly_income:.2f}
- Monthly Expenses:          {snapshot.monthly_expenses:.2f}
- Monthly Surplus:           {snapshot.monthly_surplus:.2f}
- Available Monthly Amount:  {snapshot.available_monthly_amount:.2f}
- Total EMI:                 {snapshot.total_emi:.2f}
- Current Savings:           {snapshot.current_savings:.2f}
- Savings Rate:              {snapshot.savings_rate:.1f}%
- Financial Status:          {snapshot.financial_status}
- Cash Flow Status:          {snapshot.cash_flow_status}
- Key Signals:               {snapshot.key_signals}
- Concerns:                  {snapshot.concerns}

--- GOALS ({len(snapshot.goals)} total, {len(snapshot.active_goals)} active) ---
{goals_block}

--- CONFLICT ANALYSIS ---
  conflict_detected: {snapshot.conflict_detected}
  conflict_count: {snapshot.conflict_count}
  overall_status: {snapshot.overall_conflict_status}
{conflict_block}

--- SCENARIOS ---
  scenario_required: {snapshot.scenario_required}
  scenario_count: {snapshot.scenario_count}
{scenario_block}

DETERMINISTIC TOTALS (AUTHORITATIVE):
  total_required_monthly: {snapshot.total_required_monthly:.2f}
  capacity_gap: {snapshot.capacity_gap:.2f}

Instructions:
- Explain these facts to the user in clear, neutral language.
- Do NOT recalculate any values. Use only the numbers above.
- Do NOT rank or recommend scenarios.
- Do NOT provide financial advice of any kind.
- conflict_explanation.detected MUST be: {snapshot.conflict_detected}
- scenario_explanations must cover exactly: {[s.scenario_id for s in snapshot.scenarios]}
- Return ONLY valid JSON matching the required schema."""
