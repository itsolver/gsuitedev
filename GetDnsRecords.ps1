$NameList = @('selector1._domainkey.statewideroofing.net.au','selector2._domainkey.statewideroofing.net.au')
$ServerList = @('1.1.1.1','8.8.8.8')

$FinalResult = @()
foreach ($Name in $NameList) {    
    $tempObj = "" | Select-Object Name,NameHost,Status,ErrorMessage    
try {        
    $dnsRecord = Resolve-DnsName $Name -Server $ServerList -ErrorAction Stop -Type CNAME     
    $tempObj.Name = $Name
    $tempObj.NameHost =  ($dnsRecord.NameHost -join ',')                  
    $tempObj.Status = 'OK'
    $tempObj.ErrorMessage = ''       
}    
catch {        
    $tempObj.Name = $Name        
    $tempObj.NameHost = ''        
    $tempObj.Status = 'NOT_OK'        
    $tempObj.ErrorMessage = $_.Exception.Message    
}    
$FinalResult += $tempObj
}
return $FinalResult
