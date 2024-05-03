#requires -Modules @{ModuleName = 'InvokeBuild'; ModuleVersion = '5.11.1'}
#requires -Modules @{ModuleName = 'Microsoft.PowerShell.PSResourceGet'; ModuleVersion = '1.0.4.1'}

using namespace System.Management.Automation

[CmdletBinding()]
param
(
    [version]$NewVersion,

    [string]$PSGalleryApiKey = $env:PSGalleryApiKey,

    [string]$ModuleName = $MyInvocation.MyCommand.Name -replace '\.build\.ps1$',

    [string]$ManifestPath = "$ModuleName.psd1",

    [string[]]$Include = ('*.ps1xml', '*.psrc', 'README*', 'LICENSE*'),

    [string[]]$PSScriptFolders = ('Classes', 'Private', 'Public'),

    [string]$OutputFolder = 'Build'
)

$Script:Psd1SourcePath = Join-Path $BuildRoot "$ModuleName.psd1"
$Script:Manifest = Test-ModuleManifest $Psd1SourcePath -ErrorAction Stop
$Script:Psm1SourcePath = $Manifest.RootModule

task PSSA {
    $Files = $Include, $PSScriptFolders |
        Write-Output |
        Where-Object {Test-Path $_} |
        Get-ChildItem -Recurse

    $Files |
        ForEach-Object {
            Invoke-ScriptAnalyzer -Path $_.FullName -Recurse -Settings .\.vscode\PSScriptAnalyzerSettings.psd1
        } |
        Tee-Object -Variable PSSAOutput

    if ($PSSAOutput | Where-Object Severity -ge ([int][Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticSeverity]::Warning))
    {
        throw "PSSA found code violations"
    }
}

task Clean {
    remove $OutputFolder
}

task Version {
    if ($NewVersion)
    {
        Update-ModuleManifest $Psd1SourcePath -ModuleVersion $NewVersion
        $Script:Version = $NewVersion
    }
    else
    {
        $Script:Version = $Manifest.Version
    }
}

task BuildDir {
    $Script:BuildDir = [IO.Path]::Combine($PSScriptRoot, $OutputFolder, $ModuleName, $Version)
    New-Item $BuildDir -ItemType Directory -Force | Out-Null
}

task IncludedFiles BuildDir, {
    Copy-Item $Include $BuildDir
}

task Build Clean, Version, BuildDir, IncludedFiles, {
    $RootAst = [Language.Parser]::ParseFile($Psm1SourcePath, [ref]$null, [ref]$null)
    $Statements = $RootAst.EndBlock.Statements | Write-Output

    $Requirements = @()
    $Usings = @()
    $TextExtents = $Statements | ForEach-Object {
        $Extent = $_.Extent
        $DotSource = $_.Find({$args[0].InvocationOperator -eq [Language.TokenKind]::Dot}, $true)
        if (-not $DotSource)
        {
            return $Extent.Text
        }

        $RelStartOffset = $DotSource.Extent.StartOffset - $Extent.StartOffset
        # Delete the dot, so we just get the file path
        $FileFinder = $Extent.Text -replace "(?s)(?<=^.{$RelStartOffset})."
        $Files = Invoke-Expression $FileFinder | Resolve-Path

        $Files | ForEach-Object {
            $FileName = $_ | Split-Path -Leaf
            $FileAst = [Language.Parser]::ParseFile($_, [ref]$null, [ref]$null)
            $Content = $FileAst.Extent.Text

            $Requirements += $FileAst.ScriptRequirements.Extent.Text
            $Usings += $FileAst.UsingStatements.Extent.Text
            $SnipOffset = (
                $FileAst.ScriptRequirements.Extent.EndOffset,
                $FileAst.UsingStatements.Extent.EndOffset,
                $FileAst.ParamBlock.Extent.EndOffset  # will only exist to hold PSSA suppressions
            ) |
                Sort-Object |
                Select-Object -Last 1
            $Content = $Content -replace "(?s)^.{$SnipOffset}"

            "#region $FileName", $Content.Trim(), "#endregion $FileName" | Out-String
        }
    }

    $Requirements = $Requirements | Write-Output | ForEach-Object Trim | Sort-Object -Unique
    $Usings = $Usings | Write-Output | ForEach-Object Trim | Sort-Object -Unique
    $Psm1Content = $Requirements, $Usings, "", $TextExtents | Write-Output

    Copy-Item $Psd1SourcePath $BuildDir
    $Psm1Content > (Join-Path $BuildDir $Psm1SourcePath)
}

# Default task
task . Build

task Publish Build, {
    if (-not $PSGalleryApiKey)
    {
        if (Get-Command rbw -ErrorAction Ignore)  # TODO: sort out SecretManagement wrapper
        {
            $PSGalleryApiKey = rbw get PSGallery
        }
        else
        {
            throw 'PSGalleryApiKey is required'
        }
    }

    Publish-PSResource -Path $BuildDir -DestinationPath $OutputFolder -Repository PSGallery -ApiKey $PSGalleryApiKey
}
