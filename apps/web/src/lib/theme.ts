import { browser } from '$app/environment';
import { writable } from 'svelte/store';

export type ThemeMode = 'light' | 'dark' | 'system';

function createThemeStore() {
	// Default to system, only store explicit user choices
	const getInitialMode = (): ThemeMode => {
		if (!browser) return 'system';
		const saved = globalThis.localStorage?.getItem('theme-mode') as ThemeMode;
		return saved || 'system';
	};

	const { subscribe, set } = writable<ThemeMode>(getInitialMode());
	let currentMode = getInitialMode();

	function getSystemPreference(): boolean {
		if (!browser) return false;
		return globalThis.matchMedia?.('(prefers-color-scheme: dark)').matches || false;
	}

	function isDark(): boolean {
		if (currentMode === 'system') {
			return getSystemPreference();
		}
		return currentMode === 'dark';
	}

	function updateDOM() {
		if (browser && globalThis.document) {
			const html = globalThis.document.documentElement;
			html.classList.remove('dark');
			if (isDark()) {
				html.classList.add('dark');
			}
		}
	}

	function setMode(mode: ThemeMode) {
		currentMode = mode;
		set(mode);

		// Only save explicit choices (light/dark), not system
		if (browser && globalThis.localStorage) {
			if (mode === 'system') {
				globalThis.localStorage.removeItem('theme-mode');
			} else {
				globalThis.localStorage.setItem('theme-mode', mode);
			}
		}

		updateDOM();
	}

	// Listen for system preference changes
	if (browser && globalThis.matchMedia) {
		const mediaQuery = globalThis.matchMedia('(prefers-color-scheme: dark)');
		mediaQuery.addEventListener('change', () => {
			if (currentMode === 'system') {
				updateDOM();
			}
		});
	}

	// Initialize DOM on first run
	if (browser) {
		updateDOM();
	}

	return {
		setMode,
		subscribe,
		get currentMode() {
			return currentMode;
		}
	};
}

export const themeStore = createThemeStore();
