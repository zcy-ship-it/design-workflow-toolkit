import { test, expect } from "@playwright/test";
test("view selection updates the parent state and respects busy status", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByRole("button", { name: "背面", exact: true }).click();
  await expect(page.getByRole("status")).toHaveText("当前视角：rear");
  await page.getByRole("checkbox").check();
  await expect(
    page.getByRole("button", { name: "顶面", exact: true }),
  ).toBeDisabled();
  await page.screenshot({ path: "test-results/组件演示.png", fullPage: true });
});
