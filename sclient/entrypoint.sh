#!/bin/sh
set -e

K3D_SERVERLB="k3d-sni-test-serverlb."
K3S_NODEPORT=30888
SERVICE="echo-svc.echo.svc.cluster.local"
INGRESS_IP=$(nslookup -type=a "${K3D_SERVERLB}" | grep "Address" | grep -v ":53" | awk '{ print $2 }')

if [ -z ${INGRESS_IP} ]; then
    echo "Can't find IP for ${K3D_SERVERLB}. Did you run docker with the proper network set?" > /dev/stderr
    exit 1
fi

# append to /etc/hosts
echo "Updating /etc/hosts:"
for i in 0 1; do
    echo "${INGRESS_IP} echo-${i}.${SERVICE}" | tee -a /etc/hosts
done
echo "${INGRESS_IP} ${SERVICE}" | tee -a /etc/hosts
echo

# cheatsheet
echo "-----------------------------------------------------------------"
echo "You can now connect to one of the statefulset pods using openssl."
echo
echo "For example, to force connection to echo-1:"
echo
echo "# openssl s_client -servername echo-1.${SERVICE} ${SERVICE}:${K3S_NODEPORT}"
echo
echo "TODO: pull in the self-signed root CA for verification"
echo

# jump into a shell
exec /bin/sh -i
