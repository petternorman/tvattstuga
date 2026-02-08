import { load as loadHtml } from 'cheerio';
import type { ResourceGroup, MachineState } from './types.js';

const BASE_URL = process.env.BASE_URL || '';
const USER_AGENT =
	'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

function isRecentlyFinished(status: string): boolean {
	const now = new Date();
	const currentTime = now.getHours() * 60 + now.getMinutes();
	const timeMatch = status.match(/(\d{1,2}):(\d{2})/);
	if (!timeMatch) return false;

	const finishHour = Number.parseInt(timeMatch[1], 10);
	const finishMinute = Number.parseInt(timeMatch[2], 10);
	const finishTime = finishHour * 60 + finishMinute;

	let timeDiff;
	if (currentTime >= finishTime) {
		timeDiff = currentTime - finishTime;
	} else {
		timeDiff = 24 * 60 - finishTime + currentTime;
	}

	return timeDiff <= 60;
}

export async function scrape(cookie: string): Promise<ResourceGroup[]> {
	if (!BASE_URL) {
		throw new Error('BASE_URL is not set');
	}

	await fetch(`${BASE_URL}/booking/Portal.aspx`, {
		headers: {
			Cookie: cookie,
			'User-Agent': USER_AGENT
		}
	});

	const res = await fetch(`${BASE_URL}/booking/Machine/MachineGroupStat.aspx`, {
		headers: {
			Cookie: cookie,
			Referer: `${BASE_URL}/booking/Portal.aspx`,
			'User-Agent': USER_AGENT
		}
	});

	const html = await res.text();
	const $ = loadHtml(html);

	const resourceGroups: ResourceGroup[] = [];

	const machineNameSpans = $("span[id$='MachineName']");
	machineNameSpans.each((_, el) => {
		const groupName = $(el).text().trim();
		if (!groupName) return;

		const spanId = $(el).attr('id') ?? '';
		const match = spanId.match(/ctl00_ContentPlaceHolder1_Repeater1_ctl(\d+)_MachineName/);
		if (!match) return;

		const resourceGroupId = match[1];
		const machines: ResourceGroup['machines'] = [];

		const machineGroupSpans = $(
			`span[id^="ctl00_ContentPlaceHolder1_Repeater1_ctl${resourceGroupId}_Repeater2"][id$="MaskGrpTitle"]`
		);

		machineGroupSpans.each((_, machineEl) => {
			const machineName = $(machineEl).text().trim();
			if (!machineName) return;

			const machineSpanId = $(machineEl).attr('id') ?? '';
			const machineMatch = machineSpanId.match(/ctl(\d+)_Repeater2_ctl(\d+)_MaskGrpTitle/);

			let status = '';
			if (machineMatch) {
				const groupId = machineMatch[1];
				const machineId = machineMatch[2];
				const statusSelector = `span[id="ctl00_ContentPlaceHolder1_Repeater1_ctl${groupId}_Repeater2_ctl${machineId}_Repeater3_ctl01_LabelStatus"]`;
				status = $(statusSelector).text().trim();
			}

			let state: MachineState = 'available';
			const machineNameLower = machineName.toLowerCase();
			const statusLower = status.toLowerCase();

			if (machineNameLower.includes('ej ledig')) {
				state = 'not_bookable';
			} else if (machineNameLower.includes('min bokning')) {
				state = 'taken';
			} else if (
				statusLower.includes('startad') ||
				statusLower.includes('pågående') ||
				statusLower.includes('kvar') ||
				statusLower.includes('reserverad')
			) {
				state = 'taken';
			} else if (statusLower.includes('avslutades')) {
				state = isRecentlyFinished(status) ? 'recently_used' : 'available';
			} else if (machineNameLower.includes('ledig')) {
				state = 'available';
			}

			machines.push({
				name: machineName,
				status,
				state
			});
		});

		if (machines.length > 0) {
			resourceGroups.push({
				name: groupName,
				machines
			});
		}
	});

	return resourceGroups;
}
