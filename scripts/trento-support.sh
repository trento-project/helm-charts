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
    echo "#==[ Configuration File ]===========================#"
    echo "# /etc/trento/installer.conf"
    echo "$(</etc/trento/installer.conf)"    
} &> "$OUTPUT"

collect_base_system() {
    echo "#==[ Command ]======================================#"
    echo "# k3s --version"
    k3s --version

    echo "#==[ Command ]======================================#"
    echo "# $(which helm) version"
    helm version

    echo "#==[ Command ]======================================#"
    echo "# $(which helm) get hooks trento-server"
    helm get hooks trento-server
    
    echo "#==[ Command ]======================================#"
    echo "# $(which helm) get manifest trento-server"
    helm get manifest trento-server | yq -n '[inputs]' | jq 'walk(if type == "object" then del(.data.privatekey, .data."postgresql-password", .data."postgresql-postgres-password", .secretKeyRef, ."admin-user", ."admin-password", ."SMTP_PASSWORD", ."ADMIN_USER", ."ADMIN_PASSWORD", ."SECRET_KEY_BASE") else . end)'
    
    echo "#==[ Command ]======================================#"
    echo "# $(which helm) get notes trento-server"
    helm get notes trento-server
    
    echo "#==[ Command ]======================================#"
    echo "# $(which helm) get values trento-server"
    helm get values trento-server | yq 'del(."trento-runner".privateKey, ."trento-web".adminUser)'
} &> "$OUTPUT"

collect_kubernetes_state() {
    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) get nodes -o wide"
    kubectl get nodes -o wide

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) get pods"
    kubectl get pods

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) logs deploy/trento-server-runner"
    kubectl logs deploy/trento-server-runner

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) logs deploy/trento-server-web -c init"
    kubectl logs deploy/trento-server-web -c init

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) logs deploy/trento-server-web"
    kubectl logs deploy/trento-server-web

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) describe deployments" 
    kubectl describe deployments

    echo "#==[ Command ]======================================#"
    echo "# $(which crictl) images"
    crictl images
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
