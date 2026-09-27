"""GoalSync AI Agents Layer."""

from .transaction_agent import (
    TransactionAgentInput,
    TransactionAgentResult,
    AgentConfidence as TransactionAgentConfidence,
    TransactionTypeCategory,
    TransactionAgent,
    TransactionAgentService,
    OllamaClient,
    OllamaUnavailableError,
)
from .financial_state_agent import (
    FinancialStateAgentInput,
    FinancialStateAgentResult,
    FinancialStatus,
    CashFlowStatus,
    FinancialStateAgent,
    FinancialStateAgentService,
)
from .goal_agent import (
    GoalAgentInput,
    GoalAgentResult,
    GoalStatus,
    GoalFeasibility,
    GoalAgent,
    GoalAgentService,
)
from .conflict_agent import (
    ConflictAgentInput,
    ConflictAgentResult,
    ConflictRecord,
    GoalConflictSnapshot,
    ConflictType,
    ConflictSeverity,
    OverallStatus,
    ConflictAgent,
    ConflictAgentService,
)
from .scenario_agent import (
    ScenarioAgentInput,
    ScenarioAgentResult,
    ScenarioRecord,
    GoalScenarioSnapshot,
    ConflictSummary,
    ScenarioType,
    ProjectedGoalStatus,
    AgentConfidence as ScenarioAgentConfidence,
    ScenarioAgent,
    ScenarioAgentService,
)

__all__ = [
    # Transaction Agent
    "TransactionAgentInput",
    "TransactionAgentResult",
    "TransactionAgentConfidence",
    "TransactionTypeCategory",
    "TransactionAgent",
    "TransactionAgentService",
    "OllamaClient",
    "OllamaUnavailableError",
    # Financial State Agent
    "FinancialStateAgentInput",
    "FinancialStateAgentResult",
    "FinancialStatus",
    "CashFlowStatus",
    "FinancialStateAgent",
    "FinancialStateAgentService",
    # Goal Agent
    "GoalAgentInput",
    "GoalAgentResult",
    "GoalStatus",
    "GoalFeasibility",
    "GoalAgent",
    "GoalAgentService",
    # Conflict Agent
    "ConflictAgentInput",
    "ConflictAgentResult",
    "ConflictRecord",
    "GoalConflictSnapshot",
    "ConflictType",
    "ConflictSeverity",
    "OverallStatus",
    "ConflictAgent",
    "ConflictAgentService",
    # Scenario Agent
    "ScenarioAgentInput",
    "ScenarioAgentResult",
    "ScenarioRecord",
    "GoalScenarioSnapshot",
    "ConflictSummary",
    "ScenarioType",
    "ProjectedGoalStatus",
    "ScenarioAgentConfidence",
    "ScenarioAgent",
    "ScenarioAgentService",
]
from .explanation_agent import (
    ExplanationAgentInput,
    ExplanationAgentResult,
    GoalExplanationSnapshot,
    ConflictExplanationSnapshot,
    ScenarioExplanationSnapshot,
    GoalImpactExplanation,
    ConflictExplanationOutput,
    ScenarioExplanationOutput,
    ExplanationAgent,
    ExplanationAgentService,
)

__all__ += [
    # Explanation Agent
    "ExplanationAgentInput",
    "ExplanationAgentResult",
    "GoalExplanationSnapshot",
    "ConflictExplanationSnapshot",
    "ScenarioExplanationSnapshot",
    "GoalImpactExplanation",
    "ConflictExplanationOutput",
    "ScenarioExplanationOutput",
    "ExplanationAgent",
    "ExplanationAgentService",
]
