<script lang="ts">
  import MachineCard from './MachineCard.svelte';
  import { wasRecentlyUsed } from './timerUtils';
  
  let { group, expanded, currentTime, toggle } = $props();

  const availableCount = $derived(group.machines.filter((m: any) => m.state === 'available').length);
  const recentlyUsedCount = $derived(
    group.machines.filter((m: any) => m.state === 'available' && wasRecentlyUsed(m.status, currentTime)).length
  );
</script>

<div class="bg-white shadow rounded-xl sm:rounded-2xl overflow-hidden">
  <button 
    class="w-full flex justify-between items-center p-3 sm:p-4 bg-gray-50 hover:bg-gray-100 transition-colors text-left"
    onclick={toggle}
    aria-expanded={expanded}
    aria-controls="group-{group.name}"
  >
    <div class="flex items-center space-x-2 sm:space-x-3 min-w-0 flex-1">
      <span class="text-base sm:text-lg font-semibold truncate">{group.name}</span>
      <span class="px-2 py-1 text-xs bg-gray-200 rounded-full flex-shrink-0">
        {group.machines.length} maskiner
      </span>
    </div>
    <div class="flex items-center space-x-2 flex-shrink-0">
      <span class="text-sm text-gray-500 hidden sm:block">
        {availableCount} lediga{recentlyUsedCount > 0 ? ` (${recentlyUsedCount} nyligen använda)` : ''}
      </span>
      <svg 
        class="w-5 h-5 transform transition-transform {expanded ? 'rotate-180' : ''}" 
        fill="none" 
        stroke="currentColor" 
        viewBox="0 0 24 24"
        aria-hidden="true"
      >
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
      </svg>
    </div>
  </button>
  
  {#if expanded}
    <div id="group-{group.name}" class="p-3 sm:p-4">
      <!-- Mobile: Show available count -->
      <div class="sm:hidden mb-3 text-sm text-gray-600">
        {availableCount} lediga maskiner{recentlyUsedCount > 0 ? ` (${recentlyUsedCount} nyligen använda)` : ''}
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 sm:gap-4">
        {#each group.machines as machine}
          <MachineCard {machine} {currentTime} />
        {/each}
      </div>
    </div>
  {/if}
</div> 