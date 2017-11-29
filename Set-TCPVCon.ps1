<#-----------------------------------------------------------------------------
E2E Security Data Gathering

Eloy Salamanca | Senior IT Consultant
eloy.salamanca@guadaltech.es

Part of E2E Security Project 

Generated on: 29/11/2017

Set-Version:
    (Get-FileHash .\Set-TCPVCon.ps1).hash | out-file .\Set-TCPVCon.md5

LEGAL DISCLAIMER

-----------------------------------------------------------------------------#>

<#
.SYNOPSIS
	Set-TCPVCon.ps1 deploy and schedule TCPVCon script on servers list 

.DESCRIPTION
	Set-TCPVCon.ps1 deploy TCPVCon.bat script from T-Systems on 
    C:\SoftwareBase\TCPVdata and schedule it to run

.EXAMPLE
	Set-TCPVConRollOut.ps1 -verbose

.PARAMETER -file 
    Input Server list to deploy script

.NOTES
	Name                : Set-TCPVConRollOut.ps1
	Author              : Eloy Salamanca <eloy.salamanca@guadaltech.es>
	Last Edit           : 29/11/2017
	Current Version     : 1.0

	History				: 1.0 - Posted 29/11/2017 - First iteration

	Rights Required		: Local admin on workshop for installing applications
                        : Set-ExecutionPolicy to 'Unrestricted' for the .ps1 file to execute the installs

.LINK

.FUNCTIONALITY
   Part of Capacity Planning Data Gathering Report,
   to save performance information of single servers into SQL db.
#>
[CmdletBinding()]
param (
    [Parameter(HelpMessage="Enter file name with servers list")]
    [string]$file=".\Servers.txt",

    [ValidateSet(2,3)]
    [Alias('dt')]
    [int]$drivetype = 3,

    [bool]$InstallAgent = $true
)
# =======================================================================
# FUNCTIONS
# =======================================================================
Function Install-Agent
{
    param ($srv)

    $SourceAgentFile1 = '.\tcpvcon_collect.bat'
    $SourceAgentFile2 = '.\tcpvcon.exe'
    $DestinationAgentFile1 = '\\$srv\c$\SoftwareBase\tcpvcon_ES1\tcpvcon_collect.bat'
    $DestinationAgentFile2 = '\\$srv\c$\SoftwareBase\tcpvcon_ES1\tcpvcon.exe'
    $DestinationAgentPath = '\\$srv\c$\SoftwareBase\tcpvcon_ES1'
    
    # read-host -prompt "Enter password to be encrypted in mypassword.txt" -assecurestring | convertfrom-securestring | out-file '.\securestring.txt'
    $pass = cat '.\securestring.txt' | convertto-securestring
    $mycred = new-object -typename System.Management.Automation.PSCredential -argumentlist "AdmHerreM01@heiway.net",$pass

    # Check for parameter
    if (!$srv) { 
        # One or more parameters didn't contain values. 
        Write-Host "Install-Agent function called with no server destination." 
    } else {     
        # Copying and Scheduling Agent
        Write-Verbose "Stage-1: Copying Agent to $srv"
        Write-Verbose "Check for SoftwareBase directory"
        If (!(Test-Path "\\$srv\c$\SoftwareBase")) {
            Invoke-Command -ComputerName $srv -Credential $mycred -ScriptBlock { New-Item -Path "C:\SoftwareBase" -ItemType Directory -Force } 
            Write-Verbose "C:\SoftwareBase Directory created on $srv"
        }
        Write-Verbose "Check for tcpvcon_ES1 directory"
        If (!(Test-Path $DestinationAgentPath)) {
            Write-Verbose "Creating tcpvcon_ES1 Directory on $srv"
            Invoke-Command -ComputerName $srv -Credential $mycred -ScriptBlock { New-Item -Path "C:\SoftwareBase\tcpvcon_ES1" -ItemType Directory -Force }
            Write-Verbose "tcpvcon_ES1 Directory created on $srv"
        }
        If (Test-Path $DestinationAgentFile1) {
            Write-Verbose "Removing old versions"
            Remove-Item $DestinationAgentFile1 -Force
        }
        If (Test-Path $DestinationAgentFile2) {
            Write-Verbose "Removing old versions"
            Remove-Item $DestinationAgentFile2 -Force
        }
        Write-Verbose "Copying new versions agent script"
        New-PSDrive -Name X -PSProvider FileSystem -Root \\$srv\c$\SoftwareBase\tcpvcon_ES1\
        Copy-Item $SourceAgentFile1 X:\
        Copy-Item $SourceAgentFile2 X:\
        Remove-PSDrive X

        # Setting Scheduling Agent to run all day long until Dec-4
        Invoke-Command -ComputerName $srv -Credential $mycred -ScriptBlock { schtasks /create /tn tcpvcon_ES1 /tr "C:\SoftwareBase\tcpvcon_ES1\tcpvcon_collect.bat" /sd 30/11/2017 /ed 04/12/2017 /ru SYSTEM /HRESULT }
    }
}    
# =======================================================================
# PROCESS
# =======================================================================
#$date = (Get-Date -Format ‘yyyyMMddHHmmss’).ToString()
$date = Get-Date
$servers = Get-Content $file
$TotalServers = $Servers.count
$Count = 1
$Message = "Deploying Set-TCPVCon to Servers list..."

foreach ($server in $servers) {
    Try { 
        # CountDown: <http://community.spiceworks.com/scripts/show/1712-start-countdown>
        Write-Progress -Id 1 -Activity $Message -Status "Deploying Agent on $TotalServers servers, $($TotalServers - $Count) left, currently on: $server" -PercentComplete (($Count / $TotalServers) * 100)
        Write-Verbose "Trying with $server.."
        
        Test-Connection $server -Count 1 -ErrorAction Stop | Out-Null

    } Catch {
        $ServersDown += $server
        Throw "Server $server is not reachable. Leaving it from the process. Adding it to Servers Down"
    }

    # Installing and Scheduling Agent
    Write-Verbose "Stage-2: Deploying agent"
    If ($InstallAgent) {
        Install-Agent -Srv $server
    }
    $Count++
}
Write-Progress -Id 1 -Activity $Message -Status "Completed" -PercentComplete 100 -Completed
Write-Verbose "List of Servers Down: $ServersDown"
Write-Verbose "==> Set-TCPVConRollOut.ps1 Finished"