<script lang="ts">
	let { error, updating, showErrorDetails = false, toggleErrorDetails, retry } = $props();
</script>

{#if error}
	<div
		class="mb-4 rounded-lg border border-red-200 bg-red-50 p-3 transition-colors sm:p-4 dark:border-red-800 dark:bg-red-900/20"
	>
		<div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
			<div class="flex items-start space-x-3">
				<svg
					class="mt-0.5 h-5 w-5 flex-shrink-0 text-red-400 dark:text-red-500"
					fill="none"
					stroke="currentColor"
					viewBox="0 0 24 24"
				>
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
					></path>
				</svg>
				<div class="flex-1">
					<h3 class="text-sm font-medium text-red-800 dark:text-red-200">
						{error.isInitialLoad ? 'Kunde inte ladda data' : 'Uppdatering misslyckades'}
					</h3>
					<p class="mt-1 text-sm text-red-700 dark:text-red-300">
						{error.isInitialLoad
							? 'Ingen data kunde laddas från servern.'
							: 'Kunde inte uppdatera data från servern.'}
					</p>
					{#if showErrorDetails}
						<div
							class="mt-2 rounded bg-red-100 p-2 font-mono text-xs break-words text-red-800 dark:bg-red-900/30 dark:text-red-200"
						>
							{error.message}
						</div>
					{/if}
				</div>
			</div>
			<div class="flex flex-col items-stretch gap-2 sm:flex-row sm:items-center sm:space-x-2">
				<button
					onclick={toggleErrorDetails}
					class="text-center text-sm text-red-600 underline transition-colors hover:text-red-800 dark:text-red-400 dark:hover:text-red-200"
				>
					{showErrorDetails ? 'Dölj' : 'Visa'} detaljer
				</button>
				<button
					onclick={retry}
					disabled={updating}
					class="rounded bg-red-600 px-3 py-2 text-sm text-white transition-colors hover:bg-red-700 disabled:cursor-not-allowed disabled:bg-red-400 dark:bg-red-700 dark:hover:bg-red-800 dark:disabled:bg-red-600"
				>
					{updating ? 'Försöker...' : 'Försök igen'}
				</button>
			</div>
		</div>
	</div>
{/if}
