# Rebuild fmwk.
rebuild:
    sudo nixos-rebuild switch --flake .#fmwk

# Deploy
deploy output:
    nixos-rebuild switch --fast --flake .#{{output}} --target-host nixlab --build-host nixlab --use-remote-sudo
