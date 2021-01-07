Function Get-Handler {
   param(
      [Parameter(Position=0,Mandatory=$true)][CloudNative.CloudEvents.CloudEvent]$CloudEvent,
      [Parameter(Position=1,Mandatory=$true)][System.Net.HttpListenerResponse]$Response
   )

   Write-Host "Cloud Event"
   Write-Host "  Source: $($cloudEvent.Source)"
   Write-Host "  Subject: $($cloudEvent.Subject)"
   Write-Host "  Id: $($cloudEvent.Id)"
   $data = [System.Text.Encoding]::UTF8.GetString($cloudEvent.data)
   Write-Host "  Data: $data"

   $response.StatusCode = [int]([System.Net.HttpStatusCode]::OK)
}