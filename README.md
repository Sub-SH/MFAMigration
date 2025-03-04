# MFAMigration
Powershell script to migrating users from per-user MFA to a group which can be used with conditional access policies. Using this script rather than Microsoft's migration wizard allows users to be migrated in batches for more granular control and testing.

Users are added to on-prem security groups, but the script could be easily modified to add users to Entra groups. Either option is fine; on-prem groups simply fit our environment better.

## Requirements
The script requires a CSV file with three columns of data: id, UPN, and displayName. This CSV can be downloaded from specific Entra groups (export users) or created manually. 

The script should be ran under the context of a user with privileges to add users to on-prem AD groups. It will prompt for Entra authentication, which should be a user with at least a user or group admin role.

Powershell 7 with the following modules:
- ActiveDirectory
- Microsoft.Graph.Authentication
- Microsoft.Graph.Users
- Microsoft.Graph.Beta.Identity.SignIn

## Instructions
Change the name of $entraConnectServer on line 137 to that of your Entra connect server. 
Change the name of the on-prem security group that you wish to use on lines 23, 57, and 66 (yeah, probably should have made this a variable).
