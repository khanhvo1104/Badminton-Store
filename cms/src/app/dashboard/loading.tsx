import { LoadingState } from "@/components/ui/loading-state";

export default function DashboardLoading() {
  return (
    <div className="mx-auto max-w-5xl">
      <LoadingState label="Loading dashboard content" />
    </div>
  );
}
