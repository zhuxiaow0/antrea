$ErrorActionPreference = "Stop"
$mountPath = $env:CONTAINER_SANDBOX_MOUNT_POINT
$mountPath = ($mountPath.Replace('\', '/')).TrimEnd('/')
$env:PATH = $env:PATH + ";$mountPath/Windows/System32;$mountPath/openvswitch/usr/bin;$mountPath/openvswitch/usr/sbin"
$OVS_DB_SCHEMA_PATH = "$mountPath/openvswitch/usr/share/openvswitch/vswitch.ovsschema"
$OVS_DB_PATH = "C:\openvswitch\etc\openvswitch\conf.db"
if ($(Test-Path $OVS_DB_SCHEMA_PATH) -and !$(Test-Path $OVS_DB_PATH)) {
    ovsdb-tool create "$OVS_DB_PATH" "$OVS_DB_SCHEMA_PATH"
}
ovsdb-server $OVS_DB_PATH -vfile:info --remote=punix:db.sock --log-file=/var/log/antrea/openvswitch/ovsdb-server.log --pidfile --detach
ovs-vsctl --no-wait init

# Set OVS version.
$OVS_VERSION=$(Get-Item $mountPath\openvswitch\driver\OVSExt.sys).VersionInfo.ProductVersion
ovs-vsctl --no-wait set Open_vSwitch . ovs_version=$OVS_VERSION

ovs-vswitchd --log-file=/var/log/antrea/openvswitch/ovs-vswitchd.log --pidfile -vfile:info --detach

$SleepInterval = 30
Write-Host "Started the loop that checks OVS status every $SleepInterval seconds"
while ($true) {
    if ( !( Get-Process ovsdb-server ) ) {
        Write-Host "ovsdb-server is not running, starting it again..."
        ovsdb-server $OVS_DB_PATH -vfile:info --remote=punix:db.sock --log-file=/var/log/antrea/openvswitch/ovsdb-server.log --pidfile --detach
    }
    if ( !( Get-Process ovs-vswitchd ) ) {
        Write-Host "ovs-vswitchd is not running, starting it again..."
        ovs-vswitchd --log-file=/var/log/antrea/openvswitch/ovs-vswitchd.log --pidfile -vfile:info --detach
    }
    Start-Sleep -Seconds $SleepInterval
}
