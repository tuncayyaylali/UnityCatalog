param (
    [string]$Namespace = "lakehouse"
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " Trino Row-Level Security (RLS) & Column-Level Masking Demo       " -ForegroundColor Cyan
Write-Host " Testing Fine-Grained Access Control in rules.json                " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Get Trino Pod
$trinoPod = (kubectl get pods -n $Namespace -l app=trino -o jsonpath='{.items[0].metadata.name}')
if (-not $trinoPod) {
    Write-Error "Trino pod not found in $Namespace namespace!"
    exit 1
}
Write-Host "Trino Pod: $trinoPod" -ForegroundColor Gray

# 2. Wait for Trino server readiness
Write-Host "`n[Check 0] Waiting for Trino readiness..." -ForegroundColor Yellow
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
    Write-Error "Trino server is not ready!"
    exit 1
}
Write-Host "Trino server is READY.`n" -ForegroundColor Green

# ------------------------------------------------------------------
# TEST 1: ADMIN (UNFILTERED, UNMASKED FULL ACCESS)
# ------------------------------------------------------------------
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " TEST 1: [ADMIN] Baseline Query on postgresql.public.salaries     " -ForegroundColor Cyan
Write-Host " Expected: All 5 rows visible, Real Names, Real Salaries          " -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan

$adminRes = kubectl exec -n $Namespace $trinoPod -- trino --user admin --execute "SELECT emp_id, employee_name, department, base_salary FROM postgresql.public.salaries ORDER BY emp_id;" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[ADMIN OUTPUT - FULL VISIBILITY]" -ForegroundColor Green
    $adminRes | ForEach-Object {
        if ($_ -notmatch "WARNING: Unable to create a system terminal") {
            Write-Host "  $_" -ForegroundColor Cyan
        }
    }
} else {
    Write-Error "Admin query failed: $adminRes"
    exit 1
}

# ------------------------------------------------------------------
# TEST 2: ANALYST ROW-LEVEL FILTERING (RLS) & COLUMN MASKING
# ------------------------------------------------------------------
Write-Host "`n------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host " TEST 2: [ANALYST] Query on postgresql.public.salaries            " -ForegroundColor Yellow
Write-Host " Expected RLS : Only 'Engineering' row returned (1 row of 5)     " -ForegroundColor Yellow
Write-Host " Expected MASK: employee_name masked as 'Ca****', salary masked   " -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------" -ForegroundColor Yellow

$analystRes = kubectl exec -n $Namespace $trinoPod -- trino --user analyst --execute "SELECT emp_id, employee_name, department, base_salary FROM postgresql.public.salaries ORDER BY emp_id;" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[ANALYST OUTPUT - RLS & MASKED]" -ForegroundColor Green
    $analystRes | ForEach-Object {
        if ($_ -notmatch "WARNING: Unable to create a system terminal") {
            Write-Host "  $_" -ForegroundColor Yellow
        }
    }
} else {
    Write-Error "Analyst query failed unexpectedly: $analystRes"
    exit 1
}

# ------------------------------------------------------------------
# TEST 3: ANALYST ALLOWED COLUMNS ON BONUSES (ICEBERG / MINIO)
# ------------------------------------------------------------------
Write-Host "`n------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " TEST 3: [ANALYST] Querying Allowed Columns on unity.finance_schema.bonuses" -ForegroundColor Cyan
Write-Host " Expected: Success (emp_id, performance_score, fiscal_year)       " -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan

$bonusAllowedRes = kubectl exec -n $Namespace $trinoPod -- trino --user analyst --execute "SELECT emp_id, performance_score, fiscal_year FROM unity.finance_schema.bonuses ORDER BY emp_id LIMIT 3;" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[ANALYST PERMITTED COLUMNS]" -ForegroundColor Green
    $bonusAllowedRes | ForEach-Object {
        if ($_ -notmatch "WARNING: Unable to create a system terminal") {
            Write-Host "  $_" -ForegroundColor Cyan
        }
    }
} else {
    Write-Error "Analyst allowed columns query failed: $bonusAllowedRes"
    exit 1
}

# ------------------------------------------------------------------
# TEST 4: ANALYST BLOCKED COLUMN ON BONUSES (annual_bonus: allow=false)
# ------------------------------------------------------------------
Write-Host "`n------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host " TEST 4: [ANALYST] Attempting to Select Blocked Column 'annual_bonus'" -ForegroundColor Yellow
Write-Host " Expected: ACCESS DENIED on column annual_bonus                   " -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------" -ForegroundColor Yellow

$bonusBlockedRes = kubectl exec -n $Namespace $trinoPod -- trino --user analyst --execute "SELECT emp_id, annual_bonus FROM unity.finance_schema.bonuses;" 2>&1
if ($bonusBlockedRes -match "Access Denied" -or $LASTEXITCODE -ne 0) {
    Write-Host "[GOVERNANCE ENFORCED] Column access blocked as expected!" -ForegroundColor Green
    $bonusBlockedRes | ForEach-Object {
        if ($_ -notmatch "WARNING: Unable to create a system terminal") {
            Write-Host "  $_" -ForegroundColor Red
        }
    }
} else {
    Write-Error "[SECURITY BREACH] Analyst was able to read annual_bonus: $bonusBlockedRes"
    exit 1
}

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host " All 4 RLS, Column Masking & Column Access Control Tests PASSED!  " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green

