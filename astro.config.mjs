import { defineConfig } from 'astro/config';
import tailwind from "@astrojs/tailwind";

export default defineConfig({
  site: 'https://sebafa.github.io/Seba-DevOps-Tools/', // 👈 importante
  base: '/Seba-DevOps-Tools/',                         // 👈 importantísimo
  integrations: [tailwind()],
});
