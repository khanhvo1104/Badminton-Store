import {
  getPublicEnvironment,
  type PublicEnvironment,
} from "@/lib/env/public-env";
import { isPublicEnvironmentError } from "@/lib/errors/public-environment-error";
import {
  DEFAULT_READINESS_TIMEOUT_MS,
  type ReadinessCheckState,
} from "@/lib/ops/health-contract";
import { sanitizeOperationalErrorCode } from "@/lib/ops/operational-log";

export type ReadinessDependencyChecker = (input: {
  environment: PublicEnvironment;
  timeoutMs: number;
  signal: AbortSignal;
}) => Promise<void>;

export type EvaluateReadinessOptions = {
  timeoutMs?: number;
  getEnvironment?: () => PublicEnvironment;
  checkDependency?: ReadinessDependencyChecker;
  now?: () => number;
};

export type ReadinessEvaluation = {
  dependencyStatus: ReadinessCheckState;
  durationMs: number;
};

/**
 * Evaluates CMS dependency readiness with a bounded timeout.
 * Never returns environment values, SQL, or provider error details.
 */
export async function evaluateReadiness(
  options: EvaluateReadinessOptions = {},
): Promise<ReadinessEvaluation> {
  const timeoutMs = options.timeoutMs ?? DEFAULT_READINESS_TIMEOUT_MS;
  const getEnvironment = options.getEnvironment ?? getPublicEnvironment;
  const checkDependency =
    options.checkDependency ?? defaultSupabaseAuthHealthCheck;
  const now = options.now ?? (() => Date.now());
  const startedAt = now();

  let environment: PublicEnvironment;

  try {
    environment = getEnvironment();
  } catch (error) {
    if (isPublicEnvironmentError(error)) {
      return {
        dependencyStatus: "misconfigured",
        durationMs: elapsed(startedAt, now),
      };
    }

    return {
      dependencyStatus: "error",
      durationMs: elapsed(startedAt, now),
    };
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => {
    controller.abort();
  }, timeoutMs);

  try {
    await checkDependency({
      environment,
      timeoutMs,
      signal: controller.signal,
    });
    return {
      dependencyStatus: "ok",
      durationMs: elapsed(startedAt, now),
    };
  } catch (error) {
    return {
      dependencyStatus: mapDependencyFailure(error),
      durationMs: elapsed(startedAt, now),
    };
  } finally {
    clearTimeout(timeout);
  }
}

export async function defaultSupabaseAuthHealthCheck(input: {
  environment: PublicEnvironment;
  signal: AbortSignal;
}): Promise<void> {
  const healthUrl = new URL("/auth/v1/health", input.environment.supabaseUrl);
  let response: Response;

  try {
    response = await fetch(healthUrl, {
      method: "GET",
      headers: {
        Accept: "application/json",
        apikey: input.environment.supabasePublishableKey,
      },
      redirect: "error",
      signal: input.signal,
      cache: "no-store",
    });
  } catch (error) {
    if (isAbortError(error)) {
      const timeoutError = new Error("Readiness dependency timed out.");
      timeoutError.name = "TimeoutError";
      throw timeoutError;
    }
    throw error;
  }

  if (!response.ok) {
    const statusError = new Error("Readiness dependency returned an error.");
    statusError.name = "DependencyStatusError";
    throw statusError;
  }
}

function mapDependencyFailure(error: unknown): ReadinessCheckState {
  const code = sanitizeOperationalErrorCode(error);
  if (code === "timeout") {
    return "timeout";
  }
  if (code === "misconfigured") {
    return "misconfigured";
  }
  if (code === "unreachable") {
    return "unreachable";
  }
  return "error";
}

function isAbortError(error: unknown): boolean {
  return (
    !!error &&
    typeof error === "object" &&
    "name" in error &&
    (String((error as { name?: unknown }).name) === "AbortError" ||
      String((error as { name?: unknown }).name) === "TimeoutError")
  );
}

function elapsed(startedAt: number, now: () => number): number {
  return Math.max(0, now() - startedAt);
}
