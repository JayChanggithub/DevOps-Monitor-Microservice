#!/bin/bash

CWD=$PWD
__file__=$(basename $0)
log_name=$(basename $__file__ .sh).log
logdir=$CWD/reports
ns=kube-monitor
tm=$(date +'%Y%m%d%T' | tr -s ':' ' ' | tr -d ' ')
logdir=${CWD}/reports
cache_file=${logdir}/list_tmp.log

function prome_snapshot
{
    local prome_ip=$(kubectl get po -o wide -n $ns \
                    | grep prome \
                    | grep -Eo '([0-9]+\.){3}[0-9]+' \
                    | sed -E s'/ //'g)
    local api="http://${prome_ip}:9090/api/v1/admin/tsdb/snapshot?skip_head=false"
    local get_pod=$(kubectl get po -n $ns \
                    | grep prome \
                    | awk '{print $1}' \
                    | sed -E s'/ //'g)
    if [ "$prome_ip" == "" ] || [ "$get_pod" == "" ]; then
        echo -e "\$prome_ip pod is not running!\n"
        exit 255
    fi

    local backup_name=$(curl -XPOST $api)
    if [ "$backup_name" != "" ]; then
        local name=$(echo $backup_name \
                     | awk -F '{' '{print $3}' \
                     | awk -F ':' '{print $2}' \
                     | tr -d '}}|"' \
                     | sed -E s'/ //'g \
                     | head -n 1)
    fi
    kubectl -n $ns exec -it $get_pod -- ls /prometheus/snapshots \
                                        | awk '{print $NF}' \
                                        | grep -v '^\.$' \
                                        | grep -v '^\..$' \
                                        | tee ${cache_file}
    sed -i -r 's/'$(echo -e "\033")'\[[0-9]{1,2}(;([0-9]{1,2})?)?[mK]|\r//g' ${cache_file}

    if [ -n "(cat $cache_file)" ]; then
        for d in $(cat $cache_file)
        do
            local d_name=$(echo $d | grep -Eo '[0-9a-zA-Z]+\-[0-9a-zA-Z]+')

            if [ "$d_name" == "$name" ]; then
                kubectl -n $ns exec -it $get_pod -- mv -f /prometheus/snapshots/${d_name} \
                                                          /prometheus/snapshots/${tm}
                kubectl -n $ns exec -it $get_pod -- ls /prometheus/snapshots/
            fi
        done
    fi

    # reserve the latest sixteen backup files
    local backups_num=$(kubectl -n $ns exec -it $get_pod -- ls -al /prometheus/snapshots/ \
            | awk '/^d/ {print $NF}' \
            | awk -F 'm' '{print $2}' \
            | grep -coE '[0-9]+')
    if [ $backups_num -gt 16 ]; then
        local backups_rm=($(kubectl -n $ns exec -it $get_pod -- ls -al /prometheus/snapshots/ \
              | awk '/^d/ {print $NF}' \
              | awk -F 'm' '{print $2}' \
              | grep -oE '[0-9]+' \
              | sort -Vr \
              | sed -n 17,${backups_num}p))
        for f in "${backups_rm[@]}"
        do
            kubectl -n $ns exec -it $get_pod -- rm -rf /prometheus/snapshots/${f}
            printf "%s\t%30s %s ]\n" " * remove data " "[" "$f."
        done
    fi
}

prome_snapshot | tee ${logdir}/${log_name}
