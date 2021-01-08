Function Get-Handler {
   param(
      [Parameter(Position=0,Mandatory=$true)][CloudNative.CloudEvents.CloudEvent]$CloudEvent,
      [Parameter(Position=1,Mandatory=$true)][System.Net.HttpListenerResponse]$Response
   )

   Write-Host "Cloud Event"
   Write-Host "  Source: $($cloudEvent.Source)"
   Write-Host "  Subject: $($cloudEvent.Subject)"
   Write-Host "  Id: $($cloudEvent.Id)"
   if ($cloudEvent.data.data -ne $null) {
     # structured
     Write-Host "  Data.Data.Key: $($cloudEvent.data.data.Key)"
   } else {
     # binary
     Write-Host "  Data.Key: $($cloudEvent.data.Key)"
   }

   $response.StatusCode = [int]([System.Net.HttpStatusCode]::OK)
}
