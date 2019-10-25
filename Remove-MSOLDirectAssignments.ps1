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
param(
    [Parameter(
        Mandatory=$True,
        Position = 0,
        ValueFromPipeline = $true,
        HelpMessage = "Group Object ID."
        )]
    [ValidatePattern("^[a-zA-Z0-9]{8}[-]{1}[a-zA-Z0-9]{4}[-][a-zA-Z0-9]{4}[-][a-zA-Z0-9]{4}[-][a-zA-Z0-9]{12}$")]
    [string]$GroupID,
    [Parameter(
        Mandatory = $True,
        HelpMessage = "Reprocess users."
    )]
    [Alias("ReproUsers","Users")]
    [switch]$ReprocessUsers,
    [Parameter(
        Mandatory = $True,
        HelpMessage = "Reprocess user"
    )]
    [Alias("ReproGroup","Group")]
    [switch]$ReprocessGroup
    )
#-------------------------------------------------
#                Assign Variables
#-------------------------------------------------
#Group Object ID already set as $GroupID
#Log File Location $ENV:TEMP\PowerShell_Scripts\Logs\
$LogFileDir = "$ENV:USERPROFILE\Desktop\PowerShell_Logs\"
If(!(Test-Path $LogFileDir)){mkdir $LogFileDir}
#Log File Name (Typically Script Name)
$LogFileName = "Azure_DirectAssignmentRemoval.log"
#Combine log file dir and log file name
$LogFile = "$LogFileDir" + "$LogFileName"
#-------------------------------------------------
#Function for log writing.
Function LogWrite
{
   Param ([string]$logstring)
   $Date = Get-Date -format "MM/dd/yyyy HH:mm:ss"
   Add-content $Logfile -value "$Date - $logstring"
   Write-Host "$logstring"
}
LogWrite -logstring "Starting New Execution: Removing Direct Licenses from $GroupID."

# Test if we have a Microsoft Online (Azure) Service connection. Connect if not.
try{
    Get-MsolCompanyInformation -ErrorAction Stop > $Null
}
catch
{
    LogWrite -logstring "Could not find MSOL Service connection, establishing new connection."
    Connect-MsolService
}
$MemberIDs = (Get-MsolGroupMember -GroupObjectId $GroupID -All | Select-Object ObjectID).ObjectID
$MemberCount = $MemberIDs.Count

LogWrite "Found $MemberCount members in $GroupID."
$i = 0
# Find the MSOL group members and sort out licenses. 
$MemberIDs| ForEach-Object {
    
    #Collect User information
    $User = Get-MsolUser -ObjectId $_
    $DisplayName = $User.UserPrincipalName
    LogWrite -logstring "Starting script execution for $DisplayName"
    
    # Find user licenses and determine which ones are assigned directly. We then put the direct
    # licenses into an array, named $DirectLicenses. 
    $Licenses = $User.Licenses
    $DirectLicenses = @()
    Foreach($License in $Licenses){
        If ($License.GroupsAssigningLicense.Count -eq 0){
            $DirectLicenses += $License
        }
    }
    Foreach($License in $Licenses){
        If($License.GroupsAssigningLicense.Guid -eq $User.ObjectID.Guid){
            $DirectLicenses += $License
        }
    }
# If the direct license count is greater than 0, start the process of removing the direct licenses.
# Otherwise, write to the log and exit script.
    $DLCount = $DirectLicenses.Count
    If($DLCount -gt 0){
        LogWrite -logstring "Found $DLCount directly assigned licenses for $DisplayName"
        Logwrite -logstring "Collecting Direct License service status."
        $EnabledStaticServices = @()
        $DirectLicenses.ServiceStatus | ForEach-Object {
            If ($_.ProvisioningStatus -ne "Disabled"){         
             $EnabledStaticServices += $_
            }
        }
        $SKUIDs = $DirectLicenses.AccountSKUID
        LogWrite -logstring "Removing User: $DisplayName from Group(s): $SKUIDs"
        Set-MsolUserLicense -UserPrincipalName $User.UserPrincipalName -RemoveLicenses $SKUIDs

        If($ReprocessUsers){
            LogWrite -logstring "ReprocessUser switch specified. Starting user reprocessing."
            Redo-MsolProvisionUser -ObjectId $_
        }
    }else{
        LogWrite -logstring "$DisplayName had no directly assigned licenses."
    }
    $i++
    Write-Progress -Activity "Removing Direct License Assignments" -Status "User: $DisplayName | Progress: $i of $MemberCount" -PercentComplete (($i / $MemberCount) * 100)
}
#When all said and done, if -ReprocessGroup is specified, run the reprocess command.
If($ReprocessGroup){
    LogWrite -logstring "ReprocessGroup switch specified. Starting group reprocessing. (May take a while depending on # of users in group."
}