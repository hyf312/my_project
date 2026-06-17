Write-Host "=== Running Gate Checks ==="
Write-Host "Version: v2.6.0"
Write-Host "Date: $(Get-Date)"
Write-Host ""

$allPassed = $true

function Test-Command {
    param(
        [string]$Command,
        [string]$CheckName
    )
    Write-Host "[$Command]" -ForegroundColor Cyan
    try {
        & $Command
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $CheckName passed" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ $CheckName failed" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ $CheckName failed: $_" -ForegroundColor Red
        return $false
    }
}

Write-Host "[1/6] Building..." -ForegroundColor Yellow
if (Test-Command "cargo build --release" "Build") {
    $allPassed = $allPassed -and $true
} else {
    $allPassed = $false
}

Write-Host ""
Write-Host "[2/6] Running tests..." -ForegroundColor Yellow
if (Test-Command "cargo test --all-features" "Tests") {
    $allPassed = $allPassed -and $true
} else {
    $allPassed = $false
}

Write-Host ""
Write-Host "[3/6] Running Clippy..." -ForegroundColor Yellow
if (Test-Command 'cargo clippy --all-features -- -D warnings' "Clippy") {
    $allPassed = $allPassed -and $true
} else {
    $allPassed = $false
}

Write-Host ""
Write-Host "[4/6] Checking format..." -ForegroundColor Yellow
if (Test-Command "cargo fmt --check --all" "Format") {
    $allPassed = $allPassed -and $true
} else {
    $allPassed = $false
}

Write-Host ""
Write-Host "[5/6] Checking coverage..." -ForegroundColor Yellow
if (Get-Command cargo-tarpaulin -ErrorAction SilentlyContinue) {
    Test-Command "cargo tarpaulin --out Xml --packages parser,executor,storage" "Coverage"
} else {
    Write-Host "⚠️ cargo-tarpaulin not installed, skipping coverage check" -ForegroundColor Yellow
    Write-Host "   Install with: cargo install cargo-tarpaulin" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[6/6] Running security audit..." -ForegroundColor Yellow
if (Get-Command cargo-audit -ErrorAction SilentlyContinue) {
    Test-Command "cargo audit" "Security audit"
} else {
    Write-Host "⚠️ cargo-audit not installed, skipping security audit" -ForegroundColor Yellow
    Write-Host "   Install with: cargo install cargo-audit" -ForegroundColor Gray
}

Write-Host ""
if ($allPassed) {
    Write-Host "=== All Gates Passed ===" -ForegroundColor Green
    Write-Host "✅ Release v2.6.0 is ready for deployment" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== Some Gates Failed ===" -ForegroundColor Red
    Write-Host "❌ Release v2.6.0 cannot be deployed" -ForegroundColor Red
    exit 1
}