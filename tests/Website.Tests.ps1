param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $HostName,

  [string] $SlotHostName,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $FunctionHostName
)

Describe 'Check Ghost Website' {

    It 'Serves pages' {
      $request = [System.Net.WebRequest]::Create("https://$HostName/")
      $request.AllowAutoRedirect = $true
      $request.GetResponse()
      Start-Sleep -Seconds 180
      $request.GetResponse().StatusCode |
        Should -Be 200 -Because "the website works"
    }

}

Describe 'Check Ghost Website Slot' {

  It 'Serves pages' {

    if ($slotHostName -ne $null) {
      $request = [System.Net.WebRequest]::Create("https://$SlotHostName/")
      $request.AllowAutoRedirect = $true
      $request.GetResponse()
      Start-Sleep -Seconds 180
      $request.GetResponse().StatusCode |
        Should -Be 200 -Because "the website works"  
    }
    else {
      Write-Output "Slot is not enabled"
    }
    
  }

}

# Describe "Check Ghost Function App" {
  
#   It "Redirects to AAD login" {
#     $request = [System.Net.WebRequest]::Create("https://$FunctionHostName/api/deleteGhostPosts")
#     $request.AllowAutoRedirect = $true
#     Start-Sleep -Seconds 300
#     $request.GetResponse().StatusCode |
#     Should -Be 302 -Because "unauthenticated redirect"
#   }

# }