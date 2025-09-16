fab config set mode command_line

fab auth login


$dbid = fab get /RealtimeSecurity.workspace/Eventhouse.eventhouse -q properties.databasesItemIds[0]
$clusteruri = fab get /RealtimeSecurity.workspace/Eventhouse.eventhouse -q properties.queryServiceUri
$connectionid = (new-guid).ToString()

(Get-Content C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json) -replace '<dbid>', $dbid | Out-File -encoding ASCII C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json
(Get-Content C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json) -replace '<clusteruri>', $clusteruri | Out-File -encoding ASCII C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json
(Get-Content C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json) -replace '<connectionid>', $connectionid | Out-File -encoding ASCII C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json

fab import RealtimeSecurity.workspace/kql.kqlqueryset -i C:\Demos\Realtimesecurity\kql.KQLQueryset -f
fab open /RealtimeSecurity.workspace

(Get-Content C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json) -replace $dbid, '<dbid>' | Out-File -encoding ASCII C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json
(Get-Content C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json) -replace $clusteruri, '<clusteruri>' | Out-File -encoding ASCII C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json
(Get-Content C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json) -replace $connectionid, '<connectionid>' | Out-File -encoding ASCII C:\Demos\Realtimesecurity\kql.KQLQueryset\RealTimeQueryset.json