<script lang="ts">
	import '../app.css';
	import { themeStore } from '$lib/theme';

	let { children } = $props();

	// Just accessing the store is enough to initialize it
	$effect(() => {
		themeStore.currentMode; // This triggers initialization
	});
</script>

{@render children()}
