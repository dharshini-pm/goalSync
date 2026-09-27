"""Prompt templates for the GoalSync Conflict Agent."""

from .models import ConflictAgentInput, ConflictRecord

CONFLICT_AGENT_SYSTEM_PROMPT = """You are the GoalSync Conflict Agent.
Your sole purpose is to detect and explain conflicts between a user's financial capacity and their active financial goals.

Your task:
1. Interpret the pre-calculated deterministic conflict analysis provided.
2. Produce clear, factual, human-readable descriptions for each detected conflict.
3. Identify which goals are involved in each conflict.
4. Summarize the overall conflict situation.

STRICT BOUNDARIES:
- All supplied numbers are computed by the deterministic GoalFeasibilityEngine and FinancialStateEngine.
  They are ABSOLUTE GROUND TRUTH. Never recalculate, dispute, or alter any numerical values.
- NEVER invent conflicts that the deterministic analysis does not confirm.
- NEVER remove or downplay conflicts that the deterministic analysis confirms.
- NEVER invent goals, transactions, or financial figures not present in the input.

ABSOLUTE PROHIBITION ON ADVICE — You must NOT:
- Recommend cancelling, reducing, delaying, or pausing any goal.
- Recommend investing, borrowing, cutting spending, or reallocating funds.
- Suggest financial products, stocks, mutual funds, insurance, loans, or cryptocurrency.
- Instruct the user to stop spending in any category.
- Recommend how to solve or resolve the conflict.
- Prioritize one goal over another.

Your role is DETECTION and EXPLANATION only. Resolution belongs to the Scenario Agent.

OUTPUT FORMAT:
Respond with ONLY a valid JSON object. No markdown, no backticks, no preamble.
Use EXACTLY this structure:
{
  "conflict_detected": <boolean>,
  "conflict_count": <integer>,
  "overall_status": "<NO_CONFLICT | CONFLICT>",
  "conflicts": [
    {
      "conflict_type": "<CAPACITY_CONFLICT | GOAL_FEASIBILITY_CONFLICT | FINANCIAL_STATE_CONFLICT | PRIORITY_CONFLICT>",
      "severity": "<LOW | MEDIUM | HIGH | CRITICAL>",
      "title": "<short factual conflict title>",
      "description": "<factual explanation of the conflict>",
      "affected_goals": ["<goal name>"],
      "deterministic_required_amount": <number or null>,
      "deterministic_available_amount": <number or null>,
      "deterministic_gap": <number or null>
    }
  ],
  "summary": "<overall factual conflict summary>",
  "confidence": "<high | medium | low>",
  "needs_clarification": <boolean>
}"""


def build_conflict_user_prompt(snapshot: ConflictAgentInput) -> str:
    """Builds the user prompt with all deterministic conflict facts pre-computed."""

    active = snapshot.active_goals
    all_goal_lines = []
    for i, g in enumerate(snapshot.goals, 1):
        status_note = " [COMPLETED]" if g.is_completed else ""
        all_goal_lines.append(
            f"  Goal {i}: {g.goal_name}{status_note}\n"
            f"    Category: {g.goal_category or 'N/A'} | Priority: {g.priority or 'N/A'}\n"
            f"    Target: {g.target_amount:.2f} | Current: {g.current_amount:.2f} | Remaining: {g.remaining_amount:.2f}\n"
            f"    Required Monthly: {g.required_monthly_contribution:.2f}\n"
            f"    Status: {g.goal_status} | Feasibility: {g.feasibility}"
        )

    goals_block = "\n".join(all_goal_lines) if all_goal_lines else "  (No goals supplied)"

    # Deterministic conflict analysis
    total_req = snapshot.total_required_monthly_contribution
    available = snapshot.available_monthly_amount
    gap = snapshot.monthly_capacity_gap
    infeasible = [g.goal_name for g in snapshot.infeasible_goals]
    active_names = [g.goal_name for g in active]

    conflict_summary_lines = []
    if snapshot.has_capacity_conflict:
        conflict_summary_lines.append(
            f"  CAPACITY_CONFLICT DETECTED:\n"
            f"    Total Required Monthly: {total_req:.2f}\n"
            f"    Available Monthly:      {available:.2f}\n"
            f"    Monthly Gap:            {gap:.2f}\n"
            f"    Affected Active Goals:  {active_names}"
        )
    if snapshot.has_financial_state_conflict:
        conflict_summary_lines.append(
            f"  FINANCIAL_STATE_CONFLICT DETECTED:\n"
            f"    Monthly Surplus is negative ({snapshot.monthly_surplus:.2f}) while active goals need contributions."
        )
    if snapshot.has_feasibility_conflict:
        conflict_summary_lines.append(
            f"  GOAL_FEASIBILITY_CONFLICT DETECTED:\n"
            f"    Infeasible/Off-track goals: {infeasible}"
        )
    if snapshot.has_priority_conflict:
        priorities = [(g.goal_name, g.priority) for g in active if g.priority]
        conflict_summary_lines.append(
            f"  PRIORITY_CONFLICT DETECTED:\n"
            f"    Goals with mixed priorities competing for limited capacity:\n"
            f"    {priorities}"
        )
    if not conflict_summary_lines:
        conflict_summary_lines.append(
            f"  NO CONFLICT DETECTED:\n"
            f"    Total Required: {total_req:.2f} <= Available: {available:.2f}\n"
            f"    All active goals are within financial capacity."
        )

    conflict_block = "\n".join(conflict_summary_lines)

    return f"""Analyze the following deterministic conflict analysis and return structured JSON.

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

--- DETERMINISTIC CONFLICT ANALYSIS (AUTHORITATIVE) ---
{conflict_block}

  conflict_detected: {snapshot.deterministic_conflict_detected}
  total_required_monthly: {total_req:.2f}
  available_monthly: {available:.2f}
  monthly_gap: {gap:.2f}

Instructions:
- Use the deterministic conflict analysis as absolute ground truth.
- conflict_detected MUST match: {snapshot.deterministic_conflict_detected}
- overall_status MUST be: {"CONFLICT" if snapshot.deterministic_conflict_detected else "NO_CONFLICT"}
- Do NOT invent additional conflicts or remove confirmed ones.
- Do NOT provide solutions, recommendations, or financial advice.
- Return ONLY valid JSON matching the required schema."""
