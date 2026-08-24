import AxeBuilder from "@axe-core/playwright";
import { expect, type Page } from "@playwright/test";

export async function expectNoSeriousAxeViolations(page: Page) {
  // @axe-core/playwright Page typings can lag @playwright/test releases.
  const results = await new AxeBuilder({ page: page as never })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();

  const seriousOrCritical = results.violations.filter(
    (violation) =>
      violation.impact === "serious" || violation.impact === "critical",
  );

  expect(
    seriousOrCritical,
    seriousOrCritical
      .map(
        (violation) =>
          `${violation.id} (${violation.impact}): ${violation.help}\n` +
          violation.nodes
            .map(
              (node) =>
                `  - ${node.target.join(", ")} | ${node.failureSummary ?? ""}`,
            )
            .join("\n"),
      )
      .join("\n"),
  ).toEqual([]);
}
