Param
(
   [Parameter(Mandatory = $false)]
   [switch]$Disconnect,
   [switch]$MFA,
   [string]$UserName, 
   [SecureString]$Password
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
elseif($MFA)
{
 #Check for MFA mosule
 $MFAExchangeModule = ((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter CreateExoPSSession.ps1 -Recurse ).FullName | Select-Object -Last 1)
 If ($null -eq $MFAExchangeModule)
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
   If ($null -eq $MFAExchangeModule)
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
 write-host
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
  Write-Host "Getting list of all custom domains" -ForegroundColor Yellow
  $DkimSigningConfig = Get-DkimSigningConfig
  $EXOdomains = (Get-DkimSigningConfig).name 
  Write-Host $EXOdomains

# Get list of domains to check dkim records
Write-Host "Collecting Selector1 and Selector2 CNAME records from all domains" -ForegroundColor Yellow
$counter = 0
foreach ($domain in $EXOdomains){
  ++$counter
  write-host "Working on this domain: "  -ForegroundColor Yellow
  write-host $domain
  if ($domain -Like '*.onmicrosoft.com') {
    write-host "Skipping initial domain"
    continue
  }
  # Check CNAME and NS records, if with cloudflare, create cname records otherwise get user to do manually, then enable DKIM.
  $index = $EXOdomains.IndexOf($domain)
  $cname1 = "selector1._domainkey.$domain"
  $cname1value = $DkimSigningConfig[$index].Selector1CNAME
  $cname2 = "selector2._domainkey.$domain"
  $cname2value = $DkimSigningConfig[$index].Selector2CNAME
  write-host "Microsoft wants these cname records to enable dkim: "  -ForegroundColor Yellow
  Write-Host $cname1, $cname1value
  Write-Host $cname2, $cname2value

  # get name servers

  $ServerList = @('1.1.1.1','8.8.8.8')
  $NsResult = @()   
  try {        
      write-host "Checking name servers: "  -ForegroundColor Yellow
      $dnsRecord = Resolve-DnsName $domain -Server $ServerList -ErrorAction Stop -Type NS     
      $tempObj = "" | Select-Object Name,NameHost,Status,ErrorMessage 
      $tempObj.Name = $Name
      $tempObj.NameHost = ($dnsRecord.NameHost -join ',')
      if ($dnsRecord.NameHost -like '*.cloudflare.com*') {
        $tempObj.Status = 'ok_cloudflare'
      }
      else {
        $tempObj.Status = 'ok_not_cloudflare'
      }
      
      $tempObj.ErrorMessage = ''       
  }    
  catch {        
      $tempObj.Name = $Name        
      $tempObj.NameHost = ''        
      $tempObj.Status = 'NOT_OK'        
      $tempObj.ErrorMessage = $_.Exception.Message    
  }    
  $NsResult = $tempObj
  
  $NsResult
  if ($NsResult -like '*ok_cloudflare*') {
    $CloudflareNS = $true
  }
  elseif ($NsResult -like '*ok_not_cloudflare*') {
    $CloudflareNS = $false
  }
    
  # get cname records
  $NameList = @($cname1, $cname2)
  $CnameResult = @()
  foreach ($Name in $NameList) {    
      $tempObj = "" | Select-Object Name,NameHost,Status,ErrorMessage    
  try {        
      $dnsRecord = Resolve-DnsName $Name -Server $ServerList -ErrorAction Stop -Type CNAME     
      $tempObj.Name = $Name
      $tempObj.NameHost =  ($dnsRecord.NameHost -join ',')
      if ($Name -eq $cname1 -And $dnsRecord.NameHost -eq $cname1value) {
        $tempObj.Status = 'OK'
      }
      elseif ($Name -eq $cname2 -And $dnsRecord.NameHost -eq $cname2value) {
        $tempObj.Status = 'OK'
      }
      else {
        $tempObj.Status = 'CNAME_NOT_OK'
      }
      
      $tempObj.ErrorMessage = ''       
  }    
  catch {        
      $tempObj.Name = $Name        
      $tempObj.NameHost = ''        
      $tempObj.Status = 'CNAME_NOT_OK'        
      $tempObj.ErrorMessage = $_.Exception.Message    
  }    
  $CnameResult += $tempObj
  }
  write-host "Checking if cname records exist: "  -ForegroundColor Yellow
  Write-Host $CnameResult

  if ($CnameResult -like '*CNAME_NOT_OK*' -and $CloudflareNS) { # if cname records not ok and ns == cloudflare, create cname records in cloudflare
    Remove-Variable $CnameResult
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
      $ExceptionResponse = $_.Exception.Response
      }
      $StatusCode
      $ExceptionResponse
      
      
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
      $StatusCode
      }
      catch
      {
      $StatusCode = $_.Exception.Response.StatusCode.value__
      $StatusCode
      }
      
      try
      {
      Invoke-RestMethod @params2
      $StatusCode = $Response.StatusCode
      $StatusCode
      }
      catch
      {
      $StatusCode = $_.Exception.Response.StatusCode.value__
      $StatusCode
      }
      
  }
  elseif ($CnameResult -like '*CNAME_NOT_OK*' -and $CloudflareNS -eq $false) {
    $msg = 'Name servers not with Cloudflare. Have you created the above cname records? [Y/N]'
do {
    $response = Read-Host -Prompt $msg
    if ($response -eq 'n') {
      write-host "Microsoft wants these cname records to enable dkim: "  -ForegroundColor Yellow
      Write-Host $cname1, $cname1value
      Write-Host $cname2, $cname2value
    }
} until ($response -eq 'y')
  }

  if (($StatusCode -eq 200) -or ($cnameresult -like '*Status=OK*' ) -or ($response -eq 'y')){
  try
  {
    $dkimconfig = Get-DkimSigningConfig -Identity $domain -ErrorAction SilentlyContinue
    if (!($dkimconfig)) {
      Write-Host "Adding domain: $domain to DKIM Signing Configuration..." : $domain -ForegroundColor Yellow
        New-DkimSigningConfig -DomainName $domain -Enabled $false
        }          
      
    # Enable DKIM
      Write-Host "Enabling DKIM for domain: $domain " -ForegroundColor Yellow
        Set-DkimSigningConfig -Identity $domain -Enabled $true   
    $StatusCode = $Response.StatusCode
  }
  catch
  {
    $StatusCode = $_.Exception.Response.StatusCode.value__
  }
  $StatusCode
  }
  else {
    Write-Host "DKIM not enabled because " $domain " cname records not created. Try creating the above cname records then retry this script." -ForegroundColor Yellow
  }
}

}
else
{
 Write-Host "Unable to connect to Exchange Online. Perhaps try -MFA switch." -ForegroundColor Red
}}