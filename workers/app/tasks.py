from __future__ import annotations

from datetime import datetime
from typing import Any

from redis import Redis
from rq import Queue

from .config import REDIS_URL
from .db import fetch_search_query


redis_conn = Redis.from_url(REDIS_URL)

# Separate queues for heavy IO and CPU-ish similarity work
ingest_queue = Queue("ingest", connection=redis_conn)
similarity_queue = Queue("similarity", connection=redis_conn)


def enqueue_collect_and_rank(search_query_id: int) -> None:
    """
    Entry point to be called from Rails (via Redis or HTTP bridge).

    It schedules provider collection followed by similarity computation.
    """
    ingest_queue.enqueue(collect_provider_data, search_query_id)
    similarity_queue.enqueue(compute_similarity, search_query_id)


def collect_provider_data(search_query_id: int) -> None:
    """
    Fetch / refresh data for the given query from external providers.

    MVP: this is a stub where provider-specific adapters (copart, iaai, ...)
    should be plugged in. They normalize data into the vehicle_listings table.
    """
    query = fetch_search_query(search_query_id)
    if not query:
        return

    # TODO: implement real provider fetchers here.
    # For MVP skeleton we just rely on existing data in vehicle_listings.
    _mark_search_processing(search_query_id)


def compute_similarity(search_query_id: int) -> None:
    """
    Compute similarity scores and aggregate price statistics for a query.

    This follows the high-level algorithm described in the architecture doc:
    select candidates in SQL, then apply a weighted scoring in Python and
    persist the top 10–15 and a price_estimates row.
    """
    query = fetch_search_query(search_query_id)
    if not query:
        return

    # TODO: implement candidate selection + similarity scoring + writes.
    # This module is intentionally kept as a thin orchestration layer; the
    # actual logic can be broken into smaller helpers as it grows.
    _mark_search_completed(search_query_id)


def _mark_search_processing(search_query_id: int) -> None:
    from .db import get_connection

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE search_queries SET status = %s WHERE id = %s",
                ("processing", search_query_id),
            )
        conn.commit()


def _mark_search_completed(search_query_id: int) -> None:
    from .db import get_connection

    now = datetime.utcnow()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE search_queries SET status = %s, completed_at = %s WHERE id = %s",
                ("completed", now, search_query_id),
            )
        conn.commit()










