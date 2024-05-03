using namespace System.Management.Automation

function ToTitleCase
{
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$String
    )

    begin {$Culture = Get-Culture}

    process
    {
        $Culture.TextInfo.ToTitleCase($String) -replace '-'
    }
}

function Get-PlaybookParams
{
    [CmdletBinding()]
    param ()

    if ($Script:PlaybookParams) {return $Script:PlaybookParams}

    $Help = ansible-playbook --help
    $Help = $Help.Where({$_ -match '^options:'}, 'SkipUntil') -ne "" -notmatch '^(  )?\w' | Out-String
    $Blocks = $Help.Trim() -split "`n  (?=-)"

    $Params = $Blocks | ForEach-Object {
        $Aliases, $Help = $_ -split "(?s)\s{2,}"
        $Aliases = $Aliases -split ", "
        $Help = $Help -join " "

        $Arg = ""
        $Aliases = $Aliases | ForEach-Object {$Alias, $Arg = $_ -split " "; $Alias}
        $Name = @($Aliases) -match '^--' | Select-Object -First 1
        $Aliases = ($Name, (@($Aliases) -ne $Name) | Write-Output) -replace '^--?'
        $Name = $Name -replace '^--?' | ToTitleCase

        $Type = if (-not $Arg)
        {
            [switch]
        }
        elseif ($Arg -match 'S$' -or $Help -match 'may be specified multiple times')
        {
            [string[]]
        }
        else
        {
            [string]
        }

        $Attrs = [Collections.ObjectModel.Collection[Attribute]]::new()
        $Attrs.Add([Alias]::new($Aliases))
        $ParamAttr = [ParameterAttribute]::new()
        $ParamAttr.HelpMessage = $Help
        $Attrs.Add($ParamAttr)
        [RuntimeDefinedParameter]::new($Name, $Type, $Attrs)
    }

    $Script:PlaybookParams = [RuntimeDefinedParameterDictionary]::new()
    $Params | ForEach-Object {$Script:PlaybookParams.Add($_.Name, $_)}
    $Script:PlaybookParams
}
