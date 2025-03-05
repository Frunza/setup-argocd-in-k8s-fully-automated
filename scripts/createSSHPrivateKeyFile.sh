#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e


# Write contents of SSH_PRIVATE_KEY to /infrastructure/ssh-private-key.pem
echo "$SSH_PRIVATE_KEY" > /infrastructure/ssh-private-key.pem

# Add indentation (8 spaces) to each line after the first one; this is required because the private key must have indentation when injected into the argo config file
sed -i '2,$s/^/        /' /infrastructure/ssh-private-key.pem
