<script lang="ts">
	import Header from './Header.svelte';
	import SettingsPanel from './SettingsPanel.svelte';
	import ErrorBanner from './ErrorBanner.svelte';
	import LoadingIndicator from './LoadingIndicator.svelte';
	import UpdateIndicator from './UpdateIndicator.svelte';
	import MachineGroup from './MachineGroup.svelte';
	import NoDataState from './NoDataState.svelte';

	let data = $state<any[]>([]);
	let initialLoading = $state(true); // Only true on first load
	let updating = $state(false); // True during subsequent updates
	let error = $state<any>(null); // Store error information
	let showErrorDetails = $state(false); // Toggle for error details
	let expandedGroups = $state(new Set(['Tvätt Servicehus 2'])); // Default to show Servicehus 2
	let settingsOpen = $state(false);
	let updateInterval = $state(60000); // Default 1 minute
	let intervalId = $state<ReturnType<typeof setInterval> | null>(null);
	let lastUpdateTime = $state(Date.now());
	let updateTimer = $state(0);
	let currentTime = $state(Date.now()); // For countdown timers

	const intervalOptions = [
		{ value: 0, label: 'Av' },
		{ value: 30000, label: '30 sekunder' },
		{ value: 60000, label: '1 minut' },
		{ value: 300000, label: '5 minuter' },
		{ value: 600000, label: '10 minuter' }
	];

	async function load(isInitialLoad = false) {
		try {
			if (isInitialLoad) {
				initialLoading = true;
			} else {
				updating = true;
			}
			error = null; // Clear any previous errors

			const res = await fetch('/api/tvatt');
			if (!res.ok) {
				throw new Error(`HTTP ${res.status}: ${res.statusText}`);
			}
			const newData = await res.json();
			data = newData;
			lastUpdateTime = Date.now();
		} catch (err: any) {
			console.error('Error loading data:', err);
			error = {
				message: err.message,
				timestamp: Date.now(),
				isInitialLoad: isInitialLoad
			};
			// Only clear data if this is the initial load and we have no existing data
			if (isInitialLoad && data.length === 0) {
				data = [];
			}
		} finally {
			initialLoading = false;
			updating = false;
		}
	}

	function retry() {
		load(error?.isInitialLoad || false);
	}

	function toggleErrorDetails() {
		showErrorDetails = !showErrorDetails;
	}

	function updateIntervalSetting(newInterval: number) {
		// Clear existing interval
		if (intervalId) {
			clearInterval(intervalId);
			intervalId = null;
		}

		// Only update if different to avoid unnecessary reactivity
		if (updateInterval !== newInterval) {
			updateInterval = newInterval;
		}

		// Set new interval if not 0
		if (newInterval > 0) {
			intervalId = setInterval(() => load(false), newInterval);
		}
	}

	function toggleSettings() {
		settingsOpen = !settingsOpen;
	}

	function toggleGroup(groupName: string) {
		const groups = new Set(expandedGroups);
		if (groups.has(groupName)) {
			groups.delete(groupName);
		} else {
			groups.add(groupName);
		}
		expandedGroups = groups; // Trigger reactivity
	}

	function toggleAll() {
		const groups = new Set(expandedGroups);
		if (groups.size === data.length) {
			groups.clear();
		} else {
			data.forEach((group: any) => groups.add(group.name));
		}
		expandedGroups = groups; // Trigger reactivity
	}

	$effect(() => {
		// Timer for showing countdown
		const timer = setInterval(() => {
			if (updateInterval > 0 && !updating) {
				const timeSinceUpdate = Date.now() - lastUpdateTime;
				updateTimer = Math.max(0, Math.ceil((updateInterval - timeSinceUpdate) / 1000));
			} else {
				updateTimer = 0;
			}
		}, 1000);
		return () => clearInterval(timer);
	});

	$effect(() => {
		// Timer for updating countdown timers
		const timer = setInterval(() => {
			currentTime = Date.now();
		}, 1000);
		return () => clearInterval(timer);
	});

	// Initial load and interval setup - run only once
	let hasInitialized = false;

	$effect(() => {
		if (!hasInitialized) {
			hasInitialized = true;
			load(true);
			updateIntervalSetting(updateInterval);
		}
	});
</script>

<main class="mx-auto min-h-screen max-w-6xl bg-white p-2 transition-colors sm:p-4 dark:bg-gray-900">
	<!-- Header -->
	<Header onToggleSettings={toggleSettings}>
		<SettingsPanel
			{settingsOpen}
			{updateInterval}
			{intervalOptions}
			{updating}
			{updateTimer}
			{lastUpdateTime}
			event={(type: string, value?: any) => {
				if (type === 'updateInterval') updateIntervalSetting(value);
				else if (type === 'manualUpdate') load(false);
				else if (type === 'toggleSettings') toggleSettings();
			}}
		/>
	</Header>

	<!-- Error Banner -->
	<ErrorBanner {error} {updating} {showErrorDetails} {toggleErrorDetails} {retry} />

	<!-- Loading indicator for initial load -->
	{#if initialLoading}
		<LoadingIndicator />
	{:else if data.length > 0}
		<!-- Update indicator overlay -->
		<UpdateIndicator {updating} />

		<div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
			<div class="text-sm text-gray-600 dark:text-gray-400">
				{data.length} grupper, {data.reduce(
					(total: number, group: any) => total + group.machines.length,
					0
				)} resurser
			</div>
			<button
				onclick={toggleAll}
				class="self-start rounded bg-blue-500 px-4 py-2 text-sm text-white transition-colors hover:bg-blue-600 sm:self-auto dark:bg-blue-600 dark:hover:bg-blue-700"
			>
				{expandedGroups.size === data.length ? 'Dölj alla' : 'Visa alla'}
			</button>
		</div>

		<div class="space-y-4 sm:space-y-6">
			{#each data as group}
				<MachineGroup
					{group}
					expanded={expandedGroups.has(group.name)}
					{currentTime}
					toggle={() => toggleGroup(group.name)}
				/>
			{/each}
		</div>
	{:else if !initialLoading && !error}
		<!-- No data state -->
		<NoDataState />
	{/if}
</main>
