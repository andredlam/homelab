# Home Lab

Goal: Build a home datacenter with AI capable for learning and experiment

<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [Home Lab](#home-lab)
  - [Goals](#goals)
        - [Everything will be deployed with ansible](#everything-will-be-deployed-with-ansible)
  - [Prerequisites](#prerequisites)
    - [System Requirements](#system-requirements)
  - [Installation](#installation)
      - [Setup ansible](#setup-ansible)
        - [Generate ssh key](#generate-ssh-key)
        - [Directory Layout for referrence for ansible](#directory-layout-for-referrence-for-ansible)
      - [Setup k3s](#setup-k3s)
        - [Requirements](#requirements)

<!-- /code_chunk_output -->


## Goals

##### Everything will be deployed with ansible
- ansible
- docker

## Prerequisites

### System Requirements

-  Ubuntu 22.04
-  Make sure linux is reachable to outside
-  Make sure DNS is setup properly

## Installation

@import "docs/installation/index.md"
