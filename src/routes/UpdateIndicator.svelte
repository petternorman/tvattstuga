<script>
  let { updating = false } = $props();
</script>

{#if updating}
  <div class="fixed top-2 right-2 sm:top-4 sm:right-4 bg-blue-500 text-white px-3 py-2 rounded-lg shadow-lg z-50 flex items-center space-x-2 max-w-xs">
    <svg class="animate-spin h-4 w-4 flex-shrink-0" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    <span class="text-sm font-medium">Uppdaterar...</span>
  </div>
{/if} 