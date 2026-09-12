import os
from datetime import datetime, timezone
import pyarrow as pa
from pyiceberg.catalog import load_catalog
from pyiceberg.schema import Schema
from pyiceberg.types import NestedField, StringType, TimestampType

# Define Iceberg schema matching AGENTS.md requirements
schema = Schema(
    NestedField(field_id=1, name="event_id", field_type=StringType(), required=True),
    NestedField(field_id=2, name="user_id", field_type=StringType(), required=True),
    NestedField(field_id=3, name="event_type", field_type=StringType(), required=True),
    NestedField(field_id=4, name="page_url", field_type=StringType(), required=True),
    NestedField(field_id=5, name="event_timestamp", field_type=TimestampType(), required=True),
)

print("Schema created:", schema)

