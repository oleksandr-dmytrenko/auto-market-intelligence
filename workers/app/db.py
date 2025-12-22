import contextlib
import os
from typing import Iterator

import psycopg2
import psycopg2.extras

from .config import DATABASE_URL


@contextlib.contextmanager
def get_connection() -> Iterator[psycopg2.extensions.connection]:
    conn = psycopg2.connect(DATABASE_URL)
    try:
        yield conn
    finally:
        conn.close()


def fetch_search_query(search_query_id: int) -> dict | None:
    with get_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM search_queries WHERE id = %s",
                (search_query_id,),
            )
            row = cur.fetchone()
            return dict(row) if row else None









