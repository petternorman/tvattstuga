<script lang="ts">
	import { formatTimer } from './timerUtils.js';
	import { themeStore } from '$lib/theme.js';

	let {
		settingsOpen,
		updateInterval,
		intervalOptions,
		updating,
		updateTimer,
		lastUpdateTime,
		event,
		hasCredentials,
		savedUsername
	} = $props();

	let localInterval = $state(updateInterval);

	// Keep localInterval in sync with updateInterval prop
	$effect(() => {
		if (updateInterval !== localInterval) {
			localInterval = updateInterval;
		}
	});

	function handleIntervalChange(e: Event) {
		const target = e.target as HTMLSelectElement;
		const value = Number(target.value);
		localInterval = value;
		event('updateInterval', value);
	}

	function handleThemeChange(e: Event) {
		const target = e.target as HTMLSelectElement;
		const mode = target.value as 'light' | 'dark' | 'system';
		themeStore.setMode(mode);
	}

	const themeOptions = [
		{ value: 'system', label: 'System' },
		{ value: 'light', label: 'Light mode' },
		{ value: 'dark', label: 'Dark mode' }
	];
</script>

{#if settingsOpen}
	<div
		class="absolute top-12 right-0 z-10 w-64 max-w-[calc(100vw-1rem)] rounded-lg border border-gray-200 bg-white p-3 shadow-lg sm:w-72 sm:p-4 md:w-80 dark:border-gray-700 dark:bg-gray-800"
	>
		<h3 class="mb-3 text-sm font-semibold text-gray-900 sm:text-base dark:text-gray-100">
			Inställningar
		</h3>

		<!-- Login Info -->
		<div class="mb-4">
			<div class="mb-2 text-sm font-medium text-gray-700 dark:text-gray-300">Inloggning</div>
			{#if hasCredentials}
				<div class="mb-2 text-xs text-gray-600 dark:text-gray-400">
					Sparad användare: {savedUsername}
				</div>
				<div class="flex gap-2">
					<button
						onclick={() => event('openLogin')}
						class="flex-1 rounded-md bg-blue-500 px-3 py-2 text-xs text-white transition-colors hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700"
					>
						Byt inloggning
					</button>
					<button
						onclick={() => event('clearCredentials')}
						class="flex-1 rounded-md bg-gray-200 px-3 py-2 text-xs text-gray-800 transition-colors hover:bg-gray-300 dark:bg-gray-700 dark:text-gray-100 dark:hover:bg-gray-600"
					>
						Logga ut
					</button>
				</div>
			{:else}
				<button
					onclick={() => event('openLogin')}
					class="w-full rounded-md bg-blue-500 px-3 py-2 text-xs text-white transition-colors hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700"
				>
					Lägg till inloggning
				</button>
			{/if}
		</div>

		<!-- Theme Selector -->
		<div class="mb-4">
			<label
				for="theme-mode"
				class="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300"
			>
				Tema
			</label>
			<select
				id="theme-mode"
				value={$themeStore}
				onchange={handleThemeChange}
				class="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:ring-2 focus:ring-blue-500 focus:outline-none dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
			>
				{#each themeOptions as option}
					<option value={option.value}>{option.label}</option>
				{/each}
			</select>
		</div>

		<!-- Update Interval Selector -->
		<div class="mb-4">
			<label
				for="update-interval"
				class="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300"
			>
				Uppdateringsintervall
			</label>
			<select
				id="update-interval"
				value={localInterval}
				onchange={handleIntervalChange}
				class="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:ring-2 focus:ring-blue-500 focus:outline-none dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
			>
				{#each intervalOptions as option}
					<option value={option.value}>{option.label}</option>
				{/each}
			</select>
		</div>

		<!-- Manual Update Button -->
		<div class="mb-4">
			<button
				onclick={() => event('manualUpdate')}
				disabled={updating}
				class="flex w-full items-center justify-center space-x-2 rounded-md px-4 py-2 text-sm transition-colors {updating
					? 'cursor-not-allowed bg-gray-400 text-gray-600 dark:bg-gray-600 dark:text-gray-400'
					: 'bg-blue-500 text-white hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700'}"
			>
				{#if updating}
					<svg class="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"
						></circle>
						<path
							class="opacity-75"
							fill="currentColor"
							d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
						></path>
					</svg>
					<span>Uppdaterar...</span>
				{:else}
					<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							stroke-width="2"
							d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
						></path>
					</svg>
					<span>Uppdatera nu</span>
				{/if}
			</button>
		</div>

		<!-- Timer Display -->
		{#if updateInterval > 0}
			<div class="text-center text-xs text-gray-600 sm:text-sm dark:text-gray-400">
				Nästa uppdatering om: {formatTimer(updateTimer)}
			</div>
		{:else}
			<div class="text-center text-xs text-gray-600 sm:text-sm dark:text-gray-400">
				Automatisk uppdatering inaktiverad
			</div>
		{/if}

		<!-- Last Update Time -->
		<div class="mt-2 text-center text-xs text-gray-500 dark:text-gray-500">
			Senast uppdaterad: {new Date(lastUpdateTime).toLocaleTimeString('sv-SE')}
		</div>
	</div>
{/if}

<!-- Click outside to close settings -->
{#if settingsOpen}
	<div
		class="fixed inset-0 z-0"
		onclick={() => event('toggleSettings')}
		onkeydown={(e: KeyboardEvent) => e.key === 'Escape' && event('toggleSettings')}
		tabindex="-1"
		role="button"
		aria-label="Stäng inställningar"
	></div>
{/if}
