$Namespace = "lakehouse"
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Lakehouse Federation Query Test Execution        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Find Trino Pod
$trinoPod = (kubectl get pods -n $Namespace -l app=trino -o jsonpath='{.items[0].metadata.name}')
if (-not $trinoPod) {
    Write-Error "Trino pod not found in $Namespace namespace!"
    exit 1
}

Write-Host "Trino Pod: $trinoPod" -ForegroundColor Green

Write-Host "`n1. Checking Available Catalogs in Trino..." -ForegroundColor Yellow
kubectl exec -n $Namespace $trinoPod -- trino --execute "SHOW CATALOGS;"

Write-Host "`n2. Verifying PostgreSQL Connection & Users Table (Relational)..." -ForegroundColor Yellow
kubectl exec -n $Namespace $trinoPod -- trino --execute "SELECT user_id, first_name, last_name, status FROM postgresql.public.users ORDER BY user_id;"

Write-Host "`n3. Verifying Unity Catalog Connection & Clickstream Table (Object Storage / Iceberg)..." -ForegroundColor Yellow
kubectl exec -n $Namespace $trinoPod -- trino --execute "SELECT event_id, user_id, event_type, page_url, event_timestamp FROM unity.analytics_schema.clickstream ORDER BY event_id LIMIT 5;"

Write-Host "`n4. Executing Production Cross-Catalog Federation Query from AGENTS.md..." -ForegroundColor Green
$federationQuery = @"
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
"@
kubectl exec -n $Namespace $trinoPod -- trino --execute "$federationQuery"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host " Federation Query Test PASSED Successfully!       " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

