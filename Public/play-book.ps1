function Invoke-AnsiblePlaybook
{
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

        # If the user passed a value that's not in the completion cache, invalidate the cache
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            $CompletionKey = $Script:PlaybookCompletableParams[$_.Key]
            if (-not $CompletionKey) {return}
            $Completions = $Script:PlaybookCompletionValues[$CompletionKey]
            if ($_.Value | Where-Object {$_ -inotin $Completions})
            {
                $Script:PlaybookCompletionValues[$CompletionKey] = $null
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

$Script:PlaybookCompletionValues = @{}
$Script:PlaybookCompletableParams = @{
    Tags = 'Tags'
    SkipTags = 'Tags'
    StartAtTask = 'Tasks'
    Limit = 'Hosts'
}
$Script:PlaybookCompleters = @{
    Tags = {
        param ($Playbook, $Inventory)
        $PSBoundParameters.ListTags = $true

        $Output = Invoke-Playbook @PSBoundParameters
        $Tags = $Output |
            ForEach-Object {if ($_ -match 'TAGS: \[(?<tags>.+?)\]') {$Matches.tags -split ', '}} |
            Sort-Object -Unique
        $Tags, 'always', 'never' | Write-Output
    }

    Tasks = {
        param ($Playbook, $Inventory, $Tags, $SkipTags)
        $PSBoundParameters.ListTasks = $true

        $Output = Invoke-Playbook @PSBoundParameters
        $Tasks = $Output |
            ForEach-Object {if ($_ -match '^\s+[^:]+ : (?<task>.*?)\s+TAGS:') {$Matches.task}} |
            Select-Object -Unique
        $Tasks
    }

    Hosts = {
        param ($Playbook, $Inventory)
        $PSBoundParameters.ListHosts = $true

        $Output = Invoke-Playbook @PSBoundParameters
        $Hosts = $Output |
            ForEach-Object {if ($_ -match '^\s+(?<host>\S*[^:])$') {$Matches.host}} |
            Sort-Object -Unique
        $Hosts, 'localhost', 'all' | Write-Output
    }
}

$PlaybookCompletableParams.GetEnumerator() | ForEach-Object {
    $ParamName = $_.Key
    $CompletionKey = $_.Value
    $Fetcher = $PlaybookCompleters[$CompletionKey]

    $Completer = {
        param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $Completions = $Script:PlaybookCompletionValues[$CompletionKey]
        $wordToComplete = $wordToComplete -replace "^(?<quote>['`"])(?<content>.*?)\k<quote>$", '${content}'

        # The user may be developing the playbook and updating tags, tasks, or hosts.
        # If they type a word to complete that we don't have, invalidate the cache.
        foreach ($Attempt in 1..2)
        {
            $ShouldRetry = $true
            if (-not $Completions)
            {
                $Completions = & $Fetcher @fakeBoundParameters
                $Script:PlaybookCompletionValues[$CompletionKey] = $Completions
                $ShouldRetry = $false
            }

            $Completions = (@($Completions) -like "$wordToComplete*"), (@($Completions) -like "*$wordToComplete*") | Write-Output
            if ($Completions -and -not $ShouldRetry) {break}
        }

        @($Completions) -replace '.* .*', "'`$0'"
    }.GetNewClosure()

    Register-ArgumentCompleter -CommandName Invoke-Playbook -ParameterName $ParamName -ScriptBlock $Completer
}
