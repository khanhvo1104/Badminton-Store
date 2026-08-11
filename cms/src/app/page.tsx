import { CmsLandingShell } from "@/features/landing/components/cms-landing-shell";
import { ConfigurationUnavailableShell } from "@/features/landing/components/configuration-unavailable-shell";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { isPublicEnvironmentError } from "@/lib/errors/public-environment-error";

export default function Home() {
  try {
    getPublicEnvironment();
  } catch (error) {
    if (isPublicEnvironmentError(error)) {
      return <ConfigurationUnavailableShell />;
    }

    throw error;
  }

  return <CmsLandingShell />;
}
