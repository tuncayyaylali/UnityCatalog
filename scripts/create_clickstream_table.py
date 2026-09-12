import os
import sys
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

import pyarrow as pa
from pyiceberg.catalog.sql import SqlCatalog
from pyiceberg.schema import Schema
from pyiceberg.types import NestedField, StringType, TimestamptzType

catalog = SqlCatalog(
    "lakehouse",
    **{
        "uri": "sqlite:///catalog.db",
        "warehouse": "s3://warehouse",
        "s3.endpoint": "http://localhost:9000",
        "s3.access-key-id": "minioadmin",
        "s3.secret-access-key": "minioadmin",
        "s3.region": "us-east-1",
    },
)

# 1. Create namespace
try:
    catalog.create_namespace("analytics_schema")
    print("Namespace analytics_schema created.")
except Exception as e:
    print("Namespace note:", e)

# 2. Schema
schema = Schema(
    NestedField(field_id=1, name="event_id", field_type=StringType(), required=True),
    NestedField(field_id=2, name="user_id", field_type=StringType(), required=True),
    NestedField(field_id=3, name="event_type", field_type=StringType(), required=True),
    NestedField(field_id=4, name="page_url", field_type=StringType(), required=True),
    NestedField(field_id=5, name="event_timestamp", field_type=TimestamptzType(), required=True),
)

# 3. Create or drop/recreate table
table_identifier = ("analytics_schema", "clickstream")
try:
    catalog.drop_table(table_identifier)
    print("Dropped existing table.")
except Exception:
    pass

table = catalog.create_table(
    identifier=table_identifier,
    schema=schema,
    location="s3://warehouse/analytics_schema/clickstream",
)
print("Table created at:", table.location())

# 4. Prepare data matching Iceberg arrow schema
arrow_schema = table.schema().as_arrow()

data = [
    ("evt_001", "usr_001", "page_view", "/home", datetime(2026, 9, 12, 10, 15, 0, tzinfo=timezone.utc)),
    ("evt_002", "usr_001", "click", "/products", datetime(2026, 9, 12, 10, 18, 22, tzinfo=timezone.utc)),
    ("evt_003", "usr_001", "click", "/cart", datetime(2026, 9, 12, 10, 20, 5, tzinfo=timezone.utc)),
    ("evt_004", "usr_002", "page_view", "/home", datetime(2026, 9, 12, 11, 0, 10, tzinfo=timezone.utc)),
    ("evt_005", "usr_002", "click", "/pricing", datetime(2026, 9, 12, 11, 5, 40, tzinfo=timezone.utc)),
    ("evt_006", "usr_003", "page_view", "/blog", datetime(2026, 9, 12, 12, 30, 15, tzinfo=timezone.utc)),
    ("evt_007", "usr_004", "page_view", "/login", datetime(2026, 9, 12, 13, 0, 0, tzinfo=timezone.utc)),
    ("evt_008", "usr_005", "page_view", "/products", datetime(2026, 9, 12, 14, 10, 0, tzinfo=timezone.utc)),
    ("evt_009", "usr_005", "click", "/checkout", datetime(2026, 9, 12, 14, 15, 30, tzinfo=timezone.utc)),
    ("evt_010", "usr_001", "purchase", "/thank-you", datetime(2026, 9, 12, 10, 25, 0, tzinfo=timezone.utc)),
]

arrow_table = pa.Table.from_arrays(
    [
        pa.array([r[0] for r in data], type=pa.string()),
        pa.array([r[1] for r in data], type=pa.string()),
        pa.array([r[2] for r in data], type=pa.string()),
        pa.array([r[3] for r in data], type=pa.string()),
        pa.array([r[4] for r in data], type=pa.timestamp("us", tz="UTC")),
    ],
    schema=arrow_schema,
)

table.append(arrow_table)
print("Data appended successfully. Current metadata location:", table.metadata_location)
