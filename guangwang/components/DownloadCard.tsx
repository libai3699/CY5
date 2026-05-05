export interface DownloadCardProps {
  appName: string;
  version: string;
  downloadUrl: string;
  disabled: boolean;
  testId?: string;
  unavailableText: string;
  downloadText: string;
  unavailableLabel: string;
  downloadLabel: string;
}

export default function DownloadCard({
  appName,
  version,
  downloadUrl,
  disabled,
  testId,
  unavailableText,
  downloadText,
  unavailableLabel,
  downloadLabel,
}: DownloadCardProps) {
  return (
    <div className="glass-card flex flex-col items-center p-8 text-center transition-all duration-300 hover:-translate-y-1 hover:border-purple-500/30">
      <div className="mb-5 flex h-20 w-20 items-center justify-center rounded-3xl bg-gradient-to-br from-purple-600 to-blue-600 shadow-xl shadow-purple-500/30">
        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <circle cx="12" cy="12" r="10" fill="rgba(255,255,255,0.15)" />
          <circle cx="12" cy="12" r="4" fill="white" />
          <path d="M8 12l2 2 4-4" stroke="rgba(124,58,237,0.8)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>

      <h3 className="mb-2 text-xl font-bold text-white">{appName}</h3>

      {version ? (
        <span className="mb-6 inline-flex items-center rounded-full border border-purple-500/30 bg-purple-500/20 px-3 py-1 text-xs font-medium text-purple-300">
          v{version}
        </span>
      ) : (
        <div className="mb-6" />
      )}

      <div className="mb-6 flex items-center gap-2">
        <span className="inline-flex items-center gap-1.5 rounded-full border border-green-500/20 bg-green-500/10 px-3 py-1.5 text-xs font-medium text-green-400">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M17.523 15.341a.5.5 0 01-.5.5H6.977a.5.5 0 01-.5-.5V9.5a5.523 5.523 0 1111.046 0v5.841zM7.5 17.5h9v1a1 1 0 01-1 1h-7a1 1 0 01-1-1v-1zM9.5 3.5l-1.5-2M14.5 3.5l1.5-2" />
          </svg>
          Android APK
        </span>
      </div>

      {disabled ? (
        <button
          disabled
          data-testid={testId}
          className="btn-gradient flex min-h-[48px] w-full cursor-not-allowed items-center justify-center gap-2 rounded-full px-6 py-3.5 text-base font-semibold text-white opacity-50"
          aria-label={`${appName} ${unavailableLabel}`}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2" />
            <path d="M12 8v4M12 16h.01" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
          </svg>
          {unavailableText}
        </button>
      ) : (
        <a
          href={downloadUrl}
          download
          data-testid={testId}
          className="btn-gradient flex min-h-[48px] w-full items-center justify-center gap-2 rounded-full px-6 py-3.5 text-base font-semibold text-white shadow-lg shadow-purple-500/30"
          aria-label={`${downloadLabel} ${appName}`}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M12 16l-6-6h4V4h4v6h4l-6 6z" fill="currentColor" />
            <path d="M20 18H4v2h16v-2z" fill="currentColor" />
          </svg>
          {downloadText}
        </a>
      )}
    </div>
  );
}
