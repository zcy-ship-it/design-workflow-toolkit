import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ViewSelector } from "./ViewSelector";
afterEach(cleanup);
describe("ViewSelector public interaction contract", () => {
  it("allows keyboard selection and reports the chosen view to its parent", async () => {
    const onChange = vi.fn();
    render(<ViewSelector value="front" onChange={onChange} />);
    const user = userEvent.setup();
    await user.tab();
    await user.tab();
    await user.keyboard("{Enter}");
    expect(onChange).toHaveBeenCalledWith("rear");
    expect(
      screen.getByRole("button", { name: "正面" }).getAttribute("aria-pressed"),
    ).toBe("true");
  });
  it("prevents a view change while conversion disables the controls", async () => {
    const onChange = vi.fn();
    render(<ViewSelector value="front" onChange={onChange} disabled />);
    await userEvent.setup().click(screen.getByRole("button", { name: "左侧" }));
    expect(onChange).not.toHaveBeenCalled();
  });
});
