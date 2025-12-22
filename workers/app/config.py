import os


REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
DATABASE_URL = os.getenv("DATABASE_URL", "postgres://postgres:postgres@postgres:5432/backend_development")

# Simple provider registry for pluggable integrations
PROVIDERS = {
    "copart": {
        "enabled": True,
    },
    "iaai": {
        "enabled": True,
    },
}






