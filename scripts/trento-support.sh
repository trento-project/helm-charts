#!/bin/bash

set -e

readonly ARGS=("$@")
declare -A VALID_FACILITIES=(
    ["configuration"]="configuration"
    ["base"]="base"
    ["kubernetes"]="kubernetes"
    ["all"]="all"
)

indent() { sed 's/^/  /'; }

collect_trento_configuration() {
    echo "===== TRENTO CONFIGURATION FILES ====="
    echo "/etc/trento/installer.conf:"
    echo "$(</etc/trento/installer.conf)"
    echo "===== END TRENTO CONFIGURATION FILES ====="
} &> "$OUTPUT"

collect_base_system() {
    echo "===== BASE SYSTEM DETAILS ====="
    set -x
    k3s --version
    helm version
    helm get all trento-server
    set +x
    echo "===== END BASE SYSTEM DETAILS ====="    
} &> "$OUTPUT"

collect_kubernetes_state() {
    echo "===== KUBERNETES CLUSTER STATE ====="
    set -x
    kubectl get nodes -o wide
    kubectl get pods
    kubectl logs deploy/trento-server-runner
    kubectl logs deploy/trento-server-web -c init
    kubectl logs deploy/trento-server-web
    kubectl describe deployments
    crictl images
    set +x
    echo "===== END KUBERNETES CLUSTER STATE ====="
} &> "$OUTPUT"

collect_all() {
    collect_trento_configuration
    collect_base_system
    collect_kubernetes_state    
}

generate_output() {
    if [[ " ${arr[*]} " =~ "all" ]]; then
        collect_all
        exit 0
    fi

    if [[ " ${arr[*]} " =~ "configuration" ]]; then
       collect_trento_configuration
    fi

    if [[ " ${arr[*]} " =~ "base" ]]; then
        collect_base_system
    fi

    if [[ " ${arr[*]} " =~ "kubernetes" ]]; then
        collect_kubernetes_state
    fi

    if [[ -n "$COMPRESS" ]]; then
        echo "COMPRESSING OUTPUT"
        tar -czf "$OUTPUT.tar.gz" "$OUTPUT"
        rm -f "$OUTPUT"
    fi
}

usage() {
    echo "Usage: $0 --output [stdout|file|file-tgz] --collect [configuration|base|kubernetes|all]"
}

cmdline() {
    # abort if we have less than 2 arguments
    if [[ $# -lt 2 ]]; then
        usage
        exit 1
    fi
    local arg=

    for arg; do
        local delim=""
        case "$arg" in
        --help) args="${args}-h " ;;
        --output) args="${args}-o " ;;
        --collect) args="${args}-c " ;;

        *)
            [[ "${arg:0:1}" == "-" ]] || delim="\""
            args="${args}${delim}${arg}${delim} "
            ;;
        esac
    done

    eval set -- "$args"

    while getopts "ho:c:" OPTION; do
        case $OPTION in
        h)
            usage
            exit 0
            ;;

        o)
            OUTPUT_OPT=$OPTARG
            if [[ $OUTPUT_OPT != "stdout" && $OUTPUT_OPT != "file" && $OUTPUT_OPT != "file-tgz" ]]; then
                echo "Invalid output type: $OUTPUT_OPT"
                usage
                exit 1
            fi

            if [ "$OUTPUT_OPT" = "stdout" ]; then
                OUTPUT="/dev/stdout"
            elif [ "$OUTPUT_OPT" = "file-tgz" ]; then
                OUTPUT="$(date +%Y-%m-%d_%H%M)_support.txt"
                COMPRESS=true
            else
                OUTPUT="$(date +%Y-%m-%d_%H%M)_support.txt"
            fi
            ;;

        c)
            COLLECT=$OPTARG
            IFS=, read -a arr <<<"${COLLECT}"            
            for key in "${!arr[@]}"; do
                if [[ -z "${VALID_FACILITIES[${arr[$key]}]}" ]]; then
                    printf '%s: unsupported facility\n' "${arr[$key]}"
                    usage
                    exit 1
                fi
            done
            ;;

        *)
            usage
            exit 0
            ;;
        esac
    done

    return 0
}

cmdline "${ARGS[@]}"
generate_output