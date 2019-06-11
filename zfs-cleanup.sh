# !/bin/bash

pod_name=`kubectl -n openebs get pod -l app=cstor-pool -o jsonpath='{.items[0].metadata.name}'`
pool_name=`kubectl -n openebs exec -it $pod_name -c cstor-pool -- zpool list -Ho name`
pool_name=${pool_name//[$'\t\r\n']}
zfs_volumes=( $(kubectl -n openebs exec -it $pod_name -c cstor-pool -- zfs list -t volume -o name | tail -n +2) )
pvcs=( $(kubectl get pvc --all-namespaces -o jsonpath="{.items[*]['spec.volumeName']}") )

for i in "${zfs_volumes[@]}"; do
  i=${i//[$'\t\r\n']}
  skip=

  for j in "${pvcs[@]}"; do
    [[ $i == "$pool_name/$j" ]] && { skip=1; break; }
  done

  if [[ -z $skip ]]; then
    echo $i
    kubectl -n openebs exec -it $pod_name -c cstor-pool -- zfs destroy -r $i
  fi
done
