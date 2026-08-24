/**
 * Deterministic CMS smoke-check helpers (network injectable).
 */

export const DEFAULT_TIMEOUT_MS = 3_000;
export const DEFAULT_RETRIES = 1;
export const MAX_RETRIES = 2;
export const MAX_TIMEOUT_MS = 10_000;

const FORBIDDEN_RESPONSE_PATTERN =
  /password|service_role|authorization|cookie|postgres:\/\/|BEGIN [A-Z ]*PRIVATE KEY|\/Users\/|\/home\/|node_modules|eyJ[A-Za-z0-9_-]{10,}\./i;

/**
 * @typedef {{
 *   baseUrl: string,
 *   allowLocalhost?: boolean,
 *   timeoutMs?: number,
 *   retries?: number,
 *   fetchImpl?: typeof fetch,
 * }} SmokeCheckOptions
 */

/**
 * @typedef {{
 *   ok: boolean,
 *   exitCode: number,
 *   message: string,
 *   livenessStatus?: number,
 *   readinessStatus?: number,
 * }} SmokeCheckResult
 */

/**
 * @param {string[]} argv
 * @param {{ fetchImpl?: typeof fetch, write?: (line: string) => void }} [io]
 */
export async function smokeCheckMain(argv, io = {}) {
  const write = io.write ?? ((line) => console.error(line));

  try {
    const options = parseSmokeCheckArgs(argv);
    const result = await runSmokeCheck({
      ...options,
      fetchImpl: io.fetchImpl ?? fetch,
    });
    write(result.message);
    return result.exitCode;
  } catch (error) {
    write(sanitizeSmokeMessage(error));
    return 2;
  }
}

/**
 * @param {string[]} argv
 */
export function parseSmokeCheckArgs(argv) {
  /** @type {Record<string, string | boolean>} */
  const flags = {};

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--allow-localhost") {
      flags.allowLocalhost = true;
      continue;
    }
    if (arg === "--base-url" || arg === "--timeout-ms" || arg === "--retries") {
      const value = argv[i + 1];
      if (!value || value.startsWith("--")) {
        throw new Error(`Missing value for ${arg}.`);
      }
      flags[arg.slice(2)] = value;
      i += 1;
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      flags.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (flags.help) {
    throw new Error(
      "Usage: smoke-check --base-url <url> [--allow-localhost] [--timeout-ms 3000] [--retries 1]",
    );
  }

  if (typeof flags["base-url"] !== "string" || !flags["base-url"]) {
    throw new Error("Missing required --base-url.");
  }

  const timeoutMs = flags["timeout-ms"]
    ? Number.parseInt(String(flags["timeout-ms"]), 10)
    : DEFAULT_TIMEOUT_MS;
  const retries = flags.retries
    ? Number.parseInt(String(flags.retries), 10)
    : DEFAULT_RETRIES;

  if (
    !Number.isFinite(timeoutMs) ||
    timeoutMs <= 0 ||
    timeoutMs > MAX_TIMEOUT_MS
  ) {
    throw new Error(`--timeout-ms must be between 1 and ${MAX_TIMEOUT_MS}.`);
  }
  if (!Number.isInteger(retries) || retries < 0 || retries > MAX_RETRIES) {
    throw new Error(
      `--retries must be an integer between 0 and ${MAX_RETRIES}.`,
    );
  }

  return {
    baseUrl: String(flags["base-url"]),
    allowLocalhost: Boolean(flags.allowLocalhost),
    timeoutMs,
    retries,
  };
}

/**
 * @param {SmokeCheckOptions} options
 * @returns {Promise<SmokeCheckResult>}
 */
export async function runSmokeCheck(options) {
  const base = validateBaseUrl(
    options.baseUrl,
    options.allowLocalhost === true,
  );
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const retries = options.retries ?? DEFAULT_RETRIES;
  const fetchImpl = options.fetchImpl ?? fetch;

  const liveness = await fetchHealthContract({
    fetchImpl,
    url: new URL("/api/health", base),
    expectedCheck: "liveness",
    timeoutMs,
    retries,
  });

  if (!liveness.ok) {
    return {
      ok: false,
      exitCode: 1,
      message: sanitizeSmokeMessage(liveness.error ?? "Liveness check failed."),
      livenessStatus: liveness.status,
    };
  }

  const readiness = await fetchHealthContract({
    fetchImpl,
    url: new URL("/api/ready", base),
    expectedCheck: "readiness",
    timeoutMs,
    retries,
    allowServiceUnavailable: true,
  });

  if (!readiness.ok) {
    return {
      ok: false,
      exitCode: 1,
      message: sanitizeSmokeMessage(
        readiness.error ?? "Readiness check failed.",
      ),
      livenessStatus: liveness.status,
      readinessStatus: readiness.status,
    };
  }

  if (readiness.body?.status !== "ok") {
    return {
      ok: false,
      exitCode: 1,
      message: "Readiness reported dependency failure.",
      livenessStatus: liveness.status,
      readinessStatus: readiness.status,
    };
  }

  return {
    ok: true,
    exitCode: 0,
    message: "CMS smoke check passed.",
    livenessStatus: liveness.status,
    readinessStatus: readiness.status,
  };
}

/**
 * @param {string} raw
 * @param {boolean} allowLocalhost
 */
export function validateBaseUrl(raw, allowLocalhost) {
  let url;
  try {
    url = new URL(raw);
  } catch {
    throw new Error("Invalid --base-url.");
  }

  const host = url.hostname.toLowerCase();
  const isLocal =
    host === "localhost" ||
    host === "127.0.0.1" ||
    host === "[::1]" ||
    host === "::1";

  if (url.protocol === "https:") {
    return url;
  }

  if (url.protocol === "http:" && isLocal && allowLocalhost) {
    return url;
  }

  if (url.protocol === "http:" && isLocal && !allowLocalhost) {
    throw new Error("Localhost HTTP requires --allow-localhost.");
  }

  throw new Error(
    "Only https URLs are allowed unless --allow-localhost is set.",
  );
}

/**
 * @param {{
 *   fetchImpl: typeof fetch,
 *   url: URL,
 *   expectedCheck: "liveness" | "readiness",
 *   timeoutMs: number,
 *   retries: number,
 *   allowServiceUnavailable?: boolean,
 * }} input
 */
async function fetchHealthContract(input) {
  let attempt = 0;
  let lastError = "Request failed.";
  let lastStatus;

  while (attempt <= input.retries) {
    attempt += 1;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), input.timeoutMs);

    try {
      const response = await input.fetchImpl(input.url, {
        method: "GET",
        redirect: "error",
        signal: controller.signal,
        headers: {
          Accept: "application/json",
        },
      });
      lastStatus = response.status;

      const contentType = response.headers.get("content-type") ?? "";
      if (!contentType.toLowerCase().includes("application/json")) {
        return {
          ok: false,
          status: response.status,
          error: "Unexpected content type from health endpoint.",
        };
      }

      if (
        response.status === 200 ||
        (input.allowServiceUnavailable && response.status === 503)
      ) {
        const body = await response.json();
        const validationError = validateHealthBody(body, input.expectedCheck);
        if (validationError) {
          return {
            ok: false,
            status: response.status,
            error: validationError,
            body,
          };
        }
        return { ok: true, status: response.status, body };
      }

      lastError = `Unexpected status ${response.status}.`;
    } catch (error) {
      if (isRedirectError(error)) {
        return {
          ok: false,
          status: lastStatus,
          error: "Redirects are not allowed for smoke checks.",
        };
      }
      if (isAbortError(error)) {
        lastError = "Request timed out.";
      } else {
        lastError = "Network request failed.";
      }
    } finally {
      clearTimeout(timer);
    }
  }

  return { ok: false, status: lastStatus, error: lastError };
}

/**
 * @param {unknown} body
 * @param {"liveness" | "readiness"} expectedCheck
 */
export function validateHealthBody(body, expectedCheck) {
  if (!body || typeof body !== "object") {
    return "Health response was not a JSON object.";
  }

  const serialized = JSON.stringify(body);
  if (FORBIDDEN_RESPONSE_PATTERN.test(serialized)) {
    return "Health response contained forbidden content.";
  }

  const record = /** @type {Record<string, unknown>} */ (body);
  if (record.check !== expectedCheck) {
    return "Health response check field mismatch.";
  }
  if (record.status !== "ok" && record.status !== "error") {
    return "Health response status field invalid.";
  }

  if (expectedCheck === "readiness") {
    if (record.dependency !== "supabase") {
      return "Readiness dependency field invalid.";
    }
    const allowed = new Set([
      "ok",
      "misconfigured",
      "timeout",
      "unreachable",
      "error",
    ]);
    if (!allowed.has(String(record.dependencyStatus))) {
      return "Readiness dependencyStatus invalid.";
    }
  }

  return null;
}

/**
 * @param {unknown} error
 */
export function sanitizeSmokeMessage(error) {
  const raw =
    typeof error === "string"
      ? error
      : error instanceof Error
        ? error.message
        : "Smoke check failed.";

  if (FORBIDDEN_RESPONSE_PATTERN.test(raw)) {
    return "Smoke check failed.";
  }

  // Keep messages short and free of URLs with credentials.
  return (
    raw.replace(/[^\x20-\x7E]/g, "").slice(0, 200) || "Smoke check failed."
  );
}

/**
 * @param {unknown} error
 */
function isAbortError(error) {
  return (
    !!error &&
    typeof error === "object" &&
    "name" in error &&
    /** @type {{name?: string}} */ (
      error.name === "AbortError" ||
        /** @type {{name?: string}} */ (error).name === "TimeoutError"
    )
  );
}

/**
 * @param {unknown} error
 */
function isRedirectError(error) {
  const message =
    error instanceof Error
      ? error.message
      : typeof error === "string"
        ? error
        : "";
  return /redirect/i.test(message);
}
