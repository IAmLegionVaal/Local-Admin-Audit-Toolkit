[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Member,
    [switch]$AddMember,
    [switch]$RemoveMember,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$LogDirectory="$env:ProgramData\IAmLegionVaal\LocalAdminRepair"
)

$ErrorActionPreference='Stop'
$ExitInvalidInput=2; $ExitPrerequisite=3; $ExitCancelled=4; $ExitActionFailure=5; $ExitVerificationFailure=6
function Test-Admin {$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Write-Log([string]$Message){$line="{0:u} {1}" -f (Get-Date),$Message;Write-Host $line;Add-Content -LiteralPath $script:LogPath -Value $line}

if(($AddMember -and $RemoveMember) -or -not($AddMember -or $RemoveMember)){Write-Error 'Choose exactly one of -AddMember or -RemoveMember.';exit $ExitInvalidInput}
if(-not(Test-Admin)){Write-Error 'Run from an elevated Windows PowerShell session.';exit $ExitPrerequisite}
if(-not(Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue)){Write-Error 'The Microsoft.PowerShell.LocalAccounts module is required.';exit $ExitPrerequisite}

New-Item -ItemType Directory -Path $LogDirectory -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss';$script:LogPath=Join-Path $LogDirectory "LocalAdminRepair_$stamp.log";$backupPath=Join-Path $LogDirectory "AdministratorsMembers_$stamp.xml"
try{$group=Get-LocalGroup -SID 'S-1-5-32-544';$members=@(Get-LocalGroupMember -Group $group)}catch{Write-Error "Unable to read the local Administrators group: $($_.Exception.Message)";exit $ExitPrerequisite}
$members|Export-Clixml -LiteralPath $backupPath
Write-Log "Saved current local Administrators membership to $backupPath"

$candidates=@($Member,"$env:COMPUTERNAME\$Member")
$existing=@($members|Where-Object {$candidates -contains $_.Name})|Select-Object -First 1
if($AddMember -and $existing){Write-Error "'$Member' is already a local administrator.";exit $ExitInvalidInput}
if($RemoveMember -and -not $existing){Write-Error "'$Member' is not an exact direct member of the local Administrators group. Use the displayed DOMAIN\Name value.";exit $ExitInvalidInput}
if($RemoveMember){
    $current=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    if($existing.Name -ieq $current){Write-Error 'The current signed-in account cannot remove itself from local Administrators.';exit $ExitInvalidInput}
    if($existing.SID -and $existing.SID.Value -match '-500$'){Write-Error 'The built-in local Administrator account is excluded from automated removal.';exit $ExitInvalidInput}
    if($members.Count -le 1){Write-Error 'Refusing to remove the last member of local Administrators.';exit $ExitInvalidInput}
}

$verb=if($AddMember){'add'}else{'remove'}
$preposition=if($AddMember){'to'}else{'from'}
if($DryRun){Write-Log "[DRY-RUN] Would $verb '$Member' $preposition '$($group.Name)'.";exit 0}
if(-not $Yes){$answer=Read-Host ("Proceed to {0} '{1}' {2} local group '{3}'? [y/N]" -f $verb,$Member,$preposition,$group.Name);if($answer -notmatch '^(?i)y(es)?$'){Write-Log '[CANCELLED] No changes were made.';exit $ExitCancelled}}

try{
    if($AddMember){Write-Log "[ACTION] Adding '$Member' to '$($group.Name)'";Add-LocalGroupMember -Group $group -Member $Member}
    else{Write-Log "[ACTION] Removing '$($existing.Name)' from '$($group.Name)'";Remove-LocalGroupMember -Group $group -Member $existing}
}catch{Write-Log "[FAILED] $($_.Exception.Message)";exit $ExitActionFailure}

$verifyFailed=$false
try{
    $after=@(Get-LocalGroupMember -Group $group)
    if($AddMember){$present=@($after|Where-Object {$_.Name -ieq $Member -or $_.Name -ieq "$env:COMPUTERNAME\$Member"}).Count -gt 0}
    else{$present=@($after|Where-Object {$_.Name -ieq $existing.Name}).Count -gt 0}
    Write-Log "[VERIFY] Selected membership present: $present"
    if($AddMember -and -not $present){$verifyFailed=$true}
    if($RemoveMember -and $present){$verifyFailed=$true}
}catch{Write-Log "[VERIFY-FAILED] $($_.Exception.Message)";$verifyFailed=$true}
if($verifyFailed){exit $ExitVerificationFailure}
Write-Log '[COMPLETE] Local administrator membership repair and verification completed.'
exit 0
