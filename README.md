# Local Admin Audit Toolkit

A PowerShell toolkit for reviewing and correcting direct membership of the local Windows Administrators group.

## Audit

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Local_Admin_Audit_Toolkit.ps1
```

## Repair

Preview a membership removal:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Local_Admin_Repair_Toolkit.ps1 -Member 'CONTOSO\legacyAdmin' -RemoveMember -DryRun
```

Examples:

```powershell
.\Local_Admin_Repair_Toolkit.ps1 -Member 'CONTOSO\approvedAdmin' -AddMember
.\Local_Admin_Repair_Toolkit.ps1 -Member 'CONTOSO\legacyAdmin' -RemoveMember
.\Local_Admin_Repair_Toolkit.ps1 -Member 'AzureAD\user@contoso.com' -AddMember -Yes
```

## Repair behavior

- Requires an elevated Windows PowerShell session and the LocalAccounts module.
- Uses the well-known local Administrators group SID, so it works with localized group names.
- Adds or removes one explicitly selected direct member per run.
- Exports the current group membership to CLIXML before modification.
- Refuses duplicate additions, non-member removals, self-removal, removal of the built-in local Administrator and removal of the final group member.
- Supports `-DryRun`, confirmation or `-Yes`, timestamped action logs and post-change verification.
- Returns `0` for success, `2` for invalid or unsafe input, `3` for missing privileges or prerequisites, `4` for cancellation, `5` for action failure and `6` for verification failure.

## Safety

Confirm alternate administrative access before removing an account. The repair script changes direct membership only; it does not alter nested domain groups, passwords, account enablement or User Account Control policy.

## Author

Dewald Pretorius — L2 IT Support Engineer
