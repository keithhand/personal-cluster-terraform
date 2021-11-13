#!/bin/bash

# Wait for server to restart
_wait_for_server () {
    while ! echo exit | nc "$IP" 50000; do sleep 10; done
}
_wait_for_server

# Apply supplied configuration to server
talosctl apply-config --insecure --nodes "$IP" --file "$1"

# If supplied the BOOTSTRAP env, boostrap the cluster off this server
if [ "$BOOTSTRAP" == "true" ]; 
then
    # Run Bootstrap command
    _wait_for_server
    talosctl bootstrap --nodes "$IP" || true
    # Set kubeconfig and wait for nodes to respond
    talosctl kubeconfig --nodes "$IP" -f
    while ! echo exit | kubectl get nodes &> /dev/null; do sleep 10; done
fi
