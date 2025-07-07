import { DOMParser, config } from "./deps.ts";

const env = config();
const BASE_URL = env.BASE_URL;

const LOGIN_URL = `${BASE_URL}/booking/Default.aspx`;
export async function login(username: string, password: string) {
  const res1 = await fetch(LOGIN_URL);
  const html = await res1.text();
  const doc = new DOMParser().parseFromString(html, "text/html")!;
  const vs =
    doc.querySelector("input#__VIEWSTATE")?.getAttribute("value") || "";
  const ev =
    doc.querySelector("input#__EVENTVALIDATION")?.getAttribute("value") || "";
  const vg =
    doc.querySelector("input#__VIEWSTATEGENERATOR")?.getAttribute("value") ||
    "";

  const fm = new FormData();
  fm.set("__EVENTTARGET", "ctl00$ContentPlaceHolder1$btOK");
  fm.set("__VIEWSTATE", vs);
  fm.set("__EVENTVALIDATION", ev);
  fm.set("__VIEWSTATEGENERATOR", vg);
  fm.set("ctl00$ContentPlaceHolder1$tbUsername", username);
  fm.set("ctl00$ContentPlaceHolder1$tbPassword", password);

  const res2 = await fetch(LOGIN_URL, {
    method: "POST",
    body: fm,
    redirect: "manual",
  });
  const cookie = res2.headers.get("set-cookie")?.match(/RCARDM5WebBoka=[^;]+/);
  if (!cookie) throw new Error("Login misslyckades");
  return cookie[0];
}
