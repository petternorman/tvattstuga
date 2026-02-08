<script lang="ts">
	import { onMount } from 'svelte';
	import Header from './Header.svelte';
	import SettingsPanel from './SettingsPanel.svelte';
	import ErrorBanner from './ErrorBanner.svelte';
	import LoadingIndicator from './LoadingIndicator.svelte';
	import UpdateIndicator from './UpdateIndicator.svelte';
	import MachineGroup from './MachineGroup.svelte';
	import NoDataState from './NoDataState.svelte';

	const CREDENTIALS_KEY = 'tvattstuga.credentials';
	const apiBase = (import.meta.env.PUBLIC_API_BASE_URL || '').replace(/\/$/, '');

	let credentials = $state({ username: '', password: '' });
	let hasCredentials = $state(false);
	let loginOpen = $state(false);
	let loginError = $state<string | null>(null);

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
	let hasStarted = $state(false);

	const intervalOptions = [
		{ value: 0, label: 'Av' },
		{ value: 30000, label: '30 sekunder' },
		{ value: 60000, label: '1 minut' },
		{ value: 300000, label: '5 minuter' },
		{ value: 600000, label: '10 minuter' }
	];

	async function load(isInitialLoad = false) {
		try {
			if (!hasCredentials) {
				initialLoading = false;
				updating = false;
				return;
			}

			if (isInitialLoad) {
				initialLoading = true;
			} else {
				updating = true;
			}
			error = null; // Clear any previous errors

			const res = await fetch(`${apiBase}/api/tvatt`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					username: credentials.username,
					password: credentials.password
				})
			});
			if (!res.ok) {
				if (res.status === 401) {
					loginError = 'Inloggningen misslyckades. Kontrollera uppgifterna.';
					loginOpen = true;
				}
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

	function openLogin() {
		loginError = null;
		loginOpen = true;
	}

	function closeLogin() {
		if (hasCredentials) {
			loginOpen = false;
			loginError = null;
		}
	}

	function saveCredentials() {
		loginError = null;
		const username = credentials.username.trim();
		const password = credentials.password;

		if (!username || !password) {
			loginError = 'Användarnamn och lösenord krävs.';
			return;
		}

		const stored = { username, password };
		localStorage.setItem(CREDENTIALS_KEY, JSON.stringify(stored));
		credentials = stored;
		hasCredentials = true;
		loginOpen = false;
		hasStarted = false;
		load(true);
		updateIntervalSetting(updateInterval);
	}

	function handleLoginSubmit(event: Event) {
		event.preventDefault();
		saveCredentials();
	}

	function clearCredentials() {
		localStorage.removeItem(CREDENTIALS_KEY);
		credentials = { username: '', password: '' };
		hasCredentials = false;
		data = [];
		error = null;
		initialLoading = false;
		updating = false;
		if (intervalId) {
			clearInterval(intervalId);
			intervalId = null;
		}
		hasStarted = false;
		loginOpen = true;
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

	$effect(() => {
		if (!hasCredentials || hasStarted) {
			return;
		}
		hasStarted = true;
		load(true);
		updateIntervalSetting(updateInterval);
	});

	onMount(() => {
		const saved = localStorage.getItem(CREDENTIALS_KEY);
		if (saved) {
			try {
				const parsed = JSON.parse(saved);
				if (typeof parsed?.username === 'string' && typeof parsed?.password === 'string') {
					credentials = { username: parsed.username, password: parsed.password };
					hasCredentials = true;
					return;
				}
			} catch {
				localStorage.removeItem(CREDENTIALS_KEY);
			}
		}
		loginOpen = true;
		initialLoading = false;
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
			hasCredentials={hasCredentials}
			savedUsername={credentials.username}
			event={(type: string, value?: any) => {
				if (type === 'updateInterval') updateIntervalSetting(value);
				else if (type === 'manualUpdate') load(false);
				else if (type === 'toggleSettings') toggleSettings();
				else if (type === 'openLogin') openLogin();
				else if (type === 'clearCredentials') clearCredentials();
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

{#if loginOpen}
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
		<div class="w-full max-w-sm rounded-lg bg-white p-4 shadow-lg dark:bg-gray-800">
			<h2 class="text-base font-semibold text-gray-900 dark:text-gray-100">Spara inloggning</h2>
			<p class="mt-1 text-xs text-gray-600 dark:text-gray-400">
				Uppgifterna sparas lokalt i webbläsaren för att slippa logga in igen.
			</p>

			<form class="mt-4 space-y-3" onsubmit={handleLoginSubmit}>
				<div>
					<label
						for="login-username"
						class="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300"
					>
						Användarnamn
					</label>
					<input
						id="login-username"
						type="text"
						autocomplete="username"
						bind:value={credentials.username}
						class="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:ring-2 focus:ring-blue-500 focus:outline-none dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
					/>
				</div>
				<div>
					<label
						for="login-password"
						class="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300"
					>
						Lösenord
					</label>
					<input
						id="login-password"
						type="password"
						autocomplete="current-password"
						bind:value={credentials.password}
						class="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:ring-2 focus:ring-blue-500 focus:outline-none dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
					/>
				</div>

				{#if loginError}
					<div class="text-xs text-red-600 dark:text-red-400">{loginError}</div>
				{/if}

				<div class="flex items-center justify-between gap-2 pt-1">
					{#if hasCredentials}
						<button
							type="button"
							onclick={closeLogin}
							class="flex-1 rounded-md bg-gray-200 px-3 py-2 text-sm text-gray-800 transition-colors hover:bg-gray-300 dark:bg-gray-700 dark:text-gray-100 dark:hover:bg-gray-600"
						>
							Stäng
						</button>
					{/if}
					<button
						type="submit"
						class="flex-1 rounded-md bg-blue-500 px-3 py-2 text-sm text-white transition-colors hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700"
					>
						Spara
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}
