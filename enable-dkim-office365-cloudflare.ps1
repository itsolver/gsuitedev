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
import sys
import dnspython as dns
import dns.resolver

parser = argparse.ArgumentParser()
parser.add_argument('--user', help='o365 admin user')
parser.add_argument('--pass', help='o365 admin password')
parser.add_argument('--cfkey', help='cloudflare api key')
parser.add_argument('--manual', help='print cname records for user to manually add via domain management dashboard (cpanel/non-cloudflare)')
parser.add_argument("-v", "--verbose",dest='verbose',action='store_true', help="Verbose mode.")
parser.parse_args

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
if options.domain:
 $domain = options.domain
else: 
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

for cnameval in result:
    print ' cname target address:', cnameval.target

# Verify cname records exist
$check_cname1 = dns.resolver.query($cname1, 'CNAME')
if $check_cname1 == $cname1value:
  $cname_verified = true
else: 
  $cname_verifed = false
  print("Incorrect cname1 value: " & $check_cname1)
  print("Should be: " & $cname1value)

$check_cname2 = dns.resolver.query($cname2, 'CNAME')
if $check_cname2 == $cname2value:
  $cname_verified = true
else: 
  $cname_verifed = false
  print("Incorrect cname2 value: " & $check_cname2)
  print("Should be: " & $cname2value)


if $cname_verifed:
  # Enable DKIM
  $EXOdomains | ForEach-Object {
    Write-Host "Enabling DKIM for domain: $_ " -ForegroundColor Yellow
      Set-DkimSigningConfig -Identity $_ -Enabled $true   
  }
else: 
  print("DKIM not enabled. Either cname records incorrect, or check credentials/domain in Microsoft 365 tenant.")

Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0