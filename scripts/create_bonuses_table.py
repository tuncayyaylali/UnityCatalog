import os
import sys
import json
import uuid
import subprocess
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

import pyarrow as pa
from pyiceberg.catalog.sql import SqlCatalog
from pyiceberg.schema import Schema
from pyiceberg.types import NestedField, StringType, DoubleType, IntegerType
from minio import Minio

# 1. Initialize PyIceberg SqlCatalog
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

# 2. Create namespace
try:
    catalog.create_namespace("finance_schema")
    print("Namespace finance_schema created in catalog.db.")
except Exception as e:
    print("Namespace note:", e)

# 3. Schema Definition
schema = Schema(
    NestedField(field_id=1, name="emp_id", field_type=StringType(), required=True),
    NestedField(field_id=2, name="annual_bonus", field_type=DoubleType(), required=True),
    NestedField(field_id=3, name="performance_score", field_type=DoubleType(), required=True),
    NestedField(field_id=4, name="fiscal_year", field_type=IntegerType(), required=True),
)

# 4. Create or recreate table
table_identifier = ("finance_schema", "bonuses")
try:
    catalog.drop_table(table_identifier)
    print("Dropped existing table from catalog.db.")
except Exception:
    pass

table = catalog.create_table(
    identifier=table_identifier,
    schema=schema,
    location="s3://warehouse/finance_schema/bonuses",
)
print("Table created at:", table.location())

# 5. Prepare data matching Iceberg schema
arrow_schema = table.schema().as_arrow()

data = [
    ("EMP001", 18500.0, 4.8, 2026),
    ("EMP002", 14200.0, 4.5, 2026),
    ("EMP003", 16000.0, 4.7, 2026),
    ("EMP004", 15500.0, 4.6, 2026),
    ("EMP005", 9800.0, 4.1, 2026),
]

arrow_table = pa.Table.from_arrays(
    [
        pa.array([r[0] for r in data], type=pa.string()),
        pa.array([r[1] for r in data], type=pa.float64()),
        pa.array([r[2] for r in data], type=pa.float64()),
        pa.array([r[3] for r in data], type=pa.int32()),
    ],
    schema=arrow_schema,
)

table.append(arrow_table)
print("Data appended successfully. Current metadata location:", table.metadata_location)

# 6. Retrieve the latest metadata JSON from MinIO
# table.metadata_location is e.g. s3://warehouse/finance_schema/bonuses/metadata/00001-xxxx.metadata.json
metadata_s3_path = table.metadata_location
print("Reading metadata from:", metadata_s3_path)

minio_client = Minio(
    "localhost:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=False,
)

# Parse bucket and key
s3_prefix = "s3://warehouse/"
if metadata_s3_path.startswith(s3_prefix):
    object_key = metadata_s3_path[len(s3_prefix):]
else:
    # fallback strip s3://
    parts = metadata_s3_path.replace("s3://", "").split("/", 1)
    object_key = parts[1]

response = minio_client.get_object("warehouse", object_key)
metadata_bytes = response.read()
response.close()
response.release_conn()

local_meta_path = os.path.join(os.path.dirname(__file__), "bonuses.metadata.json")
with open(local_meta_path, "wb") as f:
    f.write(metadata_bytes)
print("Saved local metadata copy to:", local_meta_path)

# 7. Copy metadata into unitycatalog pod
remote_dir = "/home/unitycatalog/etc/data/external/unity/finance_schema/tables/bonuses/metadata"
remote_file = f"{remote_dir}/00001.metadata.json"

pod_out = subprocess.check_output(
    ["kubectl", "get", "pods", "-n", "lakehouse", "-l", "app=unitycatalog", "-o", "jsonpath={.items[0].metadata.name}"]
).decode("utf-8").strip()

subprocess.run(["kubectl", "exec", "-n", "lakehouse", pod_out, "--", "mkdir", "-p", remote_dir], check=True)
cp_process = subprocess.run(
    ["kubectl", "exec", "-i", "-n", "lakehouse", pod_out, "--", "sh", "-c", f"cat > {remote_file}"],
    input=metadata_bytes,
    check=True,
)
print(f"Copied metadata to unitycatalog pod: {remote_file}")

# 8. Register schema and table into PostgreSQL unity_catalog database
# Check or insert schema into uc_schemas
schema_id = str(uuid.uuid4())
table_id = str(uuid.uuid4())
catalog_id = "59181d95-be8c-4d9e-ac66-7c4f813030b2" # unity catalog id

psql_script = f"""
DO $$
DECLARE
    v_schema_id uuid;
    v_catalog_id uuid := '{catalog_id}';
BEGIN
    SELECT id INTO v_schema_id FROM uc_schemas WHERE name = 'finance_schema';
    IF v_schema_id IS NULL THEN
        v_schema_id := '{schema_id}';
        INSERT INTO uc_schemas (id, name, catalog_id, created_at, updated_at)
        VALUES (v_schema_id, 'finance_schema', v_catalog_id, NOW(), NOW());
        RAISE NOTICE 'Created uc_schema finance_schema: %', v_schema_id;
    ELSE
        RAISE NOTICE 'Found existing uc_schema finance_schema: %', v_schema_id;
    END IF;

    -- Delete existing uc_tables entry for bonuses if exists
    DELETE FROM uc_tables WHERE name = 'bonuses' AND schema_id = v_schema_id;

    -- Insert uc_tables entry
    INSERT INTO uc_tables (
        id, name, column_count, data_source_format, schema_id, type,
        uniform_iceberg_metadata_location, url, created_at, updated_at
    ) VALUES (
        '{table_id}',
        'bonuses',
        0,
        'DELTA',
        v_schema_id,
        'EXTERNAL',
        'file://{remote_file}',
        's3://warehouse/finance_schema/bonuses',
        NOW(),
        NOW()
    );
    RAISE NOTICE 'Registered uc_tables bonuses: {table_id}';
END $$;
"""

reg_process = subprocess.run(
    ["kubectl", "exec", "-i", "-n", "lakehouse", "deployment/postgres", "--", "psql", "-U", "postgres", "-d", "unity_catalog"],
    input=psql_script.encode("utf-8"),
    capture_output=True,
    check=True,
)
print("PostgreSQL Unity Catalog registration result:")
print(reg_process.stdout.decode("utf-8"))
print("Bonuses table creation and registration completed successfully!")
