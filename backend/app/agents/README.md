# GoalSync AI Agents — Transaction Agent

The **Transaction Agent** is GoalSync's foundational AI reasoning layer for financial transactions. It is designed with strict architectural isolation, determinism priority, and local-first execution.

---

## Architecture & Hierarchy

```
Transaction Event
       ↓
Deterministic Intelligence (Rule-based & Regex Parsing)
       ↓
Merchant & Category RAG (Exact → Alias → Semantic Vector FAISS)
       ↓
Transaction Agent (Local Ollama / llama3.2)
       ↓
Structured Understanding (Validated JSON)
```

The Transaction Agent is **NOT** a decision-maker or financial calculator. It reasons over structured transaction context to deduce canonical merchant identities, financial meaning, and category alignment, preserving deterministic and RAG ground truth.

---

## Boundaries & Constraints

1. **Local Execution Only:** Runs strictly against local Ollama (`llama3.2`). No cloud APIs (OpenAI, Gemini, Claude, etc.) or external credentials.
2. **Never Invents Data:** If a merchant cannot be confidently identified and no verified RAG evidence exists, the agent preserves the raw merchant name, marks `confidence="low"`, and sets `needs_clarification=true`.
3. **No Financial Advice:** Does NOT generate financial recommendations, goal feasibility assessments, or budget cuts.
4. **Strict JSON Output:** Output is validated against `TransactionAgentResult` before being accepted by the system.
5. **Deterministic Priority:** Verified deterministic categories and RAG results are treated as ground-truth facts.

---

## Schema Contracts

### Input: `TransactionAgentInput`
```python
{
    "merchant": "SWIGGY*ORDER123",
    "amount": 450.0,
    "transaction_type": "debit",
    "payment_method": "UPI",
    "date": "2026-03-27",
    "deterministic_category": "Food",
    "merchant_rag_result": "Swiggy",
    "merchant_rag_confidence": "EXACT"
}
```

### Output: `TransactionAgentResult`
```python
{
    "merchant_name": "Swiggy",
    "category": "Food",
    "transaction_type": "Expense",
    "summary": "Food delivery order via UPI",
    "reasoning": "RAG knowledge identified Swiggy as an online food ordering service.",
    "confidence": "high",
    "needs_clarification": False
}
```
