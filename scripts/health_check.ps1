$Namespace = "lakehouse"
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Lakehouse Health Check: Checking Pods & Services " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$deployments = @("postgres", "minio", "keycloak", "unitycatalog", "trino")

foreach ($dep in $deployments) {
    Write-Host "Checking Deployment: $dep..." -NoNewline
    $ready = kubectl get deployment $dep -n $Namespace -o jsonpath='{.status.readyReplicas}' 2>$null
    if ($ready -and [int]$ready -ge 1) {
        Write-Host " [HEALTHY - READY]" -ForegroundColor Green
    } else {
        Write-Host " [WAITING / NOT READY]" -ForegroundColor Yellow
    }
}

Write-Host "`nPod Statuses in $Namespace namespace:" -ForegroundColor Cyan
kubectl get pods -n $Namespace -o wide

Write-Host "`nServices in $Namespace namespace:" -ForegroundColor Cyan
kubectl get svc -n $Namespace

