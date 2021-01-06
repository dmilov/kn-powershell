Function Get-Handler {
   param(
      [Parameter(Position=0,Mandatory=$true)][CloudNative.CloudEvents.CloudEvent]$CloudEvent,
      [Parameter(Position=1,Mandatory=$true)][System.Net.HttpListenerResponse]$Response
   )

   Write-Host $ce

   $response.StatusCode = [int]([System.Net.HttpStatusCode]::OK)
}