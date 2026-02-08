<script lang="ts">
	import MachineCard from './MachineCard.svelte';
	import { wasRecentlyUsed } from './timerUtils';

	let { group, expanded, currentTime, toggle } = $props();

	const availableCount = $derived(
		group.machines.filter((m: any) => m.state === 'available').length
	);
	const recentlyUsedCount = $derived(
		group.machines.filter(
			(m: any) => m.state === 'available' && wasRecentlyUsed(m.status, currentTime)
		).length
	);
</script>

<div
	class="overflow-hidden rounded-xl bg-white shadow transition-colors sm:rounded-2xl dark:bg-gray-800"
>
	<button
		class="flex w-full items-center justify-between bg-gray-50 p-3 text-left transition-colors hover:bg-gray-100 sm:p-4 dark:bg-gray-700 dark:hover:bg-gray-600"
		onclick={toggle}
		aria-expanded={expanded}
		aria-controls="group-{group.name}"
	>
		<div class="flex min-w-0 flex-1 items-center space-x-2 sm:space-x-3">
			<span class="truncate text-base font-semibold text-gray-900 sm:text-lg dark:text-gray-100"
				>{group.name}</span
			>
			<span
				class="flex-shrink-0 rounded-full bg-gray-200 px-2 py-1 text-xs text-gray-700 dark:bg-gray-600 dark:text-gray-300"
			>
				{group.machines.length} maskiner
			</span>
		</div>
		<div class="flex flex-shrink-0 items-center space-x-2">
			<span class="hidden text-sm text-gray-500 sm:block dark:text-gray-400">
				{availableCount} lediga{recentlyUsedCount > 0
					? ` (${recentlyUsedCount} nyligen använda)`
					: ''}
			</span>
			<svg
				class="h-5 w-5 transform text-gray-600 transition-transform dark:text-gray-400 {expanded
					? 'rotate-180'
					: ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
				aria-hidden="true"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"
				></path>
			</svg>
		</div>
	</button>

	{#if expanded}
		<div id="group-{group.name}" class="bg-white p-3 sm:p-4 dark:bg-gray-800">
			<!-- Mobile: Show available count -->
			<div class="mb-3 text-sm text-gray-600 sm:hidden dark:text-gray-400">
				{availableCount} lediga maskiner{recentlyUsedCount > 0
					? ` (${recentlyUsedCount} nyligen använda)`
					: ''}
			</div>

			<div class="grid grid-cols-1 gap-3 sm:gap-4 md:grid-cols-2">
				{#each group.machines as machine}
					<MachineCard {machine} {currentTime} />
				{/each}
			</div>
		</div>
	{/if}
</div>
