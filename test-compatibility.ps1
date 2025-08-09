# Timeline Notebook Compatibility Test Script (PowerShell)

Write-Host ""
Write-Host "Timeline Notebook Compatibility Test (Windows)" -ForegroundColor Blue
Write-Host "============================================="
Write-Host ""

# Check system information
Write-Host "System Information" -ForegroundColor Yellow
Write-Host "Operating System: Windows"
Write-Host "Architecture: $($env:PROCESSOR_ARCHITECTURE)"
Write-Host ""

# Check Node.js version
Write-Host "Node.js Compatibility Check" -ForegroundColor Yellow
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nodeVersion = & node --version
    Write-Host "Node.js Version: $nodeVersion" -ForegroundColor Green
    
    # Check version
    $versionNumber = $nodeVersion -replace 'v', ''
    $majorVersion = [int]($versionNumber.Split('.')[0])
    if ($majorVersion -ge 16) {
        Write-Host "Node.js version is compatible" -ForegroundColor Green
    } else {
        Write-Host "Node.js version is too low, requires 16.0.0 or higher" -ForegroundColor Red
    }
} else {
    Write-Host "Node.js is not installed" -ForegroundColor Red
}

$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if ($npmCmd) {
    $npmVersion = & npm --version
    Write-Host "npm Version: $npmVersion" -ForegroundColor Green
} else {
    Write-Host "npm is not installed" -ForegroundColor Red
}
Write-Host ""

# Check Python version
Write-Host "Python Compatibility Check" -ForegroundColor Yellow
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) {
    $pythonVersion = & python --version
    Write-Host "$pythonVersion" -ForegroundColor Green
    
    # Check version
    $versionParts = $pythonVersion -replace 'Python ', '' -split '\.'
    $majorVersion = [int]$versionParts[0]
    $minorVersion = [int]$versionParts[1]
    if ($majorVersion -gt 3 -or ($majorVersion -eq 3 -and $minorVersion -ge 8)) {
        Write-Host "Python version is compatible" -ForegroundColor Green
    } else {
        Write-Host "Python version is too low, requires 3.8.0 or higher" -ForegroundColor Red
    }
} else {
    Write-Host "Python is not installed" -ForegroundColor Red
}

$pipCmd = Get-Command pip -ErrorAction SilentlyContinue
if ($pipCmd) {
    $pipVersion = & pip --version
    $pipVer = ($pipVersion -split ' ')[1]
    Write-Host "pip Version: $pipVer" -ForegroundColor Green
} else {
    Write-Host "pip is not installed" -ForegroundColor Red
}
Write-Host ""

# Check Docker version
Write-Host "Docker Compatibility Check" -ForegroundColor Yellow
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCmd) {
    try {
        $dockerVersion = & docker --version
        $dockerVer = ($dockerVersion -split ' ')[2] -replace ',', ''
        Write-Host "Docker Version: $dockerVer" -ForegroundColor Green
        
        # Check Docker Compose
        try {
            $composeVersion = & docker compose version
            $composeVer = ($composeVersion -split ' ')[3]
            Write-Host "Docker Compose V2: $composeVer" -ForegroundColor Green
        } catch {
            Write-Host "Docker Compose V2 is not installed" -ForegroundColor Red
        }
    } catch {
        Write-Host "Docker is not running or not accessible" -ForegroundColor Red
    }
} else {
    Write-Host "Docker is not installed" -ForegroundColor Red
}
Write-Host ""

# Check configuration files
Write-Host "Configuration Files Check" -ForegroundColor Yellow
$configFiles = @(
    ".env.dev",
    ".env.production", 
    ".env.server",
    "docker-compose-http.yml",
    "nginx-http.conf"
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Host "$file exists" -ForegroundColor Green
    } else {
        Write-Host "$file does not exist" -ForegroundColor Yellow
    }
}
Write-Host ""

# Check frontend files
Write-Host "Frontend Dependencies Check" -ForegroundColor Yellow
if (Test-Path "frontend\package.json") {
    Write-Host "package.json exists" -ForegroundColor Green
} else {
    Write-Host "package.json does not exist" -ForegroundColor Red
}

if (Test-Path "frontend\node_modules") {
    Write-Host "node_modules exists" -ForegroundColor Green
} else {
    Write-Host "node_modules does not exist, need to run npm install" -ForegroundColor Yellow
}
Write-Host ""

# Check backend files
Write-Host "Backend Dependencies Check" -ForegroundColor Yellow
if (Test-Path "backend\requirements.txt") {
    Write-Host "requirements.txt exists" -ForegroundColor Green
} else {
    Write-Host "requirements.txt does not exist" -ForegroundColor Red
}
Write-Host ""

# Check port availability
Write-Host "Port Availability Check" -ForegroundColor Yellow
$ports = @(5000, 5173, 80, 443)
foreach ($port in $ports) {
    $connection = Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($connection) {
        Write-Host "Port $port is in use" -ForegroundColor Yellow
    } else {
        Write-Host "Port $port is available" -ForegroundColor Green
    }
}
Write-Host ""

# Summary
Write-Host "Compatibility Check Summary" -ForegroundColor Blue
Write-Host "============================================="
Write-Host "For detailed compatibility information, see: COMPATIBILITY-REPORT.md"
Write-Host ""
Write-Host "Compatibility check completed!" -ForegroundColor Green
Write-Host ""