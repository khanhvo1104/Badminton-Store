import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const redirect = vi.hoisted(() => vi.fn());
const createSupabaseServerClient = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
}));

vi.mock("@/lib/env/public-env", () => ({
  getPublicEnvironment: () => ({
    supabaseUrl: "https://demo-project.supabase.co",
    supabasePublishableKey: "public-demo-key",
  }),
}));

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

vi.mock("@/features/auth/actions/update-password", () => ({
  updatePassword: vi.fn(),
}));

vi.mock("react", async () => {
  const actual = await vi.importActual<typeof import("react")>("react");

  return {
    ...actual,
    useActionState: () => [{ errorMessage: null }, vi.fn()],
  };
});

vi.mock("react-dom", async () => {
  const actual = await vi.importActual<typeof import("react-dom")>("react-dom");

  return {
    ...actual,
    useFormStatus: () => ({ pending: false }),
  };
});

describe("UpdatePasswordPage", () => {
  it("redirects when a verified recovery session is missing", async () => {
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: { claims: { sub: "user-1", amr: [{ method: "password" }] } },
          error: null,
        }),
      },
    });
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });

    const { default: UpdatePasswordPage } = await import(
      "@/app/update-password/page"
    );

    await expect(UpdatePasswordPage()).rejects.toThrow(
      "NEXT_REDIRECT:/login?status=recovery-failed",
    );
    expect(redirect).toHaveBeenCalledWith("/login?status=recovery-failed");
  });

  it("renders the password form for a verified recovery session", async () => {
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: {
            claims: {
              sub: "user-1",
              amr: [{ method: "recovery", timestamp: 1 }],
            },
          },
          error: null,
        }),
      },
    });

    const { default: UpdatePasswordPage } = await import(
      "@/app/update-password/page"
    );

    render(await UpdatePasswordPage());

    expect(
      screen.getByRole("heading", { name: "Choose a new password" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("New password")).toBeInTheDocument();
    expect(screen.getByLabelText("Confirm password")).toBeInTheDocument();
    expect(
      screen.getByText(/does not open the CMS dashboard/i),
    ).toBeInTheDocument();
  });
});
