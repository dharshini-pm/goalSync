"""SQLAlchemy database and collection access layer for GoalSync (SQLite).

Provides SQLite database connectivity, ORM session management, table creation,
and an adapter collection layer preserving existing data-access patterns.
"""

from __future__ import annotations

import os
from copy import deepcopy
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Union

from sqlalchemy import (
    create_engine,
    event,
    select,
    delete,
    or_,
    and_,
    desc,
    asc,
    text,
)
from sqlalchemy.engine import Engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker, Session

from app.config import settings
from app.models import (
    Base,
    generate_id,
    utc_now,
    User,
    FinancialProfile,
    Goal,
    Transaction,
    TransactionProcessingRecord,
    DeviceMapping,
)


class DuplicateKeyError(ValueError):
    """Raised when a unique constraint in SQLite is violated (replaces pymongo DuplicateKeyError)."""
    pass


class ObjectId(str):
    """Compatibility class for MongoDB ObjectId during transition to SQLite.
    
    Generates a 24-character hexadecimal string if no value is provided,
    and stringifies any passed value.
    """
    def __new__(cls, val=None):
        if val is None:
            val = generate_id()
        elif isinstance(val, ObjectId):
            return val
        return super().__new__(cls, str(val))


# Model mapping by table / collection name
COLLECTION_MODEL_MAP = {
    "users": User,
    "financial_profiles": FinancialProfile,
    "goals": Goal,
    "transactions": Transaction,
    "transaction_processing_records": TransactionProcessingRecord,
    "device_mappings": DeviceMapping,
}

_engine: Optional[Engine] = None
_SessionLocal: Optional[sessionmaker] = None


def get_engine() -> Engine:
    """Returns or creates the active SQLAlchemy SQLite engine with WAL pragma."""
    global _engine
    if _engine is None:
        db_path = os.path.abspath(settings.SQLITE_DB_PATH)
        parent_dir = os.path.dirname(db_path)
        if parent_dir:
            os.makedirs(parent_dir, exist_ok=True)

        db_url = f"sqlite:///{db_path}"
        _engine = create_engine(
            db_url,
            connect_args={"check_same_thread": False, "timeout": 30},
        )

        @event.listens_for(_engine, "connect")
        def set_sqlite_pragma(dbapi_connection, connection_record):
            cursor = dbapi_connection.cursor()
            try:
                cursor.execute("PRAGMA journal_mode=WAL")
                cursor.execute("PRAGMA synchronous=NORMAL")
                cursor.execute("PRAGMA foreign_keys=ON")
            finally:
                cursor.close()

    return _engine


def get_session_factory() -> sessionmaker:
    """Returns or creates the sessionmaker bound to the active engine."""
    global _SessionLocal
    if _SessionLocal is None:
        _SessionLocal = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=get_engine(),
            expire_on_commit=False,
        )
    return _SessionLocal


def set_engine(engine: Engine) -> None:
    """Overrides the engine and session factory (used for in-memory testing)."""
    global _engine, _SessionLocal
    _engine = engine
    _SessionLocal = sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=_engine,
        expire_on_commit=False,
    )


def reset_engine() -> None:
    """Resets the engine and session factory back to default configuration."""
    global _engine, _SessionLocal
    _engine = None
    _SessionLocal = None


def get_db():
    """FastAPI dependency for obtaining a database session."""
    session_factory = get_session_factory()
    session: Session = session_factory()
    try:
        yield session
    finally:
        session.close()


def init_db(engine: Optional[Engine] = None) -> None:
    """Creates SQLite database and all required tables and indexes."""
    eng = engine or get_engine()
    Base.metadata.create_all(bind=eng)


# Backward compatibility alias for app.main lifespan
init_indexes = init_db


class InsertOneResult:
    def __init__(self, inserted_id: str):
        self.inserted_id = inserted_id


class InsertManyResult:
    def __init__(self, inserted_ids: List[str]):
        self.inserted_ids = inserted_ids


class UpdateResult:
    def __init__(self, matched_count: int, modified_count: int):
        self.matched_count = matched_count
        self.modified_count = modified_count


class DeleteResult:
    def __init__(self, deleted_count: int):
        self.deleted_count = deleted_count


class SQLiteCursor:
    """Cursor wrapper that mimics MongoDB cursor behavior with sorting, limit, and iteration."""

    def __init__(self, collection: SQLiteCollection, filter_dict: Optional[Dict[str, Any]] = None):
        self._collection = collection
        self._filter_dict = filter_dict or {}
        self._sort_specs: List[tuple] = []
        self._limit_val: Optional[int] = None

    def sort(self, key_or_list: Union[str, List[tuple]], direction: int = 1) -> SQLiteCursor:
        if isinstance(key_or_list, list):
            self._sort_specs.extend(key_or_list)
        elif isinstance(key_or_list, tuple):
            self._sort_specs.append(key_or_list)
        else:
            self._sort_specs.append((key_or_list, direction))
        return self

    def limit(self, n: int) -> SQLiteCursor:
        self._limit_val = n
        return self

    def _execute(self) -> List[Dict[str, Any]]:
        return self._collection._query(
            filter_dict=self._filter_dict,
            sort_specs=self._sort_specs,
            limit=self._limit_val,
        )

    def __iter__(self):
        return iter(self._execute())

    def __len__(self) -> int:
        return len(self._execute())

    def __getitem__(self, index: int) -> Dict[str, Any]:
        return self._execute()[index]


class SQLiteCollection:
    """Adapter wrapping SQLAlchemy operations with collection-style interface.
    
    Preserves all existing collection queries and mutations while executing
    against local SQLite tables.
    """

    def __init__(self, name: str):
        self.name = name
        self.model_cls = COLLECTION_MODEL_MAP.get(name)

    def _get_session(self) -> Session:
        return get_session_factory()()

    def _build_clauses(self, filter_dict: Dict[str, Any]) -> List[Any]:
        if not self.model_cls:
            return []

        clauses = []
        for k, v in filter_dict.items():
            if k == "$or":
                or_conditions = []
                for sub_filter in v:
                    sub_clauses = self._build_clauses(sub_filter)
                    if sub_clauses:
                        or_conditions.append(and_(*sub_clauses))
                if or_conditions:
                    clauses.append(or_(*or_conditions))
            elif k == "_id":
                val = str(v) if v is not None else None
                clauses.append(self.model_cls.id == val)
            elif k == "userId":
                val = str(v) if v is not None else None
                clauses.append(self.model_cls.userId == val)
            else:
                if hasattr(self.model_cls, k):
                    col = getattr(self.model_cls, k)
                    val = str(v) if isinstance(v, ObjectId) else v
                    clauses.append(col == val)
        return clauses

    def _query(
        self,
        filter_dict: Dict[str, Any],
        sort_specs: Optional[List[tuple]] = None,
        limit: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        if not self.model_cls:
            return []

        session = self._get_session()
        try:
            stmt = select(self.model_cls)
            clauses = self._build_clauses(filter_dict)
            if clauses:
                stmt = stmt.where(and_(*clauses))

            if sort_specs:
                for col_name, direction in sort_specs:
                    col_attr = self.model_cls.id if col_name == "_id" else getattr(self.model_cls, col_name, None)
                    if col_attr is not None:
                        stmt = stmt.order_by(desc(col_attr) if direction in (-1, "desc", "DESC") else asc(col_attr))

            if limit is not None:
                stmt = stmt.limit(limit)

            rows = session.scalars(stmt).all()
            return [row.to_dict() for row in rows]
        finally:
            session.close()

    def find_one(
        self,
        filter_dict: Optional[Dict[str, Any]] = None,
        sort: Optional[Union[tuple, List[tuple]]] = None,
    ) -> Optional[Dict[str, Any]]:
        filter_dict = filter_dict or {}
        sort_specs = []
        if sort:
            if isinstance(sort, list):
                sort_specs.extend(sort)
            elif isinstance(sort, tuple):
                sort_specs.append(sort)

        results = self._query(filter_dict=filter_dict, sort_specs=sort_specs, limit=1)
        return results[0] if results else None

    def find(self, filter_dict: Optional[Dict[str, Any]] = None) -> SQLiteCursor:
        return SQLiteCursor(self, filter_dict)

    def insert_one(self, doc: Dict[str, Any]) -> InsertOneResult:
        if not self.model_cls:
            raise ValueError(f"No SQLite model registered for collection '{self.name}'")

        doc_data = deepcopy(doc)
        item_id = str(doc_data.get("_id") or generate_id())
        doc_data["_id"] = item_id

        # Map document data to model column names
        field_kwargs = {}
        for col in self.model_cls.__table__.columns:
            col_name = col.name
            key = "_id" if col_name == "_id" else col_name
            if key in doc_data:
                val = doc_data[key]
                if key == "_id":
                    val = item_id
                elif isinstance(val, ObjectId):
                    val = str(val)
                elif key in ("userId", "transactionId") and val is not None:
                    val = str(val)
                field_kwargs[col_name] = val

        session = self._get_session()
        try:
            instance = self.model_cls(**field_kwargs)
            session.add(instance)
            session.commit()
            return InsertOneResult(item_id)
        except IntegrityError as exc:
            session.rollback()
            raise DuplicateKeyError(f"Duplicate key error on '{self.name}': {str(exc)}") from exc
        finally:
            session.close()

    def insert_many(self, docs: List[Dict[str, Any]]) -> InsertManyResult:
        ids = []
        for d in docs:
            res = self.insert_one(d)
            ids.append(res.inserted_id)
        return InsertManyResult(ids)

    def update_one(self, filter_dict: Dict[str, Any], update_dict: Dict[str, Any]) -> UpdateResult:
        if not self.model_cls:
            return UpdateResult(0, 0)

        session = self._get_session()
        try:
            stmt = select(self.model_cls)
            clauses = self._build_clauses(filter_dict)
            if clauses:
                stmt = stmt.where(and_(*clauses))
            instance = session.scalars(stmt).first()
            if not instance:
                return UpdateResult(0, 0)

            # Support MongoDB $set syntax or raw dict
            fields = update_dict.get("$set", update_dict)
            for k, v in fields.items():
                if k == "_id":
                    continue
                col_name = k
                if hasattr(instance, col_name):
                    val = str(v) if isinstance(v, ObjectId) else v
                    if col_name in ("userId", "transactionId") and val is not None:
                        val = str(val)
                    setattr(instance, col_name, val)

            if hasattr(instance, "updatedAt"):
                instance.updatedAt = utc_now()

            session.commit()
            return UpdateResult(1, 1)
        except IntegrityError as exc:
            session.rollback()
            raise DuplicateKeyError(f"Duplicate key error updating '{self.name}': {str(exc)}") from exc
        finally:
            session.close()

    def delete_one(self, filter_dict: Dict[str, Any]) -> DeleteResult:
        if not self.model_cls:
            return DeleteResult(0)

        session = self._get_session()
        try:
            stmt = select(self.model_cls)
            clauses = self._build_clauses(filter_dict)
            if clauses:
                stmt = stmt.where(and_(*clauses))
            instance = session.scalars(stmt).first()
            if not instance:
                return DeleteResult(0)

            session.delete(instance)
            session.commit()
            return DeleteResult(1)
        finally:
            session.close()

    def delete_many(self, filter_dict: Dict[str, Any]) -> DeleteResult:
        if not self.model_cls:
            return DeleteResult(0)

        session = self._get_session()
        try:
            clauses = self._build_clauses(filter_dict)
            stmt = delete(self.model_cls)
            if clauses:
                stmt = stmt.where(and_(*clauses))
            result = session.execute(stmt)
            session.commit()
            return DeleteResult(result.rowcount)
        finally:
            session.close()

    def count_documents(self, filter_dict: Optional[Dict[str, Any]] = None) -> int:
        filter_dict = filter_dict or {}
        return len(self._query(filter_dict=filter_dict))


class SQLiteDatabase:
    """Emulates database handle providing collection and command access."""

    def __init__(self, name: str = "goalsync.db"):
        self.name = name

    def command(self, cmd: str) -> Dict[str, Any]:
        """Pings SQLite and returns status dict."""
        if cmd == "ping":
            session = get_session_factory()()
            try:
                session.execute(text("SELECT 1"))
                return {"ok": 1}
            finally:
                session.close()
        return {"ok": 1}

    def __getitem__(self, collection_name: str) -> SQLiteCollection:
        return get_collection(collection_name)

    def __getattr__(self, name: str) -> SQLiteCollection:
        return get_collection(name)


_database_instance: Optional[SQLiteDatabase] = None


def get_database() -> SQLiteDatabase:
    """Returns the GoalSync SQLite database handle."""
    global _database_instance
    if _database_instance is None:
        _database_instance = SQLiteDatabase(settings.DATABASE_NAME)
    return _database_instance


def get_collection(collection_name: str) -> SQLiteCollection:
    """Returns a specific collection adapter from the GoalSync SQLite database."""
    return SQLiteCollection(collection_name)


class SQLiteClient:
    """Client wrapper providing database handle."""

    def __getitem__(self, name: str) -> SQLiteDatabase:
        return get_database()

    def close(self):
        pass


def get_client() -> SQLiteClient:
    """Returns a client instance for compatibility."""
    return SQLiteClient()
