#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e


sed -i "s/_GIT_USERNAME_/${GIT_USERNAME}/" ./resources/k8s/argo-values.yaml
echo "Replacement of GIT_USERNAME done"
sed -i "s/_GIT_PASSWORD_/${GIT_PASSWORD}/" ./resources/k8s/argo-values.yaml
echo "Replacement of GIT_PASSWORD done"
