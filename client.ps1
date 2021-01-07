# Import SDK Module
Import-Module ./CloudEventsHttp.psd1

# 2. Create Cloud Event that produces CloudEvent
$cloudEvent = New-CloudEvent `
               -Type test `
               -Source 'urn:test' `
               -Data @{'a'='b'} `
               -Id 'return-cloud-event'

# 4. Send Binary Cloud Events
$cloudEvent | Foreach-Object {
   # Convert CloudEvent to HttpMessage
   $httpMessage = $_ | ConvertTo-HttpMessage -ContentMode Binary

   $result = Invoke-WebRequest `
               -Uri 'http://localhost:8080/' `
               -Headers $httpMessage.Headers `
               -Body $httpMessage.Body

   Write-Host "Status Code: $($result.StatusCode)"

   if ($result.StatusCode -eq 200) {
      # Convert HttpMessage to CloudEvent
      $receivedCloudEvent = ConvertFrom-HttpMessage -Headers $result.Headers -Body $result.Content
   }
}