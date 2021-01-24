#/bin/bash

## MUST DO THESE COMMANDS FIRST, THEN CHANGE THE HARDCODED FIELDS BELOW
# hammer auth login basic -u <USERNAME> -p <PASSWORD>
# hammer org list
# hammer hostgroup list

org_id=1
hg_id=2


for i in `hammer host-collection list --fields name | egrep -v '^NAME|^-' `
do
  for j in `hammer host-collection hosts --name "$i"  --organization-id $org_id --fields name  | egrep -v '^NAME|^-' `
  do
  content_view=`hammer host info --name $j --fields "Content Information/Content View/ID" | egrep 'ID' | cut -d: -f2`
  hammer host update --name $j --hostgroup-id $hg_id --content-view-id $content_view
  done
done

