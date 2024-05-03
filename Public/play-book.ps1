function Invoke-AnsiblePlaybook
{
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Playbook
    )

    dynamicparam
    {
        return Get-PlaybookParams
    }

    end
    {
        [void]$PSBoundParameters.Remove("Playbook")
        $Script:CommonParameters | ForEach-Object {[void]$PSBoundParameters.Remove($_)}

        [string[]]$PlaybookArgs = @()

        $PlaybookArgs += $PSBoundParameters.GetEnumerator() |
            Where-Object {$_.Value -isnot [switch]} |
            ForEach-Object {"--$($_.Key)", "$($_.Value)"}

        $PlaybookArgs += $PSBoundParameters.GetEnumerator() |
            Where-Object {$_.Value -is [switch] -and $_.Value} |
            ForEach-Object {"--$($_.Key)"}

        ansible-playbook $PlaybookArgs $Playbook
    }
}

Set-Alias play-book Invoke-AnsiblePlaybook
