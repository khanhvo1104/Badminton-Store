import { CmsLandingShell } from "@/features/landing/components/cms-landing-shell";
import { getPublicEnvironment } from "@/lib/env/public-env";

export default function Home() {
  getPublicEnvironment();

  return <CmsLandingShell />;
}
