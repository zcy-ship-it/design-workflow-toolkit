import { defineConfig } from "@playwright/test";
import { existsSync } from "node:fs";
const edge = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
export default defineConfig({
  testDir: "./tests",
  use: {
    baseURL: "http://127.0.0.1:8781",
    headless: true,
    launchOptions: existsSync(edge) ? { executablePath: edge } : {},
    screenshot: "only-on-failure",
  },
  webServer: {
    command: "pnpm dev --port 8781 --strictPort",
    url: "http://127.0.0.1:8781",
    reuseExistingServer: false,
  },
});
