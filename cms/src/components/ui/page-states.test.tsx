import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useRef, useState } from "react";
import { describe, expect, it, vi } from "vitest";

import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { EmptyState } from "@/components/ui/empty-state";
import { ErrorState } from "@/components/ui/error-state";
import { LoadingState } from "@/components/ui/loading-state";

describe("page state primitives", () => {
  it("exposes an accessible loading status region", () => {
    render(<LoadingState label="Loading dashboard content" />);

    expect(
      screen.getByRole("status", { name: "Loading dashboard content" }),
    ).toHaveAttribute("aria-busy", "true");
  });

  it("renders an empty state with a labelled heading", () => {
    render(
      <EmptyState
        title="Nothing here yet"
        description="Catalog data arrives in a later task."
      />,
    );

    expect(
      screen.getByRole("heading", { name: "Nothing here yet" }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/catalog data arrives in a later task/i),
    ).toBeInTheDocument();
  });

  it("sanitizes errors and retries through the provided callback", () => {
    const onRetry = vi.fn();
    render(
      <ErrorState
        error={new Error("sql token secret=abc stack trace")}
        onRetry={onRetry}
      />,
    );

    expect(
      screen.getByRole("heading", { name: "Something went wrong" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByText(/sql|token|secret=abc|stack/i),
    ).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Try again" }));
    expect(onRetry).toHaveBeenCalledTimes(1);
  });
});

describe("ConfirmationDialog", () => {
  it("supports cancel, confirm, Escape, and focus return", async () => {
    const onConfirm = vi.fn();
    const onCancel = vi.fn();

    function Harness() {
      const triggerRef = useRef<HTMLButtonElement>(null);
      const [open, setOpen] = useState(false);

      return (
        <>
          <button ref={triggerRef} type="button" onClick={() => setOpen(true)}>
            Open dialog
          </button>
          <ConfirmationDialog
            open={open}
            title="Confirm archive"
            description="This confirmation stays local and does not call a backend."
            returnFocusRef={triggerRef}
            onConfirm={() => {
              onConfirm();
              setOpen(false);
            }}
            onCancel={() => {
              onCancel();
              setOpen(false);
            }}
          />
        </>
      );
    }

    render(<Harness />);

    const trigger = screen.getByRole("button", { name: "Open dialog" });
    fireEvent.click(trigger);

    const dialog = await screen.findByRole("dialog", {
      name: "Confirm archive",
    });
    expect(dialog).toBeInTheDocument();
    expect(screen.getByText(/does not call a backend/i)).toBeInTheDocument();

    await waitFor(() => {
      expect(document.activeElement).toBe(
        screen.getByRole("button", { name: "Cancel" }),
      );
    });

    fireEvent.click(screen.getByRole("button", { name: "Cancel" }));
    expect(onCancel).toHaveBeenCalledTimes(1);

    await waitFor(() => {
      expect(document.activeElement).toBe(trigger);
    });

    fireEvent.click(trigger);
    await screen.findByRole("dialog", { name: "Confirm archive" });
    fireEvent.click(screen.getByRole("button", { name: "Confirm" }));
    expect(onConfirm).toHaveBeenCalledTimes(1);

    fireEvent.click(trigger);
    const openDialog = await screen.findByRole("dialog", {
      name: "Confirm archive",
    });
    fireEvent(
      openDialog,
      new Event("cancel", { bubbles: true, cancelable: true }),
    );
    expect(onCancel).toHaveBeenCalledTimes(2);

    await waitFor(() => {
      expect(document.activeElement).toBe(trigger);
    });
  });
});
