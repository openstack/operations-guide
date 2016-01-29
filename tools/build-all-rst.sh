#!/bin/bash -e

mkdir -p publish-docs

doc-tools-build-rst doc/ops-guide --build build \
        --target draft/ops-guide
