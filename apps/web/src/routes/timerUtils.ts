// Parse completion time from status like "klar ca: 14:00"
export function parseCompletionTime(
  status: string | null | undefined
): Date | null {
  if (!status) return null;

  const match = status.match(/klar ca:\s*(\d{1,2}):(\d{2})/i);
  if (!match) return null;

  const hours = parseInt(match[1], 10);
  const minutes = parseInt(match[2], 10);

  // Create a date object for today with the specified time
  const completionTime = new Date();
  completionTime.setHours(hours, minutes, 0, 0);

  // If the time has already passed today, assume it's for tomorrow
  if (completionTime <= new Date()) {
    completionTime.setDate(completionTime.getDate() + 1);
  }

  return completionTime;
}

export function formatTimer(seconds: number): string {
  if (seconds < 60) {
    return `${seconds}s`;
  }
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  if (remainingSeconds === 0) {
    return `${minutes} min`;
  }
  return `${minutes} min ${remainingSeconds}s`;
}

export type MachineState =
  | "available"
  | "taken"
  | "not_bookable"
  | "recently_used";

export function getStateLabel(state: MachineState | string): string {
  switch (state) {
    case "available":
      return "Ledig";
    case "taken":
      return "Upptagen";
    case "not_bookable":
      return "Ej bokningsbar";
    case "recently_used":
      return "Nyligen använd";
    default:
      return "Okänd";
  }
}

export function getStateColor(state: MachineState | string): string {
  switch (state) {
    case "available":
      return "bg-green-500";
    case "taken":
      return "bg-yellow-500";
    case "not_bookable":
      return "bg-red-500";
    case "recently_used":
      return "bg-green-300";
    default:
      return "bg-gray-500";
  }
}

export function getBorderColor(state: MachineState | string): string {
  switch (state) {
    case "available":
      return "border-green-500";
    case "taken":
      return "border-yellow-500";
    case "not_bookable":
      return "border-red-500";
    case "recently_used":
      return "border-green-300";
    default:
      return "border-gray-500";
  }
}

// Check if a machine was recently used (completed within the last hour)
export function wasRecentlyUsed(
  status: string | null | undefined,
  currentTime: number
): boolean {
  if (!status) return false;

  // Look for "avslutades HH:MM" pattern
  const match = status.match(/avslutades\s*(\d{1,2}):(\d{2})/i);
  if (!match) return false;

  const hours = parseInt(match[1], 10);
  const minutes = parseInt(match[2], 10);

  // Create a date object for today with the completion time
  const completionTime = new Date();
  completionTime.setHours(hours, minutes, 0, 0);

  const now = new Date(currentTime);
  const diff = now.getTime() - completionTime.getTime();

  // Consider it recently used if it completed within the last hour (3600000 ms)
  return diff >= 0 && diff <= 3600000;
}
