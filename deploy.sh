#!/bin/bash
# ======================================================
# 🚀 Deploy Script - Seba DevOps Tools (Astro + GitHub Pages)
# ======================================================

set -e  # Detiene la ejecución ante cualquier error

echo "🧩 Construyendo sitio con Astro..."
npm run build

echo "🚀 Publicando en rama gh-pages..."
# Crear (o moverse a) la rama de deploy
git checkout gh-pages

# Borrar archivos antiguos
git rm -rf . > /dev/null 2>&1 || true
rm -rf *

# Copiar el contenido compilado desde dist/
cp -r dist/* .

# Subir a GitHub
git add .
git commit -m "Deploy automático desde deploy.sh"
git push origin gh-pages --force

# Volver a main al finalizar
git checkout main

echo "✅ Deploy completo."
echo "🌐 Sitio en: https://sebafa.github.io/Seba-DevOps-Tools/"

