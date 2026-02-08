import { load as loadHtml } from 'cheerio';

const BASE_URL = process.env.BASE_URL || '';
const USER_AGENT =
	'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const LOGIN_PATH = '/booking/Default.aspx';

export async function login(username: string, password: string): Promise<string> {
	if (!BASE_URL) {
		throw new Error('BASE_URL is not set');
	}

	const loginUrl = `${BASE_URL}${LOGIN_PATH}`;

	const res1 = await fetch(loginUrl, {
		headers: {
			'User-Agent': USER_AGENT
		}
	});

	if (res1.status >= 500) {
		throw new Error(`Backend error: ${res1.status} - login page unavailable`);
	}

	const html = await res1.text();
	const $ = loadHtml(html);

	const vs = $('input#__VIEWSTATE').attr('value') ?? '';
	const ev = $('input#__EVENTVALIDATION').attr('value') ?? '';
	const vg = $('input#__VIEWSTATEGENERATOR').attr('value') ?? '';

	const fm = new URLSearchParams();
	fm.set('__EVENTTARGET', 'ctl00$ContentPlaceHolder1$btOK');
	fm.set('__EVENTARGUMENT', '');
	fm.set('__VIEWSTATE', vs);
	fm.set('__VIEWSTATEGENERATOR', vg);
	fm.set('__EVENTVALIDATION', ev);
	fm.set('ctl00$ContentPlaceHolder1$tbUsername', username);
	fm.set('ctl00$ContentPlaceHolder1$tbPassword', password);

	const res2 = await fetch(loginUrl, {
		method: 'POST',
		body: fm,
		headers: {
			'Content-Type': 'application/x-www-form-urlencoded',
			Referer: loginUrl,
			'User-Agent': USER_AGENT
		},
		redirect: 'manual'
	});

	if (res2.status >= 500) {
		throw new Error(`Backend error: ${res2.status} - login failed`);
	}

	if (res2.status === 200) {
		throw new Error('LOGIN_FAILED');
	}

	const setCookie = res2.headers.get('set-cookie') ?? '';
	const cookieMatch = setCookie.match(/RCARDM5WebBoka=[^;]+/);
	if (!cookieMatch) {
		throw new Error('LOGIN_FAILED');
	}

	const cookie = cookieMatch[0];

	const location = res2.headers.get('location');
	if (location && res2.status === 302) {
		const redirectUrl = location.startsWith('/') ? `${BASE_URL}${location}` : location;
		await fetch(redirectUrl, {
			headers: {
				Cookie: cookie,
				Referer: loginUrl,
				'User-Agent': USER_AGENT
			}
		});
	}

	return cookie;
}
