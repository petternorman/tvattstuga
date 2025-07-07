<script>
  import { formatTimer } from './TimerUtils.ts';
  
  export let settingsOpen;
  export let updateInterval;
  export let intervalOptions;
  export let updating;
  export let updateTimer;
  export let lastUpdateTime;
  export let onUpdateInterval;
  export let onManualUpdate;
  export let onToggleSettings;
</script>

{#if settingsOpen}
  <div class="absolute right-0 top-12 w-64 sm:w-72 md:w-80 bg-white shadow-lg rounded-lg border p-3 sm:p-4 z-10 max-w-[calc(100vw-1rem)]">
    <h3 class="font-semibold text-gray-900 mb-3 text-sm sm:text-base">Inställningar</h3>
    
    <!-- Update Interval Selector -->
    <div class="mb-4">
      <label for="update-interval" class="block text-sm font-medium text-gray-700 mb-2">
        Uppdateringsintervall
      </label>
      <select 
        id="update-interval"
        bind:value={updateInterval}
        on:change={() => onUpdateInterval(updateInterval)}
        class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
      >
        {#each intervalOptions as option}
          <option value={option.value}>{option.label}</option>
        {/each}
      </select>
    </div>
    
    <!-- Manual Update Button -->
    <div class="mb-4">
      <button 
        on:click={onManualUpdate}
        disabled={updating}
        class="w-full px-4 py-2 rounded-md transition-colors flex items-center justify-center space-x-2 text-sm {updating ? 'bg-gray-400 cursor-not-allowed text-gray-600' : 'bg-blue-500 hover:bg-blue-600 text-white'}"
      >
        {#if updating}
          <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span>Uppdaterar...</span>
        {:else}
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
          <span>Uppdatera nu</span>
        {/if}
      </button>
    </div>
    
    <!-- Timer Display -->
    {#if updateInterval > 0}
      <div class="text-xs sm:text-sm text-gray-600 text-center">
        Nästa uppdatering om: {formatTimer(updateTimer)}
      </div>
    {:else}
      <div class="text-xs sm:text-sm text-gray-600 text-center">
        Automatisk uppdatering inaktiverad
      </div>
    {/if}
    
    <!-- Last Update Time -->
    <div class="text-xs text-gray-500 text-center mt-2">
      Senast uppdaterad: {new Date(lastUpdateTime).toLocaleTimeString('sv-SE')}
    </div>
  </div>
{/if}

<!-- Click outside to close settings -->
{#if settingsOpen}
  <div 
    class="fixed inset-0 z-0" 
    on:click={onToggleSettings}
    on:keydown={(e) => e.key === 'Escape' && onToggleSettings()}
    tabindex="-1"
    role="button"
    aria-label="Stäng inställningar"
  ></div>
{/if} 