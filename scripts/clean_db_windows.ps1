<# 
Observer Database Reset and Migration Script (Windows PowerShell)
#>

$ErrorActionPreference = "Stop"

# ----------------------------
# Config
# ----------------------------
$ENV_FILE    = "C:\Users\mhill1\Downloads\observer\observer_backend\.env"
$PYTHON_PATH = "C:\Users\mhill1\Downloads\observer\observer_backend\eeenv\Scripts\python.exe"
$PROJECT_DIR = "C:\Users\mhill1\Downloads\observer\observer_backend"

# ----------------------------
# Pretty output helpers
# ----------------------------
function Write-Info($msg)  { Write-Host $msg -ForegroundColor Yellow }
function Write-Ok($msg)    { Write-Host $msg -ForegroundColor Green }
function Write-Err($msg)   { Write-Host $msg -ForegroundColor Red }

# ----------------------------
# .env loader
# ----------------------------
function Import-DotEnv {
    param(
        [Parameter(Mandatory=$true)]
        [string] $Path
    )

    if (!(Test-Path -LiteralPath $Path)) {
        throw ".env file not found at: $Path"
    }

    $lines = Get-Content -LiteralPath $Path
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim.Length -eq 0) { continue }
        if ($trim.StartsWith("#")) { continue }

        # Match KEY=VALUE
        $m = [regex]::Match($trim, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$')
        if (!$m.Success) { continue }

        $key = $m.Groups[1].Value
        $val = $m.Groups[2].Value

        # Strip surrounding quotes if present
        if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
            $val = $val.Substring(1, $val.Length - 2)
        }

        # Set in current process env
        [Environment]::SetEnvironmentVariable($key, $val, "Process")
    }
}

# ----------------------------
# Main
# ----------------------------
try {
    Write-Ok "Starting Observer Database and User Reset..."

    Write-Info "Loading environment from: $ENV_FILE"
    Import-DotEnv -Path $ENV_FILE

    # Required env vars (from .env)
    $ACCOUNTS_DB_NAME = $env:ACCOUNTS_DB_NAME
    $CLINICAL_DB_NAME = $env:CLINICAL_DB_NAME
    $RESEARCH_DB_NAME = $env:RESEARCH_DB_NAME

    $TEST_ACCOUNTS_DB = $env:TEST_ACCOUNTS_DB
    $TEST_CLINICAL_DB = $env:TEST_CLINICAL_DB
    $TEST_RESEARCH_DB = $env:TEST_RESEARCH_DB
    $TEST_DEFAULT_DB  = $env:TEST_DEFAULT_DB

    $MYSQL_OBSERVER_USER     = $env:DB_USER
    $MYSQL_OBSERVER_PASSWORD = $env:DB_PASSWORD

    # Validate minimal config
    $missing = @()
    foreach ($kv in @(
        @{k="ACCOUNTS_DB_NAME"; v=$ACCOUNTS_DB_NAME},
        @{k="CLINICAL_DB_NAME"; v=$CLINICAL_DB_NAME},
        @{k="RESEARCH_DB_NAME"; v=$RESEARCH_DB_NAME},
        @{k="TEST_ACCOUNTS_DB"; v=$TEST_ACCOUNTS_DB},
        @{k="TEST_CLINICAL_DB"; v=$TEST_CLINICAL_DB},
        @{k="TEST_RESEARCH_DB"; v=$TEST_RESEARCH_DB},
        @{k="TEST_DEFAULT_DB"; v=$TEST_DEFAULT_DB},
        @{k="DB_USER"; v=$MYSQL_OBSERVER_USER},
        @{k="DB_PASSWORD"; v=$MYSQL_OBSERVER_PASSWORD}
    )) {
        if ([string]::IsNullOrWhiteSpace($kv.v)) { $missing += $kv.k }
    }
    if ($missing.Count -gt 0) {
        throw "Missing required .env variables: $($missing -join ', ')"
    }

    Write-Info "Changing to project directory: $PROJECT_DIR"
    if (!(Test-Path -LiteralPath $PROJECT_DIR)) { throw "Project dir not found: $PROJECT_DIR" }
    Set-Location -LiteralPath $PROJECT_DIR

    # Step 1: Reset MySQL databases and user
    Write-Info "Step 1: Resetting MySQL databases and user..."

    # Prompt for MySQL root password (do not echo)
    $rootPwdSecure = Read-Host "Enter MySQL root password" -AsSecureString
    $rootPwdPlain  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($rootPwdSecure)
    )

    $MYSQL_ROOT_USER = "root"

    $sql = @"
-- Drop existing databases
DROP DATABASE IF EXISTS $ACCOUNTS_DB_NAME;
DROP DATABASE IF EXISTS $CLINICAL_DB_NAME;
DROP DATABASE IF EXISTS $RESEARCH_DB_NAME;

-- Drop existing user (ignore errors if user doesn't exist)
DROP USER IF EXISTS '$MYSQL_OBSERVER_USER'@'localhost';
DROP USER IF EXISTS '$MYSQL_OBSERVER_USER'@'%';

-- Create new databases
CREATE DATABASE $ACCOUNTS_DB_NAME;
CREATE DATABASE $CLINICAL_DB_NAME;
CREATE DATABASE $RESEARCH_DB_NAME;

-- Create new user with password
CREATE USER '$MYSQL_OBSERVER_USER'@'localhost' IDENTIFIED BY '$MYSQL_OBSERVER_PASSWORD';
CREATE USER '$MYSQL_OBSERVER_USER'@'%' IDENTIFIED BY '$MYSQL_OBSERVER_PASSWORD';

-- (CHANGE #2) Always enforce the intended password (robust even if auth/user state changes)
ALTER USER '$MYSQL_OBSERVER_USER'@'localhost' IDENTIFIED BY '$MYSQL_OBSERVER_PASSWORD';
ALTER USER '$MYSQL_OBSERVER_USER'@'%' IDENTIFIED BY '$MYSQL_OBSERVER_PASSWORD';

-- Grant privileges to the new user
GRANT ALL PRIVILEGES ON $ACCOUNTS_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $ACCOUNTS_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $CLINICAL_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $CLINICAL_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $RESEARCH_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $RESEARCH_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'%';

-- Grant CREATE and DROP permissions for test databases
GRANT CREATE ON *.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT CREATE ON *.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT DROP ON *.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT DROP ON *.* TO '$MYSQL_OBSERVER_USER'@'%';

-- Grant permissions on test databases for Django testing
GRANT ALL PRIVILEGES ON $TEST_ACCOUNTS_DB.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $TEST_ACCOUNTS_DB.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $TEST_CLINICAL_DB.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $TEST_CLINICAL_DB.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $TEST_RESEARCH_DB.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $TEST_RESEARCH_DB.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $TEST_DEFAULT_DB.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $TEST_DEFAULT_DB.* TO '$MYSQL_OBSERVER_USER'@'%';

FLUSH PRIVILEGES;
"@

    # Feed SQL to mysql.exe over stdin (no temp file needed)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "mysql"
    $psi.Arguments = "-u $MYSQL_ROOT_USER -p$rootPwdPlain"
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $p.StandardInput.WriteLine($sql)
    $p.StandardInput.Close()

    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($p.ExitCode -ne 0) {
        Write-Err "✗ Database and user reset failed"
        if ($out) { Write-Host $out }
        if ($err) { Write-Host $err }
        exit 1
    }

    Write-Ok "✓ Databases and user reset successfully"

    # Step 2: Create fresh migrations
    Write-Info "Step 2: Creating fresh migrations..."
    Write-Host "Creating migrations for accounts app..."
    & $PYTHON_PATH manage.py makemigrations accounts

    Write-Host "Creating migrations for clinical app..."
    & $PYTHON_PATH manage.py makemigrations clinical

    Write-Host "Creating migrations for research app..."
    & $PYTHON_PATH manage.py makemigrations research

    Write-Ok "✓ Fresh migrations created"

    # Step 3: Apply migrations
    Write-Info "Step 3: Applying migrations..."
    Write-Host "Migrating accounts app to accounts database..."
    & $PYTHON_PATH manage.py migrate --database=accounts

    Write-Host "Migrating clinical app to clinical database..."
    & $PYTHON_PATH manage.py migrate --database=clinical

    Write-Host "Migrating research app to research database..."
    & $PYTHON_PATH manage.py migrate --database=research

    Write-Ok "✓ All migrations applied successfully"

    # Step 4: Verify everything worked
    Write-Info "Step 4: Verifying database setup..."

    # (CHANGE #1) Pass password safely + fail fast if verification fails
    Write-Host "Checking $ACCOUNTS_DB_NAME tables:"
    & mysql -u $MYSQL_OBSERVER_USER --password="$MYSQL_OBSERVER_PASSWORD" -e "USE $ACCOUNTS_DB_NAME; SHOW TABLES;"
    if ($LASTEXITCODE -ne 0) { throw "Verification failed for $ACCOUNTS_DB_NAME" }

    Write-Host ""
    Write-Host "Checking $CLINICAL_DB_NAME tables:"
    & mysql -u $MYSQL_OBSERVER_USER --password="$MYSQL_OBSERVER_PASSWORD" -e "USE $CLINICAL_DB_NAME; SHOW TABLES;"
    if ($LASTEXITCODE -ne 0) { throw "Verification failed for $CLINICAL_DB_NAME" }

    Write-Host ""
    Write-Host "Checking $RESEARCH_DB_NAME tables:"
    & mysql -u $MYSQL_OBSERVER_USER --password="$MYSQL_OBSERVER_PASSWORD" -e "USE $RESEARCH_DB_NAME; SHOW TABLES;"
    if ($LASTEXITCODE -ne 0) { throw "Verification failed for $RESEARCH_DB_NAME" }

    Write-Ok "✓ Database setup verification complete"
    Write-Ok "🎉 Observer database reset completed successfully!"
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
finally {
    # Best-effort cleanup of plain root password variable
    if (Get-Variable rootPwdPlain -ErrorAction SilentlyContinue) {
        $rootPwdPlain = $null
    }
}