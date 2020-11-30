Param
(
   [Parameter(Mandatory = $false)]
   [switch]$Disconnect,
   [switch]$MFA,
   [string]$UserName, 
   [string]$Password
)

# Get secrets from .env file
Get-Content .env | Where-Object {$_.length -gt 0} | Where-Object {!$_.StartsWith("#")} | ForEach-Object {

 $var = $_.Split('=',2).Trim()
 New-Variable -Scope Script -Name $var[0] -Value $var[1]

}

#Thanks to https://o365reports.com/2019/08/22/connect-exchange-online-powershell/
#Connect to Exchange Online PowerShell

#Disconnect existing sessions
if($Disconnect.IsPresent)
{
 Get-PSSession | Remove-PSSession
 Write-Host All sessions in the current window has been removed. -ForegroundColor Yellow
}
#Connect Exchnage Online with MFA
elseif($MFA.IsPresent)
{
 #Check for MFA mosule
 $MFAExchangeModule = ((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter CreateExoPSSession.ps1 -Recurse ).FullName | Select-Object -Last 1)
 If ($MFAExchangeModule -eq $null)
 {
  Write-Host  `nPlease install Exchange Online MFA Module.  -ForegroundColor yellow
  Write-Host You can install module using below blog : `nLink `nOR you can install module directly by entering "Y"`n
  $Confirm= Read-Host Are you sure you want to install module directly? [Y] Yes [N] No
  if($Confirm -match "[yY]")
  {
    Write-Host Yes
    Start-Process "iexplore.exe" "https://cmdletpswmodule.blob.core.windows.net/exopsmodule/Microsoft.Online.CSE.PSModule.Client.application"
  }
  else
  {
   Start-Process 'https://o365reports.com/2019/04/17/connect-exchange-online-using-mfa/'
   Exit
  }
  $Confirmation= Read-Host Have you installed Exchange Online MFA Module? [Y] Yes [N] No
  if($Confirmation -match "[yY]")
  {
   $MFAExchangeModule = ((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter CreateExoPSSession.ps1 -Recurse ).FullName | Select-Object -Last 1)
   If ($MFAExchangeModule -eq $null)
   {
    Write-Host Exchange Online MFA module is not available -ForegroundColor red
    Exit
   }
  }
  else
  { 
   Write-Host Exchange Online PowerShell Module is required
   Start-Process 'https://o365reports.com/2019/04/17/connect-exchange-online-using-mfa/'
   Exit
  }   
 }
 
 #Importing Exchange MFA Module
 write-host aaaa
 . "$MFAExchangeModule"
 Connect-EXOPSSession -WarningAction SilentlyContinue | Out-Null
}
#Connect Exchnage Online with Non-MFA
else
{
 if(($UserName -ne "") -and ($Password -ne "")) 
 { 
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force 
  $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword 
 } 
 else 
 { 
  $Credential=Get-Credential -Credential $null
 } 
 
 $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credential -Authentication Basic -AllowRedirection
 Import-PSSession $Session -DisableNameChecking -AllowClobber -WarningAction SilentlyContinue | Out-Null
}

#Check for connectivity
 if(!($Disconnect.IsPresent)){
If ((Get-PSSession | Where-Object { $_.ConfigurationName -like "*Exchange*" }) -ne $null)
{
 Write-Host `nSuccessfully connected to Exchange Online
}
else
{
 Write-Host `nUnable to connect to Exchange Online. Error occurred -ForegroundColor Red
}}


Write-Host "Getting list of all custom domains" -ForegroundColor Yellow
$EXOdomains = (Get-AcceptedDomain | Where-Object { $_.name -NotLike '*.onmicrosoft.com'}).name 
  
$EXOdomains | ForEach-Object {

$dkimconfig = Get-DkimSigningConfig -Identity $_ -ErrorAction SilentlyContinue

if (!($dkimconfig)) {
   Write-Host "Adding domain: $_ to DKIM Signing Configuration..." : $_ -ForegroundColor Yellow
     New-DkimSigningConfig -DomainName $_ -Enabled $false
     }          
 }

#Get DKIM info from the tenant
Write-Host "Collecting Selector1 and Selector2 CNAME records from all domains" -ForegroundColor Yellow
$DkimSigningConfig = Get-DkimSigningConfig 
$domain = $DkimSigningConfig.domain
$cname1 = "selector1._domainkey.$domain"
$cname1value = $DkimSigningConfig.Selector1CNAME
$cname2 = "selector2._domainkey.$domain"
$cname2value = $DkimSigningConfig.Selector2CNAME

# TODO: get name servers
# test dig cname records
# if ns == cloudflare and !test, create cname records in cloudflare
# else if ns != cloudflare and !test, print cname records and loop ask user to create, if user answers Y then proceed to enable DKIM
# else: proceed to enable dkim

# Cloudflare: create CNAME records
# Retrieve Zone ID
$params0 = @{
Uri         = "https://api.cloudflare.com/client/v4/zones?name=$domain&status=active&page=1&per_page=20&order=status&direction=desc&match=all"
Headers     = @{ 'Authorization' = "Bearer $CLOUDFLARE_API_KEY" }
Method      = 'GET'
ContentType = 'application/json'
}

try
{
 $response = Invoke-RestMethod @params0
 $zoneId = $response.result.id
 $StatusCode = $Response.StatusCode
}
catch
{
 $StatusCode = $_.Exception.Response.StatusCode.value__
}
$StatusCode


# Create DNS records 
$jsonBody1 = '{"content":"' + $cname1value + '","data":{},"name":"' + $cname1 + '","proxiable":true,"proxied":false,"ttl":1,"type":"CNAME","zone_id":"' + $zoneId + '","zone_name":"' + $domain + '"}'
$jsonBody2 = '{"content":"' + $cname2value + '","data":{},"name":"' + $cname2 + '","proxiable":true,"proxied":false,"ttl":1,"type":"CNAME","zone_id":"' + $zoneId + '","zone_name":"' + $domain + '"}'

$params1 = @{
 Uri         = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records"
 Headers     = @{ 'Authorization' = "Bearer $CLOUDFLARE_API_KEY" }
 Method      = 'POST'
 Body        = $jsonBody1
 ContentType = 'application/json'
}

$params2 = @{
 Uri         = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records"
 Headers     = @{ 'Authorization' = "Bearer $CLOUDFLARE_API_KEY" }
 Method      = 'POST'
 Body        = $jsonBody2
 ContentType = 'application/json'
}

try
{
 Invoke-RestMethod @params1
 $StatusCode = $Response.StatusCode
}
catch
{
 $StatusCode = $_.Exception.Response.StatusCode.value__
}
$StatusCode

try
{
 Invoke-RestMethod @params2
 $StatusCode = $Response.StatusCode
}
catch
{
 $StatusCode = $_.Exception.Response.StatusCode.value__
}
$StatusCode

if ($StatusCode -eq 200){
 try
 {
   # Enable DKIM
   $EXOdomains | ForEach-Object {
     Write-Host "Enabling DKIM for domain: $_ " -ForegroundColor Yellow
       Set-DkimSigningConfig -Identity $_ -Enabled $true   
   }     
   $StatusCode = $Response.StatusCode
 }
 catch
 {
   $StatusCode = $_.Exception.Response.StatusCode.value__
 }
 $StatusCode
 }
 else {
   Write-Host "DKIM not enabled because domains not setup in Cloudflare" -ForegroundColor Yellow
 }

# Close remote shells
if ($ExoSession) { Remove-PSSession -Session $ExoSession -ErrorAction SilentlyContinue }

# Clean up variables
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0