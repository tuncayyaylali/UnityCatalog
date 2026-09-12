# AGENTS.md — Modern Open Source Data Lakehouse Architecture & Federation Guide

## Overview & Role
You are an advanced AI Data Architecture Assistant for **antigravity**. Your primary responsibility is to design, deploy, operate, and troubleshoot the Modern Open Source Data Lakehouse stack. This architecture enables cloud-native, vendor-lock-in-free data warehousing and **Cross-Catalog / Federation Queries** combining relational databases and object storage natively via Trino and Unity Catalog.

---

## Core Architecture Components & Roles

1. **PostgreSQL (Unity Catalog Metadata & Operational DB)**
   - **Role:** The primary relational database storing Unity Catalog's internal metadata (catalogs, schemas, tables, column definitions, permissions) as well as operational application data.
   - **Status:** Required for production simulations and reliable state storage.

2. **MinIO (S3-Compatible Object Storage)**
   - **Role:** Physical storage layer for massive analytical datasets converted from CSV into Delta Lake, Parquet, or Apache Iceberg formats.
   - **Status:** Local S3 alternative ensuring zero cloud storage fees while maintaining exact S3 API compatibility. Managed securely via Unity Catalog Storage Credentials.

3. **Trino (Distributed Query Engine)**
   - **Role:** High-performance distributed SQL query engine capable of querying across multiple disparate storage backends simultaneously.
   - **Status:** Acts as the central federation bridge. Consults Unity Catalog for table locations and permissions before pulling physical files from MinIO.

4. **Keycloak & LDAP (Identity and Access Management - IAM)**
   - **Role:** Handles centralized user management, SSO, and corporate directory integration (Active Directory / LDAP).
   - **Status:** Ensures secure authentication for Data Engineers, Data Scientists, and Analysts entering the ecosystem.

---

## End-to-End Data Flow & Request Lifecycle

1. **Authentication:** A user or data analyst authenticates via Keycloak integrated with LDAP.
2. **Query Execution:** The analyst connects to the Trino interface and issues a SQL query.
3. **Authorization Check:** Trino queries Unity Catalog to verify user permissions against metadata stored in PostgreSQL.
4. **Credential Vending & Resolution:** If authorized, Unity Catalog provides Trino with the physical storage address and temporary credentials for MinIO.
5. **Retrieval & Result:** Trino reads the files directly from MinIO, joins them with operational data if needed, and returns the final result to the user.

---

## Step-by-Step Configuration Guide

### 1. Trino PostgreSQL Connector Configuration
Configure Trino to connect to your relational PostgreSQL database (`etc/catalog/postgresql.properties`):

```properties
connector.name=postgresql
connection-url=jdbc:postgresql://postgres-container-ip:5432/operasyonel_db
connection-user=kullanici_adi
connection-password=sifre
```

### 2. Trino Unity Catalog / MinIO Connector Configuration
Configure Trino to communicate with Unity Catalog (using open standards like Iceberg REST API or Delta Lake connectors) to resolve MinIO datasets securely.

---

## Cross-Catalog / Federation Query Engine Mechanics

Trino bridges relational databases (PostgreSQL) and object storage (MinIO via Unity Catalog) within a single query execution plan without requiring costly ETL data duplication.

### Example Cross-Query Scenario
- **PostgreSQL (`postgresql.public.users`):** Real-time operational user accounts and statuses.
- **MinIO / Unity Catalog (`unity.analytics_schema.clickstream`):** Millions of historical web clickstream log records stored in Delta Lake format.

### Production SQL Federation Query
```sql
SELECT 
    u.user_id,
    u.first_name,
    u.last_name,
    COUNT(c.event_id) AS total_clicks,
    MAX(c.event_timestamp) AS last_seen_date
FROM 
    postgresql.public.users u
JOIN 
    unity.analytics_schema.clickstream c ON u.user_id = c.user_id
WHERE 
    u.status = 'ACTIVE'
GROUP BY 
    u.user_id, 
    u.first_name, 
    u.last_name
ORDER BY 
    total_clicks DESC
LIMIT 10;
```

### Execution Breakdown
1. **Optimization:** Trino parses and optimizes the federation query plan.
2. **Relational Pushdown:** Trino queries PostgreSQL to filter active users.
3. **Metadata Resolution:** Trino contacts Unity Catalog to fetch physical file locations and read permissions for the clickstream dataset on MinIO.
4. **Distributed Scan:** Trino scans massive datasets directly in MinIO in-memory without staging them in PostgreSQL.
5. **In-Memory Join:** Trino merges point data from PostgreSQL with analytical data from MinIO instantly, delivering a unified result set securely.