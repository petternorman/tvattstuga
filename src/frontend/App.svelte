<script>
  import Header from './components/Header.svelte';
  import SettingsPanel from './components/SettingsPanel.svelte';
  import ErrorBanner from './components/ErrorBanner.svelte';
  import LoadingIndicator from './components/LoadingIndicator.svelte';
  import UpdateIndicator from './components/UpdateIndicator.svelte';
  import MachineGroup from './components/MachineGroup.svelte';
  import NoDataState from './components/NoDataState.svelte';
  
  let data = [];
  let initialLoading = true; // Only true on first load
  let updating = false; // True during subsequent updates
  let error = null; // Store error information
  let showErrorDetails = false; // Toggle for error details
  let expandedGroups = new Set(['Tvätt Servicehus 2']); // Default to show Servicehus 2
  let settingsOpen = false;
  let updateInterval = 60000; // Default 1 minute
  let intervalId = null;
  let lastUpdateTime = Date.now();
  let updateTimer = 0;
  let currentTime = Date.now(); // For countdown timers

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
      
      const res = await fetch("/api/tvatt");
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      }
      const newData = await res.json();
      data = newData;
      lastUpdateTime = Date.now();
    } catch (err) {
      console.error("Error loading data:", err);
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

  function updateIntervalSetting(newInterval) {
    updateInterval = newInterval;
    
    // Clear existing interval
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
    
    // Set new interval if not 0
    if (newInterval > 0) {
      intervalId = setInterval(() => load(false), newInterval);
    }
  }

  function toggleSettings() {
    settingsOpen = !settingsOpen;
  }

  function toggleGroup(groupName) {
    if (expandedGroups.has(groupName)) {
      expandedGroups.delete(groupName);
    } else {
      expandedGroups.add(groupName);
    }
    expandedGroups = expandedGroups; // Trigger reactivity
  }

  function toggleAll() {
    if (expandedGroups.size === data.length) {
      expandedGroups.clear();
    } else {
      data.forEach(group => expandedGroups.add(group.name));
    }
    expandedGroups = new Set(expandedGroups); // Trigger reactivity
  }

  // Timer for showing countdown
  setInterval(() => {
    if (updateInterval > 0 && !updating) {
      const timeSinceUpdate = Date.now() - lastUpdateTime;
      updateTimer = Math.max(0, Math.ceil((updateInterval - timeSinceUpdate) / 1000));
    } else {
      updateTimer = 0;
    }
  }, 1000);

  // Timer for updating countdown timers
  setInterval(() => {
    currentTime = Date.now();
  }, 1000);

  // Reactive statement to trigger component updates
  $: if (currentTime) {
    // This will trigger re-renders when currentTime changes
  }

  // Initial load and interval setup
  load(true);
  updateIntervalSetting(updateInterval);
</script>

<main class="p-2 sm:p-4 max-w-6xl mx-auto min-h-screen">
  <!-- Header -->
  <Header onToggleSettings={toggleSettings}>
    <SettingsPanel 
      {settingsOpen}
      {updateInterval}
      {intervalOptions}
      {updating}
      {updateTimer}
      {lastUpdateTime}
      onUpdateInterval={updateIntervalSetting}
      onManualUpdate={() => load(false)}
      onToggleSettings={toggleSettings}
    />
  </Header>
  
  <!-- Error Banner -->
  <ErrorBanner 
    {error}
    {updating}
    onRetry={retry}
    {showErrorDetails}
    onToggleErrorDetails={toggleErrorDetails}
  />

  <!-- Loading indicator for initial load -->
  {#if initialLoading}
    <LoadingIndicator />
  {:else if data.length > 0}
    <!-- Update indicator overlay -->
    <UpdateIndicator {updating} />

    <div class="mb-4 flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3">
      <div class="text-sm text-gray-600">
        {data.length} grupper, {data.reduce((total, group) => total + group.machines.length, 0)} resurser
      </div>
      <button 
        on:click={toggleAll}
        class="px-4 py-2 text-sm bg-blue-500 text-white rounded hover:bg-blue-600 transition-colors self-start sm:self-auto"
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
          onToggle={() => toggleGroup(group.name)}
        />
      {/each}
    </div>
  {:else if !initialLoading && !error}
    <!-- No data state -->
    <NoDataState />
  {/if}
</main>
