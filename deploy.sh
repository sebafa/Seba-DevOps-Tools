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
# 3️⃣ Verificar si Astro está instalado
# -----------------------------------------
if ! npx astro --version &>/dev/null; then
  echo "⚙️ Instalando Astro..."
  npm install astro @astrojs/tailwind tailwindcss
fi

# -----------------------------------------
# 4️⃣ Build del sitio con Astro
# -----------------------------------------
echo "🧩 Construyendo sitio con Astro..."
npm run build

# -----------------------------------------
# 5️⃣ Publicar en GitHub Pages
# -----------------------------------------
echo "🚀 Publicando en rama gh-pages..."

# Guardar temporalmente el build ANTES de cambiar de rama
if [ -d "dist" ]; then
  mv dist ../dist-temp
else
  echo "⚠️ No se encontró la carpeta dist. Abortando."
  exit 1
fi

# Cambiar directamente a gh-pages (crear si no existe)
if git show-ref --verify --quiet refs/heads/gh-pages; then
  git checkout gh-pages
else
  git checkout --orphan gh-pages
fi

# Limpiar archivos antiguos
git rm -rf . > /dev/null 2>&1 || true
rm -rf *

# Copiar el nuevo contenido compilado
cp -r ../dist-temp/* .

# Eliminar la carpeta temporal
rm -rf ../dist-temp

# Commit y push del nuevo contenido
git add .
git commit -m "Deploy automático desde deploy.sh" || echo "Nada para commitear"
git push origin gh-pages --force

# Guardar automáticamente los cambios en gh-pages antes de volver a main
git add .
git commit -m "Auto commit post-deploy" || echo "Nada para commitear"
git push origin gh-pages --force

# Volver a main
git checkout main

# -----------------------------------------
# 6️⃣ Mostrar tiempo total y abrir el sitio
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
