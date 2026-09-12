param (
    [string]$Namespace = "lakehouse"
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " Lakehouse RBAC & Data Governance Federation Demo                " -ForegroundColor Cyan
Write-Host " Comparing Access: Admin (Full Access) vs Analyst (Restricted)   " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Get Trino Pod Name
$trinoPod = (kubectl get pods -n $Namespace -l app=trino -o jsonpath='{.items[0].metadata.name}')
if (-not $trinoPod) {
    Write-Error "Trino pod not found in $Namespace namespace!"
    exit 1
}
Write-Host "Trino Pod: $trinoPod" -ForegroundColor Gray

# 2. Wait for Trino to be fully ready
Write-Host "`n[Check 0] Ensuring Trino server is ready..." -ForegroundColor Yellow
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    $info = kubectl exec -n $Namespace $trinoPod -- trino --user admin --execute "SELECT 1;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    Write-Error "Trino server did not become ready in time."
    exit 1
}
Write-Host "Trino server is READY.`n" -ForegroundColor Green

# 3. Federated Query
$federatedPayrollQuery = @"
SELECT 
    s.emp_id,
    s.employee_name,
    s.department,
    s.base_salary,
    b.annual_bonus,
    (s.base_salary + b.annual_bonus) AS total_compensation,
    b.performance_score
FROM 
    postgresql.public.salaries s
JOIN 
    unity.finance_schema.bonuses b ON s.emp_id = b.emp_id
ORDER BY 
    total_compensation DESC;
"@

# -------------------------------------------------------------
# TEST 1: ADMIN EXECUTING FEDERATION QUERY (SHOULD SUCCEED)
# -------------------------------------------------------------
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " TEST 1: [ADMIN] Executing Cross-Catalog Payroll Federation Query " -ForegroundColor Cyan
Write-Host " (PostgreSQL 'salaries' + MinIO / Unity Catalog 'bonuses')        " -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan

$adminResult = kubectl exec -n $Namespace $trinoPod -- trino --user admin --execute "$federatedPayrollQuery" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Admin query executed successfully!" -ForegroundColor Green
    Write-Host "Federated Query Results:" -ForegroundColor White
    $adminResult | ForEach-Object {
        if ($_ -notmatch "WARNING: Unable to create a system terminal") {
            Write-Host "  $_" -ForegroundColor Cyan
        }
    }
} else {
    Write-Error "[FAIL] Admin query failed unexpectedly: $adminResult"
    exit 1
}

# -------------------------------------------------------------
# TEST 2: ANALYST ATTEMPTING FEDERATION QUERY (SHOULD BE DENIED)
# -------------------------------------------------------------
Write-Host "`n------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host " TEST 2: [ANALYST] Attempting to Run Same Sensitive Payroll Query " -ForegroundColor Yellow
Write-Host " Expected Result: ACCESS DENIED by Trino Security Rules           " -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------" -ForegroundColor Yellow

$analystResult = kubectl exec -n $Namespace $trinoPod -- trino --user analyst --execute "$federatedPayrollQuery" 2>&1
if ($analystResult -match "Access Denied" -or $LASTEXITCODE -ne 0) {
    Write-Host "[GOVERNANCE ENFORCED] Query blocked as expected!" -ForegroundColor Green
    Write-Host "Trino Security Policy Output:" -ForegroundColor Red
    $analystResult | ForEach-Object {
        if ($_ -notmatch "WARNING: Unable to create a system terminal") {
            Write-Host "  $_" -ForegroundColor Red
        }
    }
} else {
    Write-Error "[SECURITY BREACH] Analyst was able to run sensitive query! Result: $analystResult"
    exit 1
}

# -------------------------------------------------------------
# TEST 3: ANALYST ATTEMPTING DIRECT ACCESS TO SENSITIVE TABLES
# -------------------------------------------------------------
Write-Host "`n------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host " TEST 3: [ANALYST] Attempting Direct Access to postgresql.public.salaries" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------" -ForegroundColor Yellow

$analystSalariesResult = kubectl exec -n $Namespace $trinoPod -- trino --user analyst --execute "SELECT * FROM postgresql.public.salaries;" 2>&1
if ($analystSalariesResult -match "Access Denied" -or $LASTEXITCODE -ne 0) {
    Write-Host "[GOVERNANCE ENFORCED] Direct access to 'salaries' blocked!" -ForegroundColor Green
    $analystSalariesResult | ForEach-Object {
        if ($_ -notmatch "WARNING: Unable to create a system terminal") {
            Write-Host "  $_" -ForegroundColor Red
        }
    }
} else {
    Write-Error "[SECURITY BREACH] Analyst accessed salaries directly!"
    exit 1
}

# -------------------------------------------------------------
# TEST 4: ANALYST ACCESSING NON-SENSITIVE GENERAL ANALYTICS DATA
# -------------------------------------------------------------
Write-Host "`n------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " TEST 4: [ANALYST] Accessing Non-Sensitive Tables (Regular Duties)" -ForegroundColor Cyan
Write-Host " (PostgreSQL 'users' & MinIO / Unity Catalog 'clickstream')      " -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan

$analystNormalResult = kubectl exec -n $Namespace $trinoPod -- trino --user analyst --execute "SELECT u.user_id, u.first_name, u.status, c.event_type FROM postgresql.public.users u JOIN unity.analytics_schema.clickstream c ON u.user_id = c.user_id LIMIT 3;" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Analyst can access regular analytics datasets as authorized!" -ForegroundColor Green
    Write-Host "Non-sensitive Query Results:" -ForegroundColor White
    $analystNormalResult | ForEach-Object {
        if ($_ -notmatch "WARNING: Unable to create a system terminal") {
            Write-Host "  $_" -ForegroundColor Cyan
        }
    }
} else {
    Write-Error "[FAIL] Analyst should have access to regular tables: $analystNormalResult"
    exit 1
}

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host " RBAC & Data Governance Demo PASSED with 100% Compliance!         " -ForegroundColor Green
Write-Host " - Admin: Full cross-catalog federation authorized                " -ForegroundColor Green
Write-Host " - Analyst: Sensitive HR/Finance data strictly protected          " -ForegroundColor Green
Write-Host " - Analyst: Permitted access to general analytics verified        " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green

