import { DOMParser } from 'deno_dom';
import { load } from 'dotenv';

type MachineState = 'available' | 'taken' | 'not_bookable' | 'recently_used';

interface Machine {
	name: string;
	status: string;
	state: MachineState;
}

interface ResourceGroup {
	name: string;
	machines: Machine[];
}

await load({ export: true });
const BASE_URL = Deno.env.get('BASE_URL') || '';

export async function scrape(cookie: string): Promise<ResourceGroup[]> {
	console.log('Starting scrape...');

	// Access the portal page
	await fetch(`${BASE_URL}/booking/Portal.aspx`, {
		headers: {
			Cookie: cookie,
			'User-Agent':
				'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
		}
	});

	// Fetch machine data
	const res = await fetch(`${BASE_URL}/booking/Machine/MachineGroupStat.aspx`, {
		headers: {
			Cookie: cookie,
			Referer: `${BASE_URL}/booking/Portal.aspx`,
			'User-Agent':
				'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
		}
	});

	const html = await res.text();
	const doc = new DOMParser().parseFromString(html, 'text/html')!;

	const resourceGroups: ResourceGroup[] = [];

	// Find all resource group names (MachineName spans)
	const machineNameSpans = doc.querySelectorAll("span[id$='MachineName']");

	for (const machineNameSpan of machineNameSpans) {
		const groupName = machineNameSpan.textContent?.trim() || '';
		if (!groupName) continue;

		// Extract the resource group identifier from the span ID
		const spanId = machineNameSpan.getAttribute('id') || '';
		const match = spanId.match(/ctl00_ContentPlaceHolder1_Repeater1_ctl(\d+)_MachineName/);
		if (!match) continue;

		const resourceGroupId = match[1];
		const machines: Machine[] = [];

		// Find all machine groups that belong to this specific resource group
		const machineGroupSpans = doc.querySelectorAll(
			`span[id^="ctl00_ContentPlaceHolder1_Repeater1_ctl${resourceGroupId}_Repeater2"][id$="MaskGrpTitle"]`
		);

		for (const machineGroupSpan of machineGroupSpans) {
			const machineName = machineGroupSpan.textContent?.trim() || '';
			if (!machineName) continue;

			// Extract the machine index from the span ID to find the corresponding status
			const machineSpanId = machineGroupSpan.getAttribute('id') || '';
			const machineMatch = machineSpanId.match(/ctl(\d+)_Repeater2_ctl(\d+)_MaskGrpTitle/);

			let status = '';
			if (machineMatch) {
				const groupId = machineMatch[1];
				const machineId = machineMatch[2];

				// Look for the status span with the specific pattern
				const statusSelector = `span[id="ctl00_ContentPlaceHolder1_Repeater1_ctl${groupId}_Repeater2_ctl${machineId}_Repeater3_ctl01_LabelStatus"]`;
				const statusSpan = doc.querySelector(statusSelector);
				status = statusSpan?.textContent?.trim() || '';
			}

			// Determine machine state based on name and status
			let state: MachineState = 'available';

			if (machineName.toLowerCase().includes('ej ledig')) {
				state = 'not_bookable';
			} else if (machineName.toLowerCase().includes('ledig')) {
				// If the machine name says "ledig" (available), it's available regardless of status
				state = 'available';
			} else {
				// For machines that don't explicitly say "ledig" or "ej ledig"
				// Check status to determine if it's currently in use
				if (
					status &&
					(status.toLowerCase().includes('startad') ||
						status.toLowerCase().includes('pågående') ||
						status.toLowerCase().includes('kvar') ||
						status.toLowerCase().includes('reserverad'))
				) {
					state = 'taken';
				} else if (status && status.toLowerCase().includes('avslutades')) {
					state = 'recently_used';
				} else {
					state = 'available';
				}
			}

			machines.push({
				name: machineName,
				status,
				state
			});
		}

		if (machines.length > 0) {
			resourceGroups.push({
				name: groupName,
				machines
			});
		}
	}

	console.log(`Scraping completed. Found ${resourceGroups.length} resource groups.`);
	return resourceGroups;
}
