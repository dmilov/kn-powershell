# Import SDK Module
Import-Module ./CloudEventsHttp.psd1
function Start-HttpCloudEventListener {
<#
   .DESCRIPTION
   Starts a HTTP Listener on specified Url
#>

[CmdletBinding()]
param(
   [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false)]
   [ValidateNotNull()]
   [string]
   $Url
)

   $listener = New-Object -Type 'System.Net.HttpListener'
   $listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous
   $listener.Prefixes.Add($Url)

   try {
      $listener.Start()

      $context = $listener.GetContext()

      # Read Input Stream
      $buffer = New-Object 'byte[]' -ArgumentList 1024
      $ms = New-Object 'IO.MemoryStream'
      $read = 0
      while (($read = $context.Request.InputStream.Read($buffer, 0, 1024)) -gt 0) {
         $ms.Write($buffer, 0, $read);
      }
      $bodyData = $ms.ToArray()
      $ms.Dispose()

      # Read Headers
      $headers = @{}
      for($i =0; $i -lt $context.Request.Headers.Count; $i++) {
         $headers[$context.Request.Headers.GetKey($i)] = $context.Request.Headers.GetValues($i)
      }

      $cloudEvent = ConvertFrom-HttpMessage -Headers $headers -Body $bodyData

      if ( $cloudEvent -ne $null ) {
         Write-Host "Cloud Event"
         Write-Host "  Source: $($cloudEvent.Source)"
         Write-Host "  Subject: $($cloudEvent.Subject)"
         Write-Host "  Id: $($cloudEvent.Id)"
         Write-Host "  Data: $($cloudEvent.Data)"
         Get-Handler -CloudEvent $cloudEvent -Response $context.Response

         $context.Response.Close();
      }

   } catch {
      Write-Error $_
      $context.Response.StatusCode = [int]([System.Net.HttpStatusCode]::InternalServerError)
      $context.Response.Close();
   } finally {
      $listener.Stop()
   }
}

. ./handler.ps1

if(${env:PORT}) {
   $url = "http://*:${env:PORT}/"
} else {
   $url = "http://*:8080/"
}

Write-Host "Listening URL: ${url}"

# 1. Start CloudEvent Listener
while($true) {
   Start-HttpCloudEventListener -Url $url
}