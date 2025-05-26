#!/usr/bin/env bash
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script

curl -fsSL https://get.docker.com -o get-docker.sh
sudo -E sh get-docker.sh
sudo usermod -aG docker $USER
