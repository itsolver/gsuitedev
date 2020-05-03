# Accounts with MFA enabled: Replace <UPN> with your account in user principal name format (for example, navin@contoso.com) and run the following command:
$UPN = Read-Host -Prompt  'Input your O365 admin account username'
Connect-ExchangeOnline -UserPrincipalName $UPN -ShowProgress $true

# # Accounts without MFA:

# $Creds = Get-Credential
# $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Creds -Authentication Basic -AllowRedirection
# Import-PSSession $Session -DisableNameChecking

Write-Host "Getting list of all custom domains" -ForegroundColor Yellow
$EXOdomains = (Get-AcceptedDomain | ? { $_.name -NotLike '*.onmicrosoft.com'}).name 
    
$EXOdomains | foreach {

$dkimconfig = Get-DkimSigningConfig -Identity $_ -ErrorAction SilentlyContinue

if (!($dkimconfig)) {
  Write-Host "Adding domain: $_ to DKIM Signing Configuration..." : $_ -ForegroundColor Yellow
    New-DkimSigningConfig -DomainName $_ -Enabled $false
    }          
}

#Get DKIM info from the tenant
Write-Host "Collecting Selector1 and Selector2 CNAME records from all domains" -ForegroundColor Yellow
Get-DkimSigningConfig | select domain, Selector1CNAME, Selector2CNAME | fl | Out-File .\O365-DKIM-SigningKeys.txt

#Open the log in Notepad, after running the tasks
notepad .\O365-DKIM-SigningKeys.txt

$CNAMECreated = Read-Host -Prompt 'Have you manually created (e.g. selector1._domainkey) the CNAME records? y / n'

$EXOdomains | foreach {
if ($CNAmeCreated -eq 'y' ) {
  Write-Host "Enabling DKIM for domain: $_ " -ForegroundColor Yellow
    Set-DkimSigningConfig -Identity $_ -Enabled $true
    }   
  }       