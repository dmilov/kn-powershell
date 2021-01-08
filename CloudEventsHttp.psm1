function New-CloudEvent {
<#
   .DESCRIPTION
   Creates CloudEvent object
#>
[CmdletBinding()]
param(
   [Parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   [string]
   $Type,

   [Parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   [string]
   $Source,

   [Parameter(Mandatory = $false)]
   [ValidateNotNullOrEmpty()]
   [string]
   $Id,

   [Parameter(Mandatory = $false)]
   [ValidateNotNullOrEmpty()]
   [DateTime]
   $Time,

   [Parameter(Mandatory = $false)]
   [hashtable]
   $Data
)

PROCESS {
   # DataContentType is set to 'application/json'
   $dataContentType = New-Object `
      -TypeName 'System.Net.Mime.ContentType' `
      -ArgumentList ([System.Net.Mime.MediaTypeNames+Application]::Json)

   $cloudEvent = New-Object `
      -TypeName 'CloudNative.CloudEvents.CloudEvent' `
      -ArgumentList @(
         $Type,
         (New-Object -TypeName 'System.Uri' -ArgumentList $Source),
         $Id,
         $Time,
         @())

   $cloudEvent.DataContentType = $dataContentType
   $cloudEvent.Data = ConvertTo-Json -InputObject $Data -Depth 3

   Write-Output $cloudEvent

}
}

function ConvertTo-HttpMessage {
<#
   .DESCRIPTION
   Converts CloudEvent to Headers (key-value) and Body(byte[])
#>
param(
   [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $false)]
   [ValidateNotNull()]
   [CloudNative.CloudEvents.CloudEvent]
   $CloudEvent,

   [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false)]
   [CloudNative.CloudEvents.ContentMode]
   $ContentMode)

   # Output Object
   $result = New-Object -TypeName PSCustomObject

   $cloudEventFormatter = New-Object 'CloudNative.CloudEvents.JsonEventFormatter'

   $HttpHeaderPrefix = "ce-";
   $SpecVersionHttpHeader1 = $HttpHeaderPrefix + "cloudEventsVersion";
   $SpecVersionHttpHeader2 = $HttpHeaderPrefix + "specversion";

   $headers = @{}

   foreach ($attribute in $cloudEvent.GetAttributes()) {
       if (-not $attribute.Key.Equals([CloudNative.CloudEvents.CloudEventAttributes]::DataAttributeName($cloudEvent.SpecVersion)) -and `
           -not $attribute.Key.Equals([CloudNative.CloudEvents.CloudEventAttributes]::DataContentTypeAttributeName($cloudEvent.SpecVersion))) {
           if ($attribute.Value -is [string]) {
               $headers.Add(($HttpHeaderPrefix + $attribute.Key), $attribute.Value.ToString())
           }
           elseif ($attribute.Value -is [DateTime]) {
               $headers.Add(($HttpHeaderPrefix + $attribute.Key), $attribute.Value.ToString("u"))
           }
           elseif ($attribute.Value -is [Uri] -or $attribute.Value -is [int]) {
               $headers.Add(($HttpHeaderPrefix + $attribute.Key), $attribute.Value.ToString())
           }
           else
           {
               $headers.Add(($HttpHeaderPrefix + $attribute.Key),
                   [System.Text.Encoding]::UTF8.GetString($cloudEventFormatter.EncodeAttribute($cloudEvent.SpecVersion, $attribute.Key,
                       $attribute.Value,
                       $cloudEvent.Extensions.Values)));
           }
       }
   }

   $result | Add-Member -MemberType NoteProperty -Name 'Headers' -Value $headers

   # Format Body as byte[]
   if ($ContentMode -eq [CloudNative.CloudEvents.ContentMode]::Structured) {

      $contentType = $null
      $buffer = $cloudEventFormatter.EncodeStructuredEvent($cloudEvent, [ref] $contentType)
      $result | Add-Member -MemberType NoteProperty -Name 'Body' -Value $buffer
      $result.Headers.Add('Content-Type', $contentType)
   }

   if ($ContentMode -eq [CloudNative.CloudEvents.ContentMode]::Binary) {
      $bodyData = $null

      if ($cloudEvent.DataContentType -ne $null) {
         $result.Headers.Add('Content-Type', $cloudEvent.DataContentType)
      }

      if ($cloudEvent.Data -is [byte[]]) {
         $bodyData = $cloudEvent.Data
      }
      elseif ($cloudEvent.Data -is [string]) {
         $bodyData = [System.Text.Encoding]::UTF8.GetBytes($cloudEvent.Data.ToString())
      }
      elseif ($cloudEvent.Data -is [IO.Stream]) {
         $buffer = New-Object 'byte[]' -ArgumentList 1024
         $ms = New-Object 'IO.MemoryStream'
         $read = 0
         while (($read = $cloudEvent.Data.Read($buffer, 0, 1024)) -gt 0)
         {
            $ms.Write($buffer, 0, $read);
         }
         $bodyData = $ms.ToArray()
         $ms.Dispose()
      } else {
         $bodyData = $cloudEventFormatter.EncodeAttribute($cloudEvent.SpecVersion,
            [CloudNative.CloudEvents.CloudEventAttributes]::DataAttributeName($cloudEvent.SpecVersion),
            $cloudEvent.Data, $cloudEvent.Extensions.Values)
      }

      $result | Add-Member -MemberType NoteProperty -Name 'Body' -Value $bodyData
   }

   $result
}

function ConvertFrom-HttpMessage {
<#
   .DESCRIPTION
   Converts Object of Headers (key-value) and Body(byte[]) to CloudEvent object
#>
param(
   [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false)]
   [ValidateNotNull()]
   [hashtable]
   $Headers,

   [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false)]
   [ValidateNotNull()]
   [byte[]]
   $Body)

   $HttpHeaderPrefix = "ce-";
   $SpecVersionHttpHeader1 = $HttpHeaderPrefix + "cloudEventsVersion";
   $SpecVersionHttpHeader2 = $HttpHeaderPrefix + "specversion";

   $result = $null

   if ($Headers['Content-Type'] -ne $null) {
      $ContentType = $Headers['Content-Type'][0]

      if ($ContentType.StartsWith([CloudNative.CloudEvents.CloudEvent]::MediaType,
                       [StringComparison]::InvariantCultureIgnoreCase)) {

         # Handle Structured Mode
         $ctParts = $ContentType.Split(';')
         if ($ctParts[0].Trim().EndsWith([CloudNative.CloudEvents.JsonEventFormatter]::MediaTypeSuffix,
            [StringComparison]::InvariantCultureIgnoreCase)) {


            $json = [System.Text.Encoding]::UTF8.GetString($Body)
            $jObject = [Newtonsoft.Json.Linq.JObject]::Parse($json)
            $formatter = New-Object 'CloudNative.CloudEvents.JsonEventFormatter'
            $result = $formatter.DecodeJObject($jObject, $null)
            $result.Data = $result.Data.ToString() | ConvertFrom-Json -AsHashtable -Depth 10
         }
         else
         {
            throw "Unsupported CloudEvents encoding"
         }
      } else {
         # Handle  Binary Mode
         $version = [CloudNative.CloudEvents.CloudEventsSpecVersion]::Default
         if ($Headers.Contains($SpecVersionHttpHeader1)) {
            $version = [CloudNative.CloudEvents.CloudEventsSpecVersion]::V0_1
         }

         if ($Headers.Contains($SpecVersionHttpHeader2)) {
            if ($Headers[$SpecVersionHttpHeader2][0] -eq "0.2") {
               $version = [CloudNative.CloudEvents.CloudEventsSpecVersion]::V0_2
            } elseif ($Headers[$SpecVersionHttpHeader2][0] -eq "0.3") {
               $version = [CloudNative.CloudEvents.CloudEventsSpecVersion]::V0_3
            }
         }

         $cloudEvent = New-Object `
                        -TypeName 'CloudNative.CloudEvents.CloudEvent' `
                        -ArgumentList @($version, $null);
         $attributes = $cloudEvent.GetAttributes();
         foreach ($httpHeader in $Headers.GetEnumerator()) {
           if ($httpHeader.Key.Equals($SpecVersionHttpHeader1, [StringComparison]::InvariantCultureIgnoreCase) -or `
               $httpHeader.Key.Equals($SpecVersionHttpHeader2, [StringComparison]::InvariantCultureIgnoreCase)) {
               continue
           }

           if ($httpHeader.Key.StartsWith($HttpHeaderPrefix, [StringComparison]::InvariantCultureIgnoreCase)) {
               $headerValue = $httpHeader.Value[0]
               $name = $httpHeader.Key.Substring(3);

               # abolished structures in headers in 1.0
               if ($version -ne [CloudNative.CloudEvents.CloudEventsSpecVersion]::V0_1 -and `
                   $headerValue -ne $null -and `
                   $headerValue.StartsWith('"') -and `
                   $headerValue.EndsWith('"') -or `
                   $headerValue.StartsWith("'") -and $headerValue.EndsWith("'") -or `
                   $headerValue.StartsWith("{") -and $headerValue.EndsWith("}") -or `
                   $headerValue.StartsWith("[") -and $headerValue.EndsWith("]")) {

                  $jsonFormatter = New-Object 'CloudNative.CloudEvents.JsonEventFormatter'
                  $attributes[$name] = $jsonFormatter.DecodeAttribute($version, $name,
                       [System.Text.Encoding]::UTF8.GetBytes($headerValue), $null);
               } else {
                  $attributes[$name] = $headerValue
               }
           }
         }

         if ($Headers['Content-Type'] -ne $null -and $Headers['Content-Type'][0] -is [string]) {
            $cloudEvent.DataContentType = New-Object 'System.Net.Mime.ContentType' -ArgumentList @($Headers['Content-Type'][0])
         }

         $cloudEvent.Data = [System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json -AsHashtable -Depth 10

         $result = $cloudEvent
      }
   }

   $result
}
