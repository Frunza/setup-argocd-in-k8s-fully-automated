#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

echo "Updating infrastructure..."
docker build -t terraform-cluster-argocd -f docker/dockerfile .
docker-compose -f docker/docker-compose.yml run --rm update

echo "Done"
