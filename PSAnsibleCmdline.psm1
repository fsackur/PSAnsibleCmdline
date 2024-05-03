'Private', 'Public' |
    Resolve-Path -RelativeBasePath $PSScriptRoot -ErrorAction Ignore |
    Get-ChildItem -Filter '*.ps1' |
    ForEach-Object {. $_.FullName}
