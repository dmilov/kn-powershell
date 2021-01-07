# Import SDK Module
Import-Module (Join-Path ($PSScriptRoot | Split-Path) 'CloudEventsHttp.psd1')

# 1. Create Cloud Event that produces NoContent
$cloudEvent1 = New-CloudEvent `
                  -Type test `
                  -Source 'urn:test' `
                  -Data @{'a'='b'} `
                  -Id 'test-id-1'

# 2. Create Cloud Event that produces CloudEvent
$cloudEvent2 = New-CloudEvent `
               -Type test `
               -Source 'urn:test' `
               -Data @{'a'='b'} `
               -Id 'return-cloud-event'

# 3. Send Structured Cloud Events
$cloudEvent1, $cloudEvent2 | Foreach-Object {
   # Convert CloudEvent to HttpMessage
   $httpMessage = $_ | ConvertTo-HttpMessage -ContentMode Structured

   $result = Invoke-WebRequest `
               -Uri 'http://localhost:8080/' `
               -Headers $httpMessage.Headers `
               -Body $httpMessage.Body

   Write-Host "Status Code: $($result.StatusCode)"

   if ($result.StatusCode -eq 200) {
      # Convert HttpMessage to CloudEvent
      $receivedCloudEvent = ConvertFrom-HttpMessage -Headers $result.Headers -Body $result.Content

      Write-Host "Cloud Event"
      Write-Host "  Source: $($receivedCloudEvent.Source)"
      Write-Host "  Subject: $($receivedCloudEvent.Subject)"
      Write-Host "  Id: $($receivedCloudEvent.Id)"
      Write-Host "  Data: $($receivedCloudEvent.Data)"
   }
}

# 4. Send Binary Cloud Events
$cloudEvent1, $cloudEvent2 | Foreach-Object {
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

      Write-Host "Cloud Event"
      Write-Host "  Source: $($receivedCloudEvent.Source)"
      Write-Host "  Subject: $($receivedCloudEvent.Subject)"
      Write-Host "  Id: $($receivedCloudEvent.Id)"
      Write-Host "  Data: $($receivedCloudEvent.Data)"
   }
}