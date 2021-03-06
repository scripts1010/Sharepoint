## SharePoint Server: PowerShell Script to Create a CSV Audit Log Report For a Site Collection ##

<#
Overview: PowerShell Script that uses the 'SharePoint Auditing Classes' to produce a CSV Audit Log Report For a Site Collection
Environments: SharePoint Server 2010 / 2013 Farms
Usage: Edit the following variables to suit your environment and run the script: '$site'; '$FileName'; '$tabCsv'
Resource: http://shokochino-sharepointexperience.blogspot.ch/2013/05/create-auditing-reports-in-sharepoint.html
#>


# Usa el equipo Local


$AuditDir= ".\Audit\"
#Parametros de Log
$LogFilePrefix= "log"
$LogDir = ".\Logs\"
$LogToFileEnable=1
$LogToConsole=1
$RotateLogs=7
$LastTimeStamp = Get-Content -Path .\LastTimeStamp.txt -TotalCount 1
$date = [datetime]::parseexact($LastTimeStamp,'dd/MM/yyyy HH:mm:ss',$null)
function Log($WhatToLog,$Level){

	if ($Level -eq $null) {$Level = "NORMAL"}
	Switch ($Level) {
		"ERROR" {$Color="Red"}
		"WARN" {$Color="Yellow"}
		"INFO" {$Color="Green"}
		default {$Color="White"}
	}

	$WhatToLog = "$(Get-Date -format dd/MM/yyyy) [$Level] $WhatToLog"
	
	if ($LogToFileEnable){
	    $LogFile = $LogDir + $LogFilePrefix + "_" +  (Get-Date -format dd-MM-yyyy)  + ".log"
			Write-Output $WhatToLog >> $LogFile
	}
	If ($LogToConsole){
	    
		Write-Host $WhatToLog -foregroundcolor $Color
	}
	
}

function DeleteOldLogs {
	Log "Eliminando logs antiguos... (items to keep: $RotateLogs)"
	$files = Get-ChildItem *.log -Path $LogDir -Recurse | Where-Object {-not $_.PsIsContainer}
	$keep = $RotateLogs
	if ($files.Count -gt $keep) {
		$files | Sort-Object CreationTime | Select-Object -First ($files.Count - $keep) | Remove-Item -Force
	}
}
$StartMS= (Get-Date)
$isItRunning  = ""
log "Iniciando.."
$isItRunning  = Get-WmiObject Win32_Process -Filter "Name='powershell.exe' AND CommandLine LIKE '%sharepoint-audit.ps1%'"


if ($isItRunning -ne $null) {
	$instances = $isItRunning.ToString().Count
	log "instances result: $isItRunning [$instances]"
    log "ya hay una tarea de busqueda en ejecucion. Abortando esta ejecucion."
    exit
    } 
log "Comienza el SnapIn de PS-SharePoint"
Add-PSSnapin "Microsoft.SharePoint.Powershell"
[Microsoft.SharePoint.SPSecurity]::RunWithElevatedPrivileges(
{
$tabName = "AuditLog"

#Create Table object
log "Se genera el objeto tabla"
$table = New-Object system.Data.DataTable ?$tabName?

#Define Columns
log "Se definen y se agregan a la tabla las columnas a utilizar"
$col1 = New-Object system.Data.DataColumn SiteUrl,([string])
$col2 = New-Object system.Data.DataColumn SiteID,([string])
$col3 = New-Object system.Data.DataColumn ItemName,([string])
$col4 = New-Object system.Data.DataColumn ItemType,([string])
$col5 = New-Object system.Data.DataColumn UserID,([string])
$col6 = New-Object system.Data.DataColumn UserName,([string])
$col7 = New-Object system.Data.DataColumn Occurred,([string])
$col8 = New-Object system.Data.DataColumn Event,([string])
$col9 = New-Object system.Data.DataColumn Description,([string])
$col10 = New-Object system.Data.DataColumn EventSource,([string])
$col11 = New-Object system.Data.DataColumn SourceName,([string])
$col12 = New-Object system.Data.DataColumn EventData,([string])
$col13 = New-Object system.Data.DataColumn MachineName,([string])
$col14 = New-Object system.Data.DataColumn MachineIP,([string])
$col15 = New-Object system.Data.DataColumn DocLocation,([string])

#Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)
$table.columns.add($col6)
$table.columns.add($col7)
$table.columns.add($col8)
$table.columns.add($col9)
$table.columns.add($col10)
$table.columns.add($col11)
$table.columns.add($col12)
$table.columns.add($col13)
$table.columns.add($col14)
$table.columns.add($col15)

#======================================================================================================================================================================================
#======================================================================================================================================================================================
#======================================================================================================================================================================================

#$site = Get-SPSite -Identity "http://sharepoint" #Change this to match your site collection name
$sites = Get-SPSite -Limit All -CompatibilityLevel 15
$sitesCount = $sites.Count
log "Se van a buscar los sitios del sharepoint. Los sitios son: $sitesCount"
# $sites = Get-SPSite -Identity "http://sharepoint"
foreach($site in $sites){
$siteUrl = $site.Url
log "Sitio siendo analizado: $siteUrl"
$wssQuery = New-Object -TypeName Microsoft.SharePoint.SPAuditQuery($site)
$auditCol = $site.Audit.GetEntries($wssQuery)
$root = $site.RootWeb

for ($i=0; $i -le ($auditCol.Count)-1 ; $i++)
{
     #Get the Entry Item from the Collection
     $entry = $auditCol.item($i)
	 

     #log "Se genera la fila con los datos del evento de auditoria y el usuario que lo realiz?"
     #Create a row
     $row = $table.NewRow()
	 if ($entry.Occurred -gt $date){
           #find the Current UserName 
           foreach($User in $root.SiteUsers)
           {
                if($entry.UserId -eq $User.Id)
                {
                     $UserName = $User.UserLogin
                }
           }   

           #find the Item Name
           foreach($List in $root.Lists)
           {
                if($entry.ItemId -eq $List.Id)
                {
                     $ItemName = $List.Title
                }
           }   

#Define Description for the Event Property
     switch ($entry.Event) 
    {
           AuditMaskChange{$eventName = "The audit flags are changed for the audited object."}
           ChildDelete {$eventName = "A child of the audited object is deleted."}
           ChildMove {$eventName = "A child of the audited object is moved."}
           CheckIn {$eventName = " A document is checked in."}
           'Copy' {$eventName = "The audited item is copied."}
           Delete {$eventName = "The audited object is deleted."}
           EventsDeleted {$eventName = "Some audit entries are deleted from SharePoint database."}
           'Move' {$eventName = "The audited object is moved."}
           Search {$eventName = "The audited object is searched."}
           SecGroupCreate {$eventName = "A group is created for the site collection. (This action also generates an Update event.See below.)"}
           SecGroupDelete {$eventName = "A group on the site collection is deleted."}
           SecGroupMemberAdd {$eventName = "A user is added to a group."}
           SecGroupMemberDelete {$eventName = "A user is removed from a group."}
           SecRoleBindBreakInherit {$eventName = "A subsite's inheritance of permission level definitions (that is, role definitions) is severed."}
           SecRoleBindInherit {$eventName = "A subsite is set to inherit permission level definitions (that is, role definitions) from its parent."}
           SecRoleBindUpdate {$eventName = "The permissions of a user or group for the audited object are changed."}
           SecRoleDefCreate {$eventName = "A new permission level (a combination of permissions that are given to people holding a particular role for the site collection) is created."}
           SecRoleDefDelete {$eventName = "A permission level (a combination of permissions that are given to people holding a particular role for the site collection) is deleted."}
           SecRoleDefModify {$eventName = "A permission level (a combination of permissions that are given to people holding a particular role for the site collection) is modified."}
           Update {$eventName = "An existing object is updated."}
           CheckOut {$eventName = " A document is checked Out."}
           View {$eventName = "Viewing of the object by a user."}
           ProfileChange {$eventName = "Change in a profile that is associated with the object."}
           SchemaChange {$eventName = "Change in the schema of the object."}
           Undelete {$eventName = "Restoration of an object from the Recycle Bin."}
           Workflow {$eventName = "Access of the object as part of a workflow."}
           FileFragmentWrite {$eventName = "A File Fragment has been written for the file."}
           Custom {$eventName = "Custom action or event."}
        default {$eventName = "The Event could not be determined."}
    }
     #Enter data in the row
     $row.SiteUrl = $site.Url
     $row.SiteID = $entry.SiteID
     $row.ItemName = $ItemName
     $row.ItemType = $entry.ItemType
     $row.UserID = $entry.UserID
     $row.UserName = $UserName	
	 $row.Occurred = ($entry.Occurred).ToString('dd/MM/yyyy HH:mm:ss')
	 $row.Event = $entry.Event
     $row.Description = $eventName
     $row.EventSource = $entry.EventSource
     $row.SourceName = $entry.SourceName
     $row.EventData = $entry.EventData
     $row.MachineName = $entry.MachineName
     $row.MachineIP = $entry.MachineIP
     $row.DocLocation = $entry.DocLocation


     #Add the row to the table
     $table.Rows.Add($row)

	 }
}
}


#======================================================================================================================================================================================
#======================================================================================================================================================================================
#======================================================================================================================================================================================

     #Display the table (Optional)
     #$table | format-table -AutoSize

$date = get-date -format "d-M-yyyy"
$sDtae = [string]$date
Write-Host $table
$FileName = "AuditLogReport_For_" + $sDtae #Change this file name to match your environment
#Export the CSV File to Folder Destination
$tabCsv = $table | export-csv ($AuditDir +"$FileName.csv") -noType #Change this file path to match your environment
DeleteOldLogs
Write-Output (get-date -format "dd/MM/yyyy HH:mm:ss") > .\LastTimeStamp.txt
})

