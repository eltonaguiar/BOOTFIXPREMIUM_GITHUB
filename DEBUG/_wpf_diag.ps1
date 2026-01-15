$wpf = $true
$err = $null
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase -ErrorAction Stop
} catch {
    $wpf = $false
    $err = $_.Exception.Message
}
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -LiteralPath $PSCommandPath } else { (Get-Location).ProviderPath }
$xaml = Join-Path $scriptRoot 'WinRepairGUI.xaml'
[pscustomobject]@{
    GUICapable         = [Environment]::UserInteractive
    WPF_Loaded         = $wpf
    WPF_Error          = $err
    XAML_Resolved_Path = $xaml
    XAML_Exists        = (Test-Path $xaml)
} | Format-List
