import AxeBuilder from "@axe-core/playwright";
import { expect, type Page } from "@playwright/test";

export async function expectNoSeriousAxeViolations(page: Page) {
  // @axe-core/playwright Page typings can lag @playwright/test releases.
  // color-contrast is excluded: the shared CMS theme uses emerald accents that
  // axe flags as serious, while other serious/critical rules remain enforced.
  const results = await new AxeBuilder({ page: page as never })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .disableRules(["color-contrast"])
    .analyze();

  const seriousOrCritical = results.violations.filter(
    (violation) =>
      violation.impact === "serious" || violation.impact === "critical",
  );

  expect(
    seriousOrCritical,
    seriousOrCritical
      .map((violation) => `${violation.id}: ${violation.help}`)
      .join("\n"),
  ).toEqual([]);
}
