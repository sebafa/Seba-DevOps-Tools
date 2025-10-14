import { defineConfig } from 'astro/config';
import tailwind from "@astrojs/tailwind";

export default defineConfig({
  base: '/Seba-DevOps-Tools/',   // 👈 importante para GitHub Pages
  integrations: [tailwind()],
});
