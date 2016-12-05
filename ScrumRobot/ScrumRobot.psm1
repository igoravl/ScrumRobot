Function Start-ScrumRobot
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory=$true)]
        [object]
        $Collection,

        [Parameter(Mandatory=$true)]
        [string]
        $Project,

        [Parameter()]
        [int]
        $NumberOfReleases = 2,

        [Parameter()]
        [int]
        $SprintsPerRelease = 3,

        [Parameter()]
        [int]
        $WeeksPerSprint = 2,

        [switch]
        $ResetSprintNumber,

        [switch]
        $RandomizeValues,

        [Parameter()]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    Begin
    {
        $tpc = Get-TfsTeamProjectCollection -Collection $Collection -Credential $Credential
        $tp = Get-TfsTeamProject -Collection $Collection -Project $Project
    }

    Process
    {
        if (-not $tp)
        {
            if ($PSCmdlet.ShouldProcess($Project, "Create new team project"))
            {
                New-TfsTeamProject -Collection $Collection -Project $Project 
                    -Description "Team Project created by ScrumRobot at $(Get-Date)" 
                    -ProcessTemplate Scrum -SourceControl Git
            }
            else
            {
                throw "Skipped creating $Project. Unable to proceed."
            }
        }

        RecreateAreas -Collection $tpc -Project $tp

        RecreateSprints -Collection $tpc -Project $tp

        RecreateTasks -Collection $tpc -Project $tp
    }
}

Function Get-ScrumRobotSampleAreas
{
    Process
    {
        return GetSampleFile 'Areas'
    }
}

Function Get-ScrumRobotSampleBacklog
{
    Process
    {
        return GetSampleFile 'Backlog'
    }
}

Function RecreateAreas($Collection, $Project)
{
    Function CreateArea($area, $parentPath)
    {
        if($PSCmdlet.ShouldProcess("$parentPath\$($area.Name)", 'Create area'))
        {
            New-TfsArea -Collection $Collection -Project $Project -Area "$parentPath\$($area.Name)" | Out-Null
        }

        foreach($c in $area.Children)
        {
            CreateArea $c "$parentPath\$($area.Name)"
        }
    }

    # Remove existing areas (if any)
    Get-TfsArea -Collection $Collection -Project $Project | Sort {$_.RelativePath} -Descending | Remove-TfsArea -Collection $Collection -Project $Project

    # Create new areas
    $areas = Get-ScrumRobotSampleAreas
    foreach ($a in $areas.Areas)
    {
        CreateArea -Area $a
    }
}

Function RecreateSprints($Collection, $Project, $NumberOfReleases, $SprintsPerRelease, $WeeksPerSprint, $ResetSprintNumber)
{
    Function CreateIteration($iteration, $parentPath, $startDate, $endDate)
    {
        if($PSCmdlet.ShouldProcess("$parentPath\$($iteration.Name)", 'Create iteration'))
        {
            $parms = @{
                Collection = $Collection;
                Project = $Project;
                Iteration = "$parentPath\$($iteration.Name)";
            }

            if ($startDate -and $endData)
            {
                $parms['StartDate'] = $startDate
                $parms['FinishDate'] = $endDate
            }

            New-TfsIteration @parms | Out-Null
        }

        1..
        {
            CreateIteration $c "$parentPath\$($iteration.Name)"
        }
    }

    # Remove existing iterations (if any)
    Get-TfsIteration -Collection $Collection -Project $Project | Sort {$_.RelativePath} -Descending | Remove-TfsIteration -Collection $Collection -Project $Project

    # Create new iterations
    1..$
}

Function RecreateTasks($Collection, $Project)
{
}

Function GetSampleFile($file)
{
    $scriptDir = 'D:\Projects\VSTS_Igoravl\Personal\Personal\ScrumRobot\PS' # $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
    $jsonFile = Join-Path $scriptDir "$file.json"

    return Get-Content -Path $jsonFile -ReadCount 0 | Out-String | ConvertFrom-Json
}

