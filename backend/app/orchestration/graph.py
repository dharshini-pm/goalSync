"""LangGraph StateGraph assembly for the GoalSync multi-agent pipeline.

Execution order (sequential, no parallelism in v1):
  START
    → transaction
    → financial_state
    → goal
    → conflict
    → scenario
    → explanation
    → END
"""

from __future__ import annotations

from langgraph.graph import StateGraph, START, END

from .state import GoalSyncState
from .nodes import (
    transaction_node,
    financial_state_node,
    goal_node,
    conflict_node,
    scenario_node,
    explanation_node,
)


def build_graph():
    """Build and compile the GoalSync StateGraph.

    Returns a compiled LangGraph that accepts GoalSyncState and
    executes all six agent nodes in the prescribed sequential order.
    """
    graph = StateGraph(GoalSyncState)

    # Register nodes
    graph.add_node("transaction", transaction_node)
    graph.add_node("financial_state", financial_state_node)
    graph.add_node("goal", goal_node)
    graph.add_node("conflict", conflict_node)
    graph.add_node("scenario", scenario_node)
    graph.add_node("explanation", explanation_node)

    # Wire sequential edges
    graph.add_edge(START, "transaction")
    graph.add_edge("transaction", "financial_state")
    graph.add_edge("financial_state", "goal")
    graph.add_edge("goal", "conflict")
    graph.add_edge("conflict", "scenario")
    graph.add_edge("scenario", "explanation")
    graph.add_edge("explanation", END)

    return graph.compile()
