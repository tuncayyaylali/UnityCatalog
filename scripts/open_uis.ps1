# scripts/open_uis.ps1
# Modern Open Source Data Lakehouse Web Arayuzlerini Baslatma ve Tarayicida Acma

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Data Lakehouse Web Arayuzleri                    " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Trino Web UI (8080)
Write-Host "[1/4] Trino Web UI: http://localhost:8080" -ForegroundColor Green
Write-Host "      Kullanici Adi: admin (Sifre: bos)" -ForegroundColor DarkGray

# 2. Keycloak Admin Console (8081)
Write-Host "[2/4] Keycloak IAM Console: http://localhost:8081" -ForegroundColor Green
Write-Host "      Kullanici: admin | Sifre: adminpassword" -ForegroundColor DarkGray

# 3. Unity Catalog API / Docs (8083)
Write-Host "[3/4] Unity Catalog Console: http://localhost:8083/docs/" -ForegroundColor Green
Write-Host "      Kimlik Dogrulama: Gerekmez" -ForegroundColor DarkGray

# 4. MinIO Console (9001)
Write-Host "[4/4] MinIO Object Browser: http://localhost:9001" -ForegroundColor Green
Write-Host "      Kullanici: minioadmin | Sifre: minioadmin" -ForegroundColor DarkGray
Write-Host "==================================================" -ForegroundColor Cyan

$open = Read-Host "Tarayicida tum arayuzleri simdi acmak ister misiniz? (E/H)"
if ($open -eq 'E' -or $open -eq 'e') {
    Start-Process "http://localhost:8080"
    Start-Process "http://localhost:8081"
    Start-Process "http://localhost:8083/docs/"
    Start-Process "http://localhost:9001"
}
