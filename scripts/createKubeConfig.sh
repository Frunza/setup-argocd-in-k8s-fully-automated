#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e


# Create /infrastructure/.kube if it does not exist
mkdir -p /infrastructure/.kube

# Write contents of CLUSTER_KUBE_CONFIG to /infrastructure/.kube/config
echo "$CLUSTER_KUBE_CONFIG" > /infrastructure/.kube/config
