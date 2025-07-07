<script>
  export let error;
  export let updating;
  export let onRetry;
  export let showErrorDetails = false;
  export let onToggleErrorDetails;
</script>

{#if error}
  <div class="mb-4 bg-red-50 border border-red-200 rounded-lg p-3 sm:p-4">
    <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
      <div class="flex items-start space-x-3">
        <svg class="w-5 h-5 text-red-400 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <div class="flex-1">
          <h3 class="text-sm font-medium text-red-800">
            {error.isInitialLoad ? 'Kunde inte ladda data' : 'Uppdatering misslyckades'}
          </h3>
          <p class="text-sm text-red-700 mt-1">
            {error.isInitialLoad ? 'Ingen data kunde laddas från servern.' : 'Kunde inte uppdatera data från servern.'}
          </p>
          {#if showErrorDetails}
            <div class="mt-2 p-2 bg-red-100 rounded text-xs font-mono text-red-800 break-words">
              {error.message}
            </div>
          {/if}
        </div>
      </div>
      <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 sm:space-x-2">
        <button 
          on:click={onToggleErrorDetails}
          class="text-sm text-red-600 hover:text-red-800 underline text-center"
        >
          {showErrorDetails ? 'Dölj' : 'Visa'} detaljer
        </button>
        <button 
          on:click={onRetry}
          disabled={updating}
          class="px-3 py-2 text-sm bg-red-600 text-white rounded hover:bg-red-700 disabled:bg-red-400 disabled:cursor-not-allowed transition-colors"
        >
          {updating ? 'Försöker...' : 'Försök igen'}
        </button>
      </div>
    </div>
  </div>
{/if} 