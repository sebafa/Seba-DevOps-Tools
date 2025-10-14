import { defineConfig } from 'astro/config';
import tailwind from "@astrojs/tailwind";

export default defineConfig({
  site: 'https://sebafa.github.io/Seba-DevOps-Tools/',
  base: '/Seba-DevOps-Tools/',
  integrations: [tailwind({
    config: {
      applyBaseStyles: true   // ⭐ fuerza los estilos base de Tailwind
    }
  })],
});
