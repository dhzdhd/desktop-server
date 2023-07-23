$folders = @('calibre/books', 'calibre/config', 'mariadb/config', 'photoprism/storage', 'pihole/etc_dnsmasq', 'pihole/etc_dnsmasq.d', 'swag/config', 'vscode/config', 'vscode/config/code', 'prometheus/config', 'grafana/storage', 'jackett/config', 'jackett/downloads', 'lidarr/config', 'lidarr/music', 'lidarr/downloads', 'qbittorrent/config', 'qbittorrent/downloads')

foreach ($folder in $folders) {
    New-Item -ItemType Directory ./data/$folder
}

# function Invoke-Rename {
#     param
#     (
#         [Parameter(Mandatory)]
#         [System.IO.WaitForChangedResult]
#         $ChangeInformation
#     )

#     Write-Host 'Renaming files'
#     $ChangeInformation | Out-String | Write-Host -ForegroundColor DarkYellow
#     Rename-Item -Path "" -NewName ""
# }

# $timeout = 1000
# $AttributeFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite

# try {
#     Write-Host 'Monitoring swag directory to make changes.'

#     $watcher = New-Object -TypeName IO.FileSystemWatcher -ArgumentList ./data/swag/config/, * -Property @{
#         IncludeSubdirectories = $true
#         NotifyFilter          = $AttributeFilter
#     }

#     do {
#         $result = $watcher.WaitForChanged($ChangeTypes, $Timeout)
#         if ($result.TimedOut) { continue }

#         Invoke-Rename -Change $result
#     } while ($true)
# }
# finally {
#     $watcher.Dispose()
#     Write-Host 'Finished making changes, please restart containers.'
# }
