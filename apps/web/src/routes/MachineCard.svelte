<script lang="ts">
	import {
		parseCompletionTime,
		getStateLabel,
		getStateColor,
		getBorderColor,
		wasRecentlyUsed
	} from './timerUtils.js';

	let {
		machine,
		currentTime,
		tracked = false,
		onToggleTrack
	}: {
		machine: any;
		currentTime: number;
		tracked?: boolean;
		onToggleTrack?: () => void;
	} = $props();

	const effectiveState = $derived(
		machine.state === 'available' && wasRecentlyUsed(machine.status, currentTime)
			? 'recently_used'
			: machine.state
	);
</script>

<div
	class="rounded-lg border-l-4 bg-gray-50 p-3 sm:rounded-xl sm:p-4 dark:bg-gray-800 {getBorderColor(
		effectiveState
	)}"
>
	<div class="mb-2 flex items-start justify-between gap-2">
		<span class="text-sm font-medium break-words text-gray-900 sm:text-base dark:text-gray-100"
			>{machine.name}</span
		>
		<div class="flex flex-shrink-0 items-center gap-1.5">
			{#if effectiveState === 'taken' && onToggleTrack}
				<button
					onclick={onToggleTrack}
					class="rounded-full p-1 transition-colors {tracked
						? 'text-yellow-500 hover:text-yellow-600 dark:text-yellow-400 dark:hover:text-yellow-300'
						: 'text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300'}"
					title={tracked ? 'Avbryt bevakning' : 'Meddela mig när maskinen är klar'}
					aria-label={tracked ? 'Avbryt bevakning' : 'Meddela mig när maskinen är klar'}
				>
					{#if tracked}
						<svg class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
							<path
								d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"
							/>
						</svg>
					{:else}
						<svg
							class="h-5 w-5"
							viewBox="0 0 24 24"
							fill="none"
							stroke="currentColor"
							stroke-width="2"
							aria-hidden="true"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
							/>
						</svg>
					{/if}
				</button>
			{/if}
			<span
				class="rounded-full px-2 py-1 text-xs text-white {getStateColor(
					effectiveState
				)} flex-shrink-0"
			>
				{getStateLabel(effectiveState)}
			</span>
		</div>
	</div>
	<p class="text-sm break-words text-gray-600 dark:text-gray-400">
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
