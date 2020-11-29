# Get secrets from .env file
Get-Content .env | Where-Object {$_.length -gt 0} | Where-Object {!$_.StartsWith("#")} | ForEach-Object {

  $var = $_.Split('=',2).Trim()
  New-Variable -Scope Script -Name $var[0] -Value $var[1]

}
# # Accounts with MFA enabled: Replace <UPN> with your account in user principal name format (for example, navin@contoso.com) and run the following command:
# $UPN = Read-Host -Prompt  'Input your O365 admin account username'
# Connect-ExchangeOnline -UserPrincipalName $UPN -ShowProgress $true

# Accounts without MFA enabled:
import argparse
parser = argparse.ArgumentParser()

import argparse
import sys

def getOptions(args=sys.argv[1:]):
  parser = argparse.ArgumentParser(description="Parses command.")
  parser.add_argument('--user', help='o365 admin user')
  parser.add_argument('--pass', help='o365 admin password')
  parser.add_argument('--cfkey', help='cloudflare api key')
  parser.add_argument('--manual', help='print cname records for user to manually add via domain management dashboard (cpanel/non-cloudflare)')
  parser.add_argument("-v", "--verbose",dest='verbose',action='store_true', help="Verbose mode.")
  options = parser.parse_args(args)
  return options

options = getOptions(sys.argv[1:])

if options.verbose:
    print("Verbose mode on")
else:
    print("Verbose mode off")

if options.user && options.password:
  $m365_user = options.user
  $m365_pass = options.pass
else: 
  $m365_user = $O365_ADMIN_USER
  $m365_pass = $O365_ADMIN_PASS

if options.cfkey:
  $cf_api_key = options.cfkey
else: 
  $cf_api_key = $CLOUDFLARE_API_KEY

$secureStringPwd = $m365_pass | ConvertTo-SecureString -AsPlainText -Force 
$UserCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $m365_user, $secureStringPwd


#$UserCredential = Get-Credential
Connect-ExchangeOnline -Credential $UserCredential -ShowProgress $true

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
# To do: if(!CNAME)

if options.manual:
  print("Not with Cloudflare huh? That sucks. Please create the cname records manually:")
  print($cname1)
  print($cname1value)
  print($cname2)
  print($cname2value)
else:
  # Cloudflare: create CNAME records
  # Retrieve Zone ID
  $params0 = @{
  Uri         = "https://api.cloudflare.com/client/v4/zones?name=$domain&status=active&page=1&per_page=20&order=status&direction=desc&match=all"
  Headers     = @{ 'Authorization' = "Bearer $cf_api_key" }
  Method      = 'GET'
  ContentType = 'application/json'
  }
  $response = Invoke-RestMethod @params0
  $zoneId = $response.result.id

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
  try: 
    Invoke-RestMethod @params1
    Invoke-RestMethod @params2
  catch: 
    print("Failed to create cname records in Cloudflare")

# Enable DKIM
$EXOdomains | ForEach-Object {
  Write-Host "Enabling DKIM for domain: $_ " -ForegroundColor Yellow
    Set-DkimSigningConfig -Identity $_ -Enabled $true   
}       
# To do: catch errors

Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0