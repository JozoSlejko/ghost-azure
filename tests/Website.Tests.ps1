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
      for ($i = 0; $i -lt 4; $i++) {
        Invoke-WebRequest "https://$HostName/"
        Start-Sleep -Seconds 30
      }
      $request = Invoke-WebRequest "https://$HostName/"
      $request.StatusCode |
        Should -Be 200 -Because "the website works"
    }

}

Describe 'Check Ghost Website Slot' {

  It 'Serves pages' -Skip:($SlotHostName -eq '') {
      for ($i = 0; $i -lt 4; $i++) {
        Invoke-WebRequest "https://$SlotHostName/"
        Start-Sleep -Seconds 30
      }
      $request = Invoke-WebRequest "https://$SlotHostName/"
      $request.StatusCode |
        Should -Be 200 -Because "the website works"
    }
}

Describe "Check Ghost Function App" {
  
  It "Redirects to AAD login" {
    $request = Invoke-WebRequest "https://$FunctionHostName/api/deleteGhostPosts"
    $request.StatusCode |
    Should -Be 302 -Because "unauthenticated redirect"
  }

}