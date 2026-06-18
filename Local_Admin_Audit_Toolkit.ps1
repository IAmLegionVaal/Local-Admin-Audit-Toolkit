#requires -Version 5.1
<#
.SYNOPSIS
    Local Admin Audit Toolkit.
.DESCRIPTION
    Read-only local administrator context reporter for Windows support.
#>
[CmdletBinding()]
param([string]$OutputPath)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Local_Admin_Audit_Reports' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
function Export-Data { param($Name,$Data) $Data | Export-Csv (Join-Path $OutputPath "$Name.csv") -NoTypeInformation -Encoding UTF8; $Data | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $OutputPath "$Name.json") -Encoding UTF8 }

$os = Get-CimInstance Win32_OperatingSystem
$computer = [PSCustomObject]@{ComputerName=$env:COMPUTERNAME;User="$env:USERDOMAIN\$env:USERNAME";OS=$os.Caption;Build=$os.BuildNumber;Generated=Get-Date}
Export-Data -Name "computer_context_$RunStamp" -Data @($computer)
try { $admins = Get-LocalGroupMember -Group 'Administrators' | Select-Object Name,ObjectClass,PrincipalSource,SID; Export-Data -Name "local_administrators_$RunStamp" -Data $admins } catch { $admins = @([PSCustomObject]@{Name='Query failed';ObjectClass='';PrincipalSource='';SID=$_.Exception.Message}); Export-Data -Name "local_administrators_$RunStamp" -Data $admins }
try { $users = Get-LocalUser | Select-Object Name,Enabled,LastLogon,PasswordLastSet,PasswordRequired,UserMayChangePassword,Description; Export-Data -Name "local_users_$RunStamp" -Data $users } catch { $users=@() }
$findings = @()
$admins | Where-Object {$_.Name -match 'Everyone|Users|Domain Users'} | ForEach-Object { $findings += [PSCustomObject]@{Area='Administrators';Finding='Broad group appears in Administrators';Value=$_.Name;Recommendation='Review privileged access policy.'} }
$users | Where-Object {$_.Enabled -eq $true -and $_.Name -notin @('Administrator','DefaultAccount','WDAGUtilityAccount','Guest')} | ForEach-Object { $findings += [PSCustomObject]@{Area='Local Users';Finding='Enabled local user';Value=$_.Name;Recommendation='Confirm this account is expected.'} }
Export-Data -Name "local_admin_findings_$RunStamp" -Data $findings
$html = "<h1>Local Admin Audit - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Findings</h2>$($findings | ConvertTo-Html -Fragment)<h2>Administrators</h2>$($admins | ConvertTo-Html -Fragment)"
$html | ConvertTo-Html -Title 'Local Admin Audit' | Set-Content (Join-Path $OutputPath "local_admin_audit_$RunStamp.html") -Encoding UTF8
$findings | Format-Table -AutoSize -Wrap
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
