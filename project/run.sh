#!/bin/bash
set -e

echo "Iniciando pipeline..."
Rscript src/main.R
echo "Pipeline finalizado."
