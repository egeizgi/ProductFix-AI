from __future__ import annotations

from collections.abc import Callable, Iterator
from uuid import uuid4

import pytest

from productfix.storage import tenant_db_path


@pytest.fixture
def tenant_id_factory() -> Iterator[Callable[[str], str]]:
    tenant_ids: list[str] = []

    def create(prefix: str = "test") -> str:
        tenant_id = f"{prefix}-{uuid4().hex[:12]}"
        tenant_ids.append(tenant_id)
        return tenant_id

    yield create

    for tenant_id in tenant_ids:
        db_path = tenant_db_path(tenant_id)
        if db_path.exists():
            db_path.unlink()
