<script>
	import {
		parseCompletionTime,
		getStateLabel,
		getStateColor,
		getBorderColor,
		wasRecentlyUsed
	} from './timerUtils.js';

	export let machine;
	export let currentTime;

	// Declare effectiveState and determine the effective state considering recently used
	let effectiveState;
	$: effectiveState =
		machine.state === 'available' && wasRecentlyUsed(machine.status, currentTime)
			? 'recently_used'
			: machine.state;
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
		<span
			class="rounded-full px-2 py-1 text-xs text-white {getStateColor(
				effectiveState
			)} flex-shrink-0"
		>
			{getStateLabel(effectiveState)}
		</span>
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
