# Get-Emails.ps1
# Description: Get comma-separated list of emails from CSV for emailing users

Add-Type -AssemblyName System.Windows.Forms

$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
$OpenFileDialog.Title = "Select CSV file"

if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $csvPath = $OpenFileDialog.FileName
    Write-Host "Selected file: $csvPath"
} else {
    Write-Host "No file selected. Exiting..." -ForegroundColor Red
    exit
}

$upns = Import-Csv -Path $csvPath | ForEach-Object { $_.userPrincipalName + ";" }
$output = $upns -join " "

$output
