function Invoke-AnsiblePlaybook
{
    <#

    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Playbook,

        [Alias('vv', 'vvv', 'vvvv', 'vvvvv')]
        [switch]$v
    )

    dynamicparam
    {
        $DynParams = Get-PlaybookParams
        $DynParams
    }

    end
    {
        $Verbosity = if ($v -or $VerbosePreference -notin ('SilentlyContinue', 'Ignore'))
        {
            if ($MyInvocation.Line -match '\s-(v*)(\s|$)') {$Matches[1].Length} else {3}
        }

        $PlaybookArgs = [Collections.Generic.List[string]]::new()
        $PSBoundParameters.GetEnumerator() |
            ForEach-Object {
                $Param = $DynParams[$_.Key]
                if (-not $Param) {return}  # filter out static and common params

                $PSName = $_.Key
                $Aliases = $Param.Attributes.AliasNames
                $Name = $Aliases | Where-Object {$_ -replace '-' -ilike $PSName} | Select-Object -First 1
                if (-not $Name) {$Name = $PSName.ToLower()}

                if ($Param.ParameterType -eq [switch])
                {
                    $PlaybookArgs.Add("--$Name")
                }
                else
                {
                    $PlaybookArgs.Add("--$Name")
                    $PlaybookArgs.Add("$($_.Value)")
                }
            }

        if ($Verbosity)
        {
            $PlaybookArgs.Add("-$('v' * $Verbosity)")
        }

        try
        {
            $ANSIBLE_DEBUG = $env:ANSIBLE_DEBUG
            if ($DebugPreference -notin ('SilentlyContinue', 'Ignore')) {$env:ANSIBLE_DEBUG = 1}

            if ($Verbosity) {$VerbosePreference = 'Continue'}
            Write-Verbose "ansible-playbook $PlaybookArgs $Playbook"
            ansible-playbook $PlaybookArgs $Playbook
        }
        finally
        {
            $env:ANSIBLE_DEBUG = $ANSIBLE_DEBUG
        }
    }
}

Set-Alias play-book Invoke-AnsiblePlaybook
