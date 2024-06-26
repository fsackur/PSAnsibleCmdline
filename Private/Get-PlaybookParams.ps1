using namespace System.Management.Automation

function ToTitleCase
{
    param
    (
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
    [Diagnostics.CodeAnalysis.SuppressMessage("PSUseSingularNouns", "")]
    [OutputType([RuntimeDefinedParameterDictionary])]
    [CmdletBinding()]
    param ()

    if ($Script:PlaybookParams) {return $Script:PlaybookParams}

    $Help = ansible-playbook --help
    $Help = $Help.Where({$_ -match '^options:'}, 'SkipUntil') -ne "" -notmatch '^(  )?\w' | Out-String
    $Blocks = $Help.Trim() -split "`n  (?=-)"

    [string[]]$Aliases = $null
    $SingleLetterAliases = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    $Params = $Blocks | ForEach-Object {
        $Aliases, $Help = $_ -split "(?s)\s{2,}"
        $Aliases = $Aliases -split ", "
        $Help = $Help -join " "

        if ($Aliases -match '-verbose') {return}  # special case!

        $Arg = ""
        $Aliases = $Aliases | ForEach-Object {$Alias, $Arg = $_ -split " "; $Alias}

        # Assumption: there's no more than one single-letter alias
        $SingleLetterAlias = @($Aliases) -match '^-\w$' -replace '-'
        if ($SingleLetterAlias -and -not $SingleLetterAliases.Add($SingleLetterAlias))
        {
            # we have a case-insensitive duplicate :-(
            $Aliases = @($Aliases) -notmatch '^-\w$'
        }

        $Name = @($Aliases) -match '^--' | Select-Object -First 1
        $Aliases = @($Aliases) -ne $Name

        if ($Name -match '\w-\w')
        {
            $Aliases = $Name, $Aliases | Write-Output
        }

        $Name = ($Name | ToTitleCase) -replace '-'
        $Aliases = @($Aliases) -replace '^--?'


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
        if ($Aliases)
        {
            $Attrs.Add([Alias]::new($Aliases))
        }
        $ParamAttr = [ParameterAttribute]::new()
        $ParamAttr.HelpMessage = $Help
        $Attrs.Add($ParamAttr)
        [RuntimeDefinedParameter]::new($Name, $Type, $Attrs)
    }

    $Script:PlaybookParams = [RuntimeDefinedParameterDictionary]::new()
    $Params | ForEach-Object {$Script:PlaybookParams.Add($_.Name, $_)}
    $Script:PlaybookParams
}
