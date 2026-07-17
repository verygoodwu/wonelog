$ErrorActionPreference = "Stop"

Write-Host "== Wonelog Flutter client bootstrap =="

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Host "Flutter SDK was not found in PATH." -ForegroundColor Yellow
    Write-Host "Install Flutter for Windows first, then rerun this script."
    Write-Host "Official guide: https://docs.flutter.dev/get-started/install/windows/desktop"
    exit 1
}

Write-Host "Flutter:" (flutter --version | Select-Object -First 1)
Write-Host "Creating Windows runner files..."
flutter create . --platforms=windows

Write-Host "Resolving packages..."
flutter pub get

Write-Host "Running flutter doctor..."
flutter doctor

Write-Host "Done. You can run: flutter run -d windows"
