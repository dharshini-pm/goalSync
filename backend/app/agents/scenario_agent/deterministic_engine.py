"""Deterministic scenario calculation engine for the GoalSync Scenario Agent.

The LLM NEVER performs financial mathematics. This module does all calculations.
"""

from __future__ import annotations

from datetime import date
from typing import List, Optional, Tuple

from .models import (
    GoalScenarioSnapshot,
    ProjectedGoalStatus,
    ScenarioRecord,
    ScenarioType,
)


# ---------------------------------------------------------------------------
# Status classifier
# ---------------------------------------------------------------------------

def classify_projected_status(
    scenario_requirement: float,
    capacity: float,
    remaining_amount: float,
) -> ProjectedGoalStatus:
    """Classify projected goal status based on scenario numbers."""
    if remaining_amount <= 0:
        return ProjectedGoalStatus.COMPLETED
    if capacity <= 0:
        return ProjectedGoalStatus.OFF_TRACK
    gap = scenario_requirement - capacity
    if gap <= 0:
        return ProjectedGoalStatus.ON_TRACK
    ratio = gap / max(1.0, scenario_requirement)
    if ratio <= 0.20:
        return ProjectedGoalStatus.AT_RISK
    return ProjectedGoalStatus.OFF_TRACK


# ---------------------------------------------------------------------------
# SCENARIO TYPE 1: TIMELINE_ADJUSTMENT
# ---------------------------------------------------------------------------

def compute_timeline_adjustment(
    goal: GoalScenarioSnapshot,
    extend_months: int,
    available_monthly_amount: float,
    reference_date: Optional[date] = None,
) -> Tuple[float, float, float, ProjectedGoalStatus, List[str]]:
    """Compute new required contribution after extending the target date.

    Returns:
        (original_req, scenario_req, capacity_gap, projected_status, assumptions)
    """
    original_req = round(goal.required_monthly_contribution, 2)
    original_months = goal.months_remaining_from(reference_date) or 0

    # Extended months — minimum 1 to avoid division by zero
    new_months = max(1, original_months + extend_months)
    scenario_req = goal.deterministic_contribution_for_months(new_months)

    # Total capacity gap with new requirement (other goals assumed unchanged)
    capacity_gap = round(max(0.0, scenario_req - available_monthly_amount), 2)
    status = classify_projected_status(scenario_req, available_monthly_amount, goal.remaining_amount)

    assumptions = [
        f"Target date for '{goal.goal_name}' is extended by {extend_months} month(s).",
        f"Remaining amount stays at {goal.remaining_amount:.2f} (no additional contributions assumed).",
        f"All other goals and financial conditions remain unchanged.",
    ]
    return original_req, scenario_req, capacity_gap, status, assumptions


# ---------------------------------------------------------------------------
# SCENARIO TYPE 2: CONTRIBUTION_REALLOCATION
# ---------------------------------------------------------------------------

def compute_contribution_reallocation(
    active_goals: List[GoalScenarioSnapshot],
    available_monthly_amount: float,
) -> Tuple[float, float, float, ProjectedGoalStatus, List[str], List[str]]:
    """Proportionally redistribute available capacity across active goals.

    The total of all scenario contributions equals available_monthly_amount (no shortfall).

    Returns:
        (original_req, scenario_req, capacity_gap, projected_status, assumptions, affected_goals)
    """
    original_req = round(sum(g.required_monthly_contribution for g in active_goals), 2)
    total_weight = original_req if original_req > 0 else 1.0

    allocations: List[Tuple[str, float, float]] = []
    for g in active_goals:
        weight = g.required_monthly_contribution / total_weight
        allocated = round(weight * available_monthly_amount, 2)
        allocations.append((g.goal_name, g.required_monthly_contribution, allocated))

    scenario_req = round(sum(a[2] for a in allocations), 2)
    capacity_gap = round(max(0.0, scenario_req - available_monthly_amount), 2)

    # Status based on lowest funded goal ratio
    worst_status = ProjectedGoalStatus.ON_TRACK
    for name, orig, alloc in allocations:
        if orig > 0 and alloc < orig:
            ratio_covered = alloc / orig
            if ratio_covered < 0.7:
                worst_status = ProjectedGoalStatus.OFF_TRACK
                break
            elif ratio_covered < 0.9:
                worst_status = ProjectedGoalStatus.AT_RISK

    assumptions = [
        "Available monthly capacity is redistributed proportionally across all active goals.",
        f"Total reallocation equals available capacity of {available_monthly_amount:.2f}.",
        "No additional income or expenses are assumed.",
    ]
    goal_lines = [
        f"  - {name}: originally {orig:.2f}, under scenario {alloc:.2f}"
        for name, orig, alloc in allocations
    ]
    assumptions += goal_lines
    affected = [a[0] for a in allocations]
    return original_req, scenario_req, capacity_gap, worst_status, assumptions, affected


# ---------------------------------------------------------------------------
# SCENARIO TYPE 3: SINGLE_GOAL_FOCUS
# ---------------------------------------------------------------------------

def compute_single_goal_focus(
    focused_goal: GoalScenarioSnapshot,
    all_active_goals: List[GoalScenarioSnapshot],
    available_monthly_amount: float,
) -> Tuple[float, float, float, ProjectedGoalStatus, List[str], List[str]]:
    """Model what happens if all capacity is directed to one goal.

    Returns:
        (original_req, scenario_req, capacity_gap, projected_status, assumptions, affected_goals)
    """
    original_req = round(sum(g.required_monthly_contribution for g in all_active_goals), 2)
    scenario_req = round(focused_goal.required_monthly_contribution, 2)
    capacity_gap = round(max(0.0, scenario_req - available_monthly_amount), 2)
    status = classify_projected_status(
        scenario_req, available_monthly_amount, focused_goal.remaining_amount
    )

    other_names = [g.goal_name for g in all_active_goals if g.goal_name != focused_goal.goal_name]
    assumptions = [
        f"Under this scenario, all available monthly capacity ({available_monthly_amount:.2f}) "
        f"is directed to '{focused_goal.goal_name}'.",
        f"Other active goals ({other_names}) are not funded under this scenario.",
        "This is a what-if illustration only. No actual goal is modified.",
    ]
    affected = [focused_goal.goal_name] + other_names
    return original_req, scenario_req, capacity_gap, status, assumptions, affected


# ---------------------------------------------------------------------------
# SCENARIO TYPE 4: CAPACITY_CHANGE
# ---------------------------------------------------------------------------

def compute_capacity_change(
    active_goals: List[GoalScenarioSnapshot],
    original_capacity: float,
    new_capacity: float,
) -> Tuple[float, float, float, ProjectedGoalStatus, List[str]]:
    """Model what happens to goal feasibility if monthly capacity changes.

    Returns:
        (original_req, scenario_req, capacity_gap, projected_status, assumptions)
    """
    original_req = round(sum(g.required_monthly_contribution for g in active_goals), 2)
    # scenario_req is the same — the capacity changed, not the requirements
    scenario_req = original_req
    capacity_gap = round(max(0.0, scenario_req - new_capacity), 2)
    status = classify_projected_status(scenario_req, new_capacity, 1.0)  # 1.0 = goals not completed

    delta = round(new_capacity - original_capacity, 2)
    direction = "increased" if delta >= 0 else "decreased"
    assumptions = [
        f"Available monthly capacity is {direction} by {abs(delta):.2f} "
        f"from {original_capacity:.2f} to {new_capacity:.2f}.",
        "Goal required contributions remain unchanged under this scenario.",
        "The source of the capacity change is not assumed — this is a what-if illustration only.",
    ]
    return original_req, scenario_req, capacity_gap, status, assumptions


# ---------------------------------------------------------------------------
# Full scenario set builder
# ---------------------------------------------------------------------------

def build_deterministic_scenarios(
    snapshot,  # ScenarioAgentInput — avoid circular import
    reference_date: Optional[date] = None,
) -> List[ScenarioRecord]:
    """Build all applicable deterministic scenario records from a ScenarioAgentInput.

    Returns a list of ScenarioRecord objects with all numerical values pre-computed.
    The LLM later adds human-readable descriptions; the numbers are fixed here.
    """
    active = snapshot.active_goals
    if not active:
        return []

    available = snapshot.available_monthly_amount
    original_total = round(sum(g.required_monthly_contribution for g in active), 2)
    records: List[ScenarioRecord] = []
    sid = 1

    # ------------------------------------------------------------------
    # S1: TIMELINE_ADJUSTMENT — extend the goal with the largest contribution
    # ------------------------------------------------------------------
    largest = max(active, key=lambda g: g.required_monthly_contribution)
    if largest.remaining_amount > 0:
        for ext_months in (6, 12):
            orig_req, sc_req, gap, status, assumptions = compute_timeline_adjustment(
                goal=largest,
                extend_months=ext_months,
                available_monthly_amount=available,
                reference_date=reference_date,
            )
            # Total scenario: other goals unchanged + new req for largest
            other_req = original_total - orig_req
            total_sc_req = round(other_req + sc_req, 2)
            total_gap = round(max(0.0, total_sc_req - available), 2)
            status = classify_projected_status(total_sc_req, available, 1.0)
            records.append(ScenarioRecord(
                scenario_id=f"S{sid}",
                scenario_type=ScenarioType.TIMELINE_ADJUSTMENT,
                title=f"Extend '{largest.goal_name}' target date by {ext_months} months",
                assumptions=assumptions,
                affected_goals=[largest.goal_name],
                original_monthly_requirement=round(original_total, 2),
                scenario_monthly_requirement=round(total_sc_req, 2),
                monthly_capacity=round(available, 2),
                capacity_gap=round(total_gap, 2),
                projected_goal_status=status,
                description=(
                    f"Under this scenario, the target date for '{largest.goal_name}' is extended by "
                    f"{ext_months} months. The calculated monthly contribution for that goal changes "
                    f"from {orig_req:.2f} to {sc_req:.2f}. "
                    f"Total required monthly contribution becomes {total_sc_req:.2f} "
                    f"compared with available capacity of {available:.2f}."
                ),
            ))
            sid += 1

    # ------------------------------------------------------------------
    # S3: CONTRIBUTION_REALLOCATION (only when multiple goals and shortfall)
    # ------------------------------------------------------------------
    if len(active) > 1 and snapshot.has_capacity_shortfall:
        orig_req, sc_req, gap, status, assumptions, affected = compute_contribution_reallocation(
            active_goals=active,
            available_monthly_amount=available,
        )
        records.append(ScenarioRecord(
            scenario_id=f"S{sid}",
            scenario_type=ScenarioType.CONTRIBUTION_REALLOCATION,
            title="Proportional reallocation of available capacity across all active goals",
            assumptions=assumptions,
            affected_goals=affected,
            original_monthly_requirement=orig_req,
            scenario_monthly_requirement=sc_req,
            monthly_capacity=round(available, 2),
            capacity_gap=round(gap, 2),
            projected_goal_status=status,
            description=(
                f"Under this scenario, the available monthly capacity of {available:.2f} is "
                f"redistributed proportionally across all {len(active)} active goals. "
                f"Total scenario contribution equals {sc_req:.2f}, matching the available capacity. "
                f"Each goal receives a proportional share based on its original required contribution."
            ),
        ))
        sid += 1

    # ------------------------------------------------------------------
    # S4: SINGLE_GOAL_FOCUS — focus on the highest-priority / largest goal
    # ------------------------------------------------------------------
    if len(active) > 1:
        focus_goal = max(active, key=lambda g: g.required_monthly_contribution)
        orig_req, sc_req, gap, status, assumptions, affected = compute_single_goal_focus(
            focused_goal=focus_goal,
            all_active_goals=active,
            available_monthly_amount=available,
        )
        records.append(ScenarioRecord(
            scenario_id=f"S{sid}",
            scenario_type=ScenarioType.SINGLE_GOAL_FOCUS,
            title=f"Direct all available capacity to '{focus_goal.goal_name}' only",
            assumptions=assumptions,
            affected_goals=affected,
            original_monthly_requirement=orig_req,
            scenario_monthly_requirement=sc_req,
            monthly_capacity=round(available, 2),
            capacity_gap=round(gap, 2),
            projected_goal_status=status,
            description=(
                f"Under this scenario, all available monthly capacity ({available:.2f}) is "
                f"directed to '{focus_goal.goal_name}'. "
                f"Other active goals are not funded under this what-if assumption. "
                f"Remaining capacity gap for the focused goal: {gap:.2f}."
            ),
        ))
        sid += 1

    # ------------------------------------------------------------------
    # S5: CAPACITY_CHANGE — model 20% capacity increase
    # ------------------------------------------------------------------
    new_capacity = round(available * 1.20, 2)
    orig_req, sc_req, gap, status, assumptions = compute_capacity_change(
        active_goals=active,
        original_capacity=available,
        new_capacity=new_capacity,
    )
    records.append(ScenarioRecord(
        scenario_id=f"S{sid}",
        scenario_type=ScenarioType.CAPACITY_CHANGE,
        title="What-if: available monthly capacity increases by 20%",
        assumptions=assumptions,
        affected_goals=[g.goal_name for g in active],
        original_monthly_requirement=round(orig_req, 2),
        scenario_monthly_requirement=round(sc_req, 2),
        monthly_capacity=round(new_capacity, 2),
        capacity_gap=round(gap, 2),
        projected_goal_status=status,
        description=(
            f"Under this scenario, available monthly capacity is modelled at {new_capacity:.2f} "
            f"(a 20% increase from the current {available:.2f}). "
            f"Goal contribution requirements remain unchanged at {sc_req:.2f}. "
            f"Remaining shortfall under this scenario: {gap:.2f}."
        ),
    ))

    return records
