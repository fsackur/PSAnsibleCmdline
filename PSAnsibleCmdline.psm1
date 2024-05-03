'Private', 'Public' |
    Resolve-Path -RelativeBasePath $PSScriptRoot -ErrorAction Ignore |
    Get-ChildItem -Filter '*.ps1' |
    ForEach-Object {. $_.FullName}

[string[]]$CommonParameters = (
    'Verbose',
    'Debug',
    'ErrorAction',
    'WarningAction',
    'InformationAction',
    'ErrorVariable',
    'WarningVariable',
    'InformationVariable',
    'OutVariable',
    'OutBuffer',
    'PipelineVariable',
    'WhatIf',
    'Confirm'
)
