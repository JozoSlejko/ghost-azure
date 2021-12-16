param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $HostName
)

Describe 'Check Website' {

    It 'Serves pages' {
      $request = [System.Net.WebRequest]::Create("https://$HostName/")
      $request.AllowAutoRedirect = $true
      $request.GetResponse().StatusCode |
        Should -Be 200 -Because "the website works"
    }

}
