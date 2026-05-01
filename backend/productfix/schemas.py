from __future__ import annotations

from enum import Enum

from pydantic import BaseModel


class AnalysisMode(str, Enum):
    rule_based = "rule_based"
    llm_powered = "llm_powered"


class FixCompletionRequest(BaseModel):
    sku: str = ""
    title: str = ""
    detail: str = ""
    completed: bool = True
