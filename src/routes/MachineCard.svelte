<script>
  import { parseCompletionTime, getStateLabel, getStateColor, getBorderColor, wasRecentlyUsed } from './timerUtils.js';
  
  export let machine;
  export let currentTime;

  // Declare effectiveState and determine the effective state considering recently used
  let effectiveState;
  $: effectiveState = machine.state === "available" && wasRecentlyUsed(machine.status, currentTime) 
    ? "recently_used" 
    : machine.state;
</script>

<div class="bg-gray-50 rounded-lg sm:rounded-xl p-3 sm:p-4 border-l-4 {getBorderColor(effectiveState)}">
  <div class="flex justify-between items-start mb-2 gap-2">
    <span class="font-medium text-gray-900 text-sm sm:text-base break-words">{machine.name}</span>
    <span class="px-2 py-1 text-xs text-white rounded-full {getStateColor(effectiveState)} flex-shrink-0">
      {getStateLabel(effectiveState)}
    </span>
  </div>
  <p class="text-sm text-gray-600 break-words">
    {(() => {
      const completionTime = parseCompletionTime(machine.status);
      if (!completionTime) {
        return machine.status || 'Ingen status';
      }
      // Explicitly reference currentTime to make it reactive
      const now = currentTime;
      const diff = completionTime.getTime() - now;
      
      if (diff <= 0) {
        return `${machine.status} (klar)`;
      }
      
      const totalSeconds = Math.floor(diff / 1000);
      const minutes = Math.floor(totalSeconds / 60);
      const seconds = totalSeconds % 60;
      
      let countdown;
      if (minutes < 60) {
        countdown = `(om ${minutes} min ${seconds}s)`;
      } else {
        const hours = Math.floor(minutes / 60);
        const remainingMinutes = minutes % 60;
        if (remainingMinutes === 0) {
          countdown = `(om ${hours} tim)`;
        } else {
          countdown = `(om ${hours} tim ${remainingMinutes} min)`;
        }
      }
      
      return `${machine.status} ${countdown}`;
    })()}
  </p>
</div> 