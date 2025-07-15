import { DOMParser } from 'deno_dom';
import { load } from 'dotenv';

await load({ export: true });
const BASE_URL = Deno.env.get('BASE_URL') || '';

const LOGIN_URL = `${BASE_URL}/booking/Default.aspx`;
export async function login(username: string, password: string) {
	console.log('Authenticating user...');
	const res1 = await fetch(LOGIN_URL);

	// Handle gateway timeout or other server errors
	if (res1.status >= 500) {
		throw new Error(
			`Server error: ${res1.status} - The booking system server appears to be down or experiencing issues`
		);
	}

	const html = await res1.text();
	const doc = new DOMParser().parseFromString(html, 'text/html')!;

	const vs = doc.querySelector('input#__VIEWSTATE')?.getAttribute('value') || '';
	const ev = doc.querySelector('input#__EVENTVALIDATION')?.getAttribute('value') || '';
	const vg = doc.querySelector('input#__VIEWSTATEGENERATOR')?.getAttribute('value') || '';

	const fm = new URLSearchParams();
	fm.set('__EVENTTARGET', 'ctl00$ContentPlaceHolder1$btOK');
	fm.set('__EVENTARGUMENT', '');
	fm.set('__VIEWSTATE', vs);
	fm.set('__VIEWSTATEGENERATOR', vg);
	fm.set('__EVENTVALIDATION', ev);
	fm.set('ctl00$ContentPlaceHolder1$tbUsername', username);
	fm.set('ctl00$ContentPlaceHolder1$tbPassword', password);

	const res2 = await fetch(LOGIN_URL, {
		method: 'POST',
		body: fm,
		headers: {
			'Content-Type': 'application/x-www-form-urlencoded',
			Referer: LOGIN_URL,
			'User-Agent':
				'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
		},
		redirect: 'manual'
	});

	// Handle gateway timeout or other server errors
	if (res2.status >= 500) {
		throw new Error(
			`Server error: ${res2.status} - The booking system server appears to be down or experiencing issues`
		);
	}

	// Check if login failed (200 means the form was returned again)
	if (res2.status === 200) {
		const loginErrorHtml = await res2.text();
		console.log('Login failed - saving error details to debug_login_error.html');
		try {
			await Deno.writeTextFile('debug_login_error.html', loginErrorHtml);
		} catch (error) {
			console.log('Failed to save login error file:', error);
		}
		throw new Error('Login failed - received 200 status instead of redirect');
	}

	const cookie = res2.headers.get('set-cookie')?.match(/RCARDM5WebBoka=[^;]+/);
	if (!cookie) throw new Error('Login misslyckades');

	// Follow the redirect to complete the login process
	const location = res2.headers.get('location');
	if (location && res2.status === 302) {
		const redirectUrl = location.startsWith('/') ? `${BASE_URL}${location}` : location;
		await fetch(redirectUrl, {
			headers: {
				Cookie: cookie[0],
				Referer: LOGIN_URL
			}
		});
	}

	console.log('Authentication successful');
	return cookie[0];
}
