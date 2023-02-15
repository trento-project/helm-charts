#!/bin/bash

set -e

readonly ARGS=("$@")
declare -A VALID_FACILITIES=(
    ["configuration"]="configuration"
    ["base"]="base"
    ["kubernetes"]="kubernetes"
    ["all"]="all"
)

INSTALLATION_NAME="trento-server"
OUTPUT=/dev/stdout

indent() { sed 's/^/  /'; }

collect_trento_configuration() {
    echo "#==[ Configuration File ]===========================#"
    echo "# /etc/trento/installer.conf"
    echo "$(</etc/trento/installer.conf)"
} &> "$OUTPUT"

collect_base_system() {
    if [ "$COLLECT_K3S" != "false" ]; then
        echo "#==[ Command ]======================================#"
        echo "# k3s --version"
        k3s --version
    fi

    echo "#==[ Command ]======================================#"
    echo "# $(which helm) version"
    helm version

    echo "#==[ Command ]======================================#"
    echo "# $(which helm) get hooks $INSTALLATION_NAME"
    helm get hooks $INSTALLATION_NAME

    echo "#==[ Command ]======================================#"
    echo "# $(which helm) get manifest $INSTALLATION_NAME"
    helm get manifest $INSTALLATION_NAME | yq -n '[inputs]' | jq 'walk(if type == "object" then del(.data."postgresql-password", .data."postgresql-postgres-password", .secretKeyRef, ."admin-user", ."admin-password", ."SMTP_PASSWORD", ."ADMIN_USER", ."ADMIN_PASSWORD", ."SECRET_KEY_BASE", ."ACCESS_TOKEN_ENC_SECRET", ."REFRESH_TOKEN_ENC_SECRET") else . end)'

    echo "#==[ Command ]======================================#"
    echo "# $(which helm) get notes $INSTALLATION_NAME"
    helm get notes $INSTALLATION_NAME

    echo "#==[ Command ]======================================#"
    echo "# $(which helm) get values $INSTALLATION_NAME"
    helm get values $INSTALLATION_NAME | yq 'del(."trento-web".adminUser)'
} &> "$OUTPUT"

collect_kubernetes_state() {
    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) get nodes -o wide"
    kubectl get nodes -o wide

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) get pods"
    kubectl get pods

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) logs deploy/$INSTALLATION_NAME-wanda -c init"
    kubectl logs deploy/$INSTALLATION_NAME-wanda -c init

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) logs deploy/$INSTALLATION_NAME-wanda"
    kubectl logs deploy/$INSTALLATION_NAME-wanda

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) logs deploy/$INSTALLATION_NAME-web -c init"
    kubectl logs deploy/$INSTALLATION_NAME-web -c init

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) logs deploy/$INSTALLATION_NAME-web"
    kubectl logs deploy/$INSTALLATION_NAME-web

    echo "#==[ Command ]======================================#"
    echo "# $(which kubectl) describe deployments"
    kubectl describe deployments

    if [ "$COLLECT_CRICTL" != "false" ]; then
        echo "#==[ Command ]======================================#"
        echo "# $(which crictl) images"
        crictl images
    fi
} &> "$OUTPUT"

collect_all() {
    collect_trento_configuration || echo "Error $? during 'configuration' collection"
    collect_base_system || echo "Error $? during 'base' collection"
    collect_kubernetes_state || echo "Error $? during 'kubernetes' collection"
}

generate_output() {
    if [[ " ${arr[*]} " =~ "all" ]]; then
        collect_all
    else
      if [[ " ${arr[*]} " =~ "configuration" ]]; then
        collect_trento_configuration
      fi

      if [[ " ${arr[*]} " =~ "base" ]]; then
        collect_base_system
      fi

      if [[ " ${arr[*]} " =~ "kubernetes" ]]; then
        collect_kubernetes_state
      fi
    fi

    if [[ -n "$COMPRESS" ]]; then
        echo "COMPRESSING OUTPUT"
        tar -czf "$OUTPUT.tar.gz" "$OUTPUT"
        rm -f "$OUTPUT"
    fi
}

usage() {
    cat <<-EOF
    Usage: $0 options

    Run Trento Server supportconfig script

    Options:
        -o, --output   Output type. Options: stdout|file|file-tgz
        -c, --collect  Collection options: configuration|base|kubernetes|all
        -n, --name     Name of the installation. "trento-server" by default.
        -h, --help

    Example:
        $0 --output stdout --collect all

EOF
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
        --name) args="${args}-n " ;;

        *)
            [[ "${arg:0:1}" == "-" ]] || delim="\""
            args="${args}${delim}${arg}${delim} "
            ;;
        esac
    done

    eval set -- "$args"

    while getopts "ho:c:n:" OPTION; do
        case $OPTION in
        h)
            usage
            exit 0
            ;;

        o)
            OUTPUT_OPT="${OPTARG}"
            if [[ ${OUTPUT_OPT} != "stdout" && ${OUTPUT_OPT} != "file" && ${OUTPUT_OPT} != "file-tgz" ]]; then
                echo "Invalid output type: $OUTPUT_OPT"
                usage
                exit 1
            fi

            if [ "${OUTPUT_OPT}" = "stdout" ]; then
                OUTPUT="/dev/stdout"
            elif [ "${OUTPUT_OPT}" = "file-tgz" ]; then
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

        n)
            INSTALLATION_NAME=$OPTARG
            ;;

        *)
            usage
            exit 0
            ;;
        esac
    done

    return 0
}

check_deps() {
    if ! which jq >/dev/null 2>&1; then
        echo "error: jq is required and not installed"
        exit 1
    fi
    if ! which yq >/dev/null 2>&1; then
        echo "error: yq is required and not installed"
        exit 1
    fi
    if ! which helm >/dev/null 2>&1; then
        echo "error: helm is required and not installed"
        exit 1
    fi
    if ! which kubectl >/dev/null 2>&1; then
        echo "error: kubectl is required and not installed"
        exit 1
    fi
    if ! which crictl >/dev/null 2>&1; then
        COLLECT_CRICTL=false
    fi
    if ! which k3s >/dev/null 2>&1; then
        COLLECT_K3S=false
    fi
}

check_deps
cmdline "${ARGS[@]}"
generate_output
