$domain = 'itsolver.net'
$NameList = @($domain)
$ServerList = @('1.1.1.1','8.8.8.8')

$NsResult = @()
foreach ($Name in $NameList) {    
    $tempObj = "" | Select-Object Name,NameHost,Status,ErrorMessage    
try {        
    $dnsRecord = Resolve-DnsName $Name -Server $ServerList -ErrorAction Stop -Type NS     
    $tempObj.Name = $Name
    $tempObj.NameHost = ($dnsRecord.NameHost -join ',')
    if ($dnsRecord.NameHost -like '*.cloudflare.com*') {
      $tempObj.Status = 'cloudflare'
    }
    else {
      $tempObj.Status = 'not_cloudflare'
    }
    
    $tempObj.ErrorMessage = ''       
}    
catch {        
    $tempObj.Name = $Name        
    $tempObj.NameHost = ''        
    $tempObj.Status = 'NOT_OK'        
    $tempObj.ErrorMessage = $_.Exception.Message    
}    
$NsResult += $tempObj
}
Write-Host $NsResult