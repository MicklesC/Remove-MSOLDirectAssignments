# Remove-MSOLDirectAssignments
Removes MSOL direct license assignments from users in a specified group.

Requires the MSOnline PowerShell module and related AzureAD permissions.

<#
.SYNOPSIS
  Removes Directly assigned licenses from users in a specified group.
.DESCRIPTION
  Utilizes the MSOnline PowerShell module to gather the users in a group and remove their directly assigned
  licenses. Please note the user or group will need to be reprocessed and license assignments will be lost if 
  the active license directly assigned. Licenses assigned via groups will not apply until reprocessing is complete.
.PARAMETER GroupID
    Required - The group ID for the group which you want to reprocess. 
.PARAMETER ReprocessUsers
    Switch - Reprocess the users 1 by 1 after they have direct assignments removed. Recomended for larger groups. 
.PARAMETER ReprocessGroup
    Switch - Reprocesses the entire group after every user has had their direct assignments removed. 
.INPUTS
  None
.OUTPUTS
  Logs stored in $ENV:Userprofile\Desktop\PowerShell_Logs\Azure_DirectAssignmentRemoval.log
.NOTES
  Version:        1.0
  Author:         Michael Cherneski
  Creation Date:  25 October 2019
  Purpose/Change: Initial script development
  
.EXAMPLE
Remote-MSOLDirectAssignments -GroupID "XXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" -ReprocessUsers
#>
