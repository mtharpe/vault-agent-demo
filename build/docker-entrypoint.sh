#!/bin/ash

JWT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

echo_err() {
    echo -e "$(date) ERROR: ${1?}"
}

echo_info() {
    echo -e "$(date) INFO: ${1?}"
}

echo_warn() {
    echo -e "$(date) WARN: ${1?}"
}

get_secrets() {
while IFS= read -r secret
do
    val=${secret##*=}
    vaultPath=${val%%:*}
    localPath=${val##*:}
    echo_info "Injecting secret ${vaultPath?} to ${localPath?}"
    vault read -format=json ${vaultPath?} > ${localPath?}
    done <<- END
${SECRETS}
END
}

trap_sigterm() {
    echo_warn "Clean shutdown of Vault Agent.."
    exit 0
}

trap 'trap_sigterm' SIGINT SIGTERM

TOKEN=''
while [[ "${TOKEN}" == "" ]]
do
    echo_info "Attempting to receive login token from Vault.."
    TOKEN=$(vault write -field=token auth/kubernetes/login role=demo jwt=$JWT_TOKEN)
    if [[ ${TOKEN} == "" ]]
    then
        echo_warn "Could not receive token, trying again.."
        sleep 5
    fi
done

echo_info "Received login token, logging in"

vault login -no-print token=${TOKEN?}
if [[ $? -ne 0 ]]
then
    echo_err "Could not login, exiting.."
    exit 1
fi


echo_info "Login Successful!"

SECRETS=$(env | grep VAULT_SECRET)
while true
do
    echo_info "Retrieving secrets.."
    get_secrets
    sleep 5
done