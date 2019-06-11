# Velero/OpenEBS backup and restore

These are a couple of scripts to more easily use OpenEBS's Velero plugin so to include cStor volume snapshots in Velero backups. See https://github.com/openebs/velero-plugin for reference.

I use these scripts so I don't have to remember all the parameters and additional steps to correctly back up and restore namespaces that include OpenEBS cStor volumes.

## Notes

- When restoring, the `--include-namespaces` parameter is kinda ignored for volumes, while it works for everything else in the namespace. I was told by the OpenEBS devs that in order to be able restore only volumes for the selected namespaces I need to apply some label to the PVs before backing up and then use a selector during the restore to only take into account the selected namespaces. Therefore the backup script -before performing the actual backup or enabling a schedule- adds a label to the PVs in the selected namespaces with the format `openebs.io/namespace=#{namespace}`. The restore script then figures out which namespaces to ignore and uses a `notin` selector to skip restoring volumes in those namespaces;

- The backup script excludes a couple of `cert-manager` related resources that otherwise will cause restores to fail when certificates are involved. This doesn't affect the restore of certificates etc which will work just fine after restoring;

- The restore script sets the target ip of the volumes after restoring, as described in the link above.


## Usage

### Backup

```
./backup.rb --backup <backup name> --include-namespaces <namespaces>
```

### Schedule a backup

```
./backup.rb --backup <backup name> --include-namespaces <namespaces> --schedule '0 5 0 0 0'
```

### Restore

```
./restore.rb --backup <backup name> --include-namespaces <namespaces>
```
