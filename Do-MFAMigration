# Do-MFAMigration
# Description: A script for migrating users from per-user MFA to a group for use with Conditional Access Policies
#              This script uses a CSV that can be exported from Entra groups (export members) or you can create your own. 
#              CSV file requires three columns: id, UPN, and displayName
# Author: SH
# Version: 1.0

function Get-MuhMfaStatus {

    param (
        [Parameter(Mandatory)]
        [string]$userId,
        [Parameter(Mandatory)]
        [string]$UPN
    )

    [int]$mfaStatus = 0

    # On-prem check for "Entra_Auth_MFA" membership
    $PDC = (Get-ADDomain).PDCEmulator
    $userObj = Get-ADUser -Filter { UserPrincipalName -eq $UPN } -Server $PDC -ErrorAction Stop
    $isMember = Get-ADPrincipalGroupMembership -Identity $userObj | Select-Object -ExpandProperty Name
    if ($isMember -contains "Entra_Auth_MFA") {
        $mfaStatus += 1
    }
    
    # Per-user MFA check
    $perUserStatus = Invoke-MgGraphRequest -Method GET -Uri "/beta/users/$userId/authentication/requirements" | Select-Object -ExpandProperty perUserMfaState
    if ($perUserStatus -like "disabled") {
        $mfaStatus += 2
    }

    return $mfaStatus
}

function Yeet-UserMfa {

    param (
        [Parameter(Mandatory)]
        [int]$mfaStatus,
        [string]$userId,
        [string]$UPN
    )

    try {
        $body = @{"perUserMfaState" = "disabled"}
        $PDC = (Get-ADDomain).PDCEmulator
        $userObj = Get-ADUser -Filter { UserPrincipalName -eq $UPN } -Server $PDC -ErrorAction Stop
        switch ($mfaStatus) {
            1 {
                Write-Host "User $UPN already added to on-prem MFA group. Attempting to disable per-user MFA." -ForegroundColor Cyan
                Invoke-MgGraphRequest -Method PATCH -Uri "/beta/users/$userId/authentication/requirements" -Body $body
                break
            }
            2 {
                Write-Host "User $UPN already has per-user MFA disabled. Adding to on-prem MFA group." -ForegroundColor Cyan
                Add-ADGroupMember -Identity "Entra_Auth_MFA" -Members $userObj -Server $PDC
                break
            }
            3 {
                Write-Host "User $UPN already has per-user MFA disabled and is a member of the on-prem MFA group. Skipping user..." -ForegroundColor Cyan
                break
            }
            Default {
                Write-Host "Adding $UPN to the Entra_Auth_MFA security group and disabling per-user MFA" -ForegroundColor Cyan
                Add-ADGroupMember -Identity "Entra_Auth_MFA" -Members $userObj -Server $PDC
                Invoke-MgGraphRequest -Method PATCH -Uri "/beta/users/$userId/authentication/requirements" -Body $body
                break
            }
        }
    } catch {
        Write-Host "ERROR: Issue processing user ${UPN}: $_" -ForegroundColor Red
    }
}

function Check-YoSync {
    param (
        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    do {
        Start-Sleep -Seconds 2
        try {
            $syncStatus = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                (Get-ADSyncScheduler).SyncCycleInProgress
            }
        }
        catch {
            Write-Warning "Error checking sync job: $_"
            $syncStatus = $false
        }
    } while ($syncStatus)
}

# Get CSV file
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

$users = Import-Csv -Path $csvPath
$Date = Get-Date -Format "yyyyMMdd-HHmmss"

Start-Transcript -Path ".\MFA_Logs-$Date.txt"

# Import modules
Write-Host "Importing modules: this may take a moment..." -ForegroundColor Cyan
try {
    Import-Module ActiveDirectory
    Import-Module Microsoft.Graph.Authentication
    Import-Module Microsoft.Graph.Users
    Import-Module Microsoft.Graph.Beta.Identity.SignIns -Force
}
catch {
    Write-Error "Missing or failed to import one or more required modules: $_"
    Stop-Transcript
    exit
}

# Connect to Graph
Write-Host "Connecting to Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.Read.All", "Policy.ReadWrite.AuthenticationMethod"

# Main loop
$userCountSuccess = 0
$userCountError = 0
$entraConnectServer = "EntraConnectServer"

foreach ($user in $users) {
    try {
        $userId = $user.id
        $UPN = $user.userPrincipalName

        Write-Host "User: $($user.displayName)" -ForegroundColor Cyan
        $mfaStatus = Get-MuhMfaStatus -userId $userId -UPN $UPN
        Yeet-UserMfa -mfaStatus $mfaStatus -userId $userId -UPN $UPN
        $userCountSuccess++
    } catch {
        Write-Host "ERROR: Issue configuring $($user.displayName): $_" -ForegroundColor Red
        $userCountError++
        continue
    }
}

# Force Entra sync
Write-Host "=====Entra Sync=====" -ForegroundColor Cyan
Write-Host "Checking for existing sync job..." -ForegroundColor Cyan
Check-YoSync -ComputerName $entraConnectServer

Write-Host "Starting sync to Entra" -ForegroundColor Cyan
Invoke-Command -ComputerName $entraConnectServer -ScriptBlock {
    Start-ADSyncSyncCycle -PolicyType Delta | Out-Null
}

do {
    Write-Host "Waiting for Entra sync to complete..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    try {
        $syncStatus = Invoke-Command -ComputerName $entraConnectServer -ScriptBlock {
            (Get-ADSyncScheduler).SyncCycleInProgress
        }
    }
    catch {
        Write-Warning "Error checking sync status: $_"
        $syncStatus = $false
    }
} while ($syncStatus)

Write-Host "Entra sync completed" -ForegroundColor Green

# All done
Stop-Transcript

Write-Host "Completed. Successfully processed $userCountSuccess." -ForegroundColor Green
Write-Host "There were $userCountError users with errors." -ForegroundColor Red
