#!/bin/bash
# ======================================================
# 🚀 Deploy Script - Seba DevOps Tools (Astro + GitHub Pages)
# ======================================================

set -e  # Detiene la ejecución ante cualquier error
start_time=$(date +%s)

# -----------------------------------------
# 1️⃣ Instalar dependencias si no existen
# -----------------------------------------
if [ ! -d "node_modules" ]; then
  echo "📦 Instalando dependencias..."
  npm install
fi

# -----------------------------------------
# 2️⃣ Commit automático previo al deploy
# -----------------------------------------
echo "💾 Guardando cambios locales (si hay)..."
git add .
git commit -m "Auto commit previo al deploy" || echo "No hay cambios nuevos para commitear"

# -----------------------------------------
# 3️⃣ Build del sitio con Astro
# -----------------------------------------
echo "🧩 Construyendo sitio con Astro..."
npm run build

# -----------------------------------------
# 4️⃣ Publicar en GitHub Pages
# -----------------------------------------
echo "🚀 Publicando en rama gh-pages..."

# Cambiar directamente a gh-pages
git checkout gh-pages

# Limpiar archivos antiguos
git rm -rf . > /dev/null 2>&1 || true
rm -rf *

# Copiar el nuevo contenido desde dist/
cp -r dist/* .

# Subir a GitHub
git add .
git commit -m "Deploy automático desde deploy.sh"
git push origin gh-pages --force

# Volver a main
git checkout main

# -----------------------------------------
# 5️⃣ Mostrar tiempo total y abrir el sitio
# -----------------------------------------
end_time=$(date +%s)
elapsed=$((end_time - start_time))
SITE_URL="https://sebafa.github.io/Seba-DevOps-Tools/"

echo "✅ Deploy completo en ${elapsed}s"
echo "🌐 Abriendo sitio en navegador: $SITE_URL"

# macOS usa 'open', Linux usa 'xdg-open'
if command -v open &> /dev/null; then
  open "$SITE_URL"
elif command -v xdg-open &> /dev/null; then
  xdg-open "$SITE_URL"
fi
