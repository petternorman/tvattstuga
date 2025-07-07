import { DOMParser, config } from "./deps.ts";

type MachineState = "available" | "taken" | "not_bookable" | "recently_used";

interface Machine {
  name: string;
  status: string;
  state: MachineState;
}

interface ResourceGroup {
  name: string;
  machines: Machine[];
}

const env = config();
const BASE_URL = env.BASE_URL;

export async function scrape(cookie: string): Promise<ResourceGroup[]> {
  const res = await fetch(`${BASE_URL}/booking/Machine/MachineGroupStat.aspx`, {
    headers: { Cookie: cookie, Referer: `${BASE_URL}/booking/Portal.aspx` },
  });
  const html = await res.text();
  const doc = new DOMParser().parseFromString(html, "text/html")!;

  const resourceGroups: ResourceGroup[] = [];

  // Find all resource group names (MachineName spans)
  const machineNameSpans = doc.querySelectorAll("span[id$='MachineName']");

  for (const machineNameSpan of machineNameSpans) {
    const groupName = machineNameSpan.textContent?.trim() || "";
    if (!groupName) continue;

    // Extract the resource group identifier from the span ID
    // e.g., "ctl00_ContentPlaceHolder1_Repeater1_ctl00_MachineName" -> "ctl00"
    const spanId = machineNameSpan.getAttribute("id") || "";
    const match = spanId.match(
      /ctl(\d+)_ContentPlaceHolder1_Repeater1_ctl(\d+)_MachineName/
    );
    if (!match) continue;

    const resourceGroupId = match[2]; // This is the unique identifier for this resource group

    const machines: Machine[] = [];

    // Find all machine groups that belong to this specific resource group
    // Use the resource group ID to filter machines
    const machineGroupSpans = doc.querySelectorAll(
      `span[id*="ctl${resourceGroupId}_Repeater2"][id$="MaskGrpTitle"]`
    );

    for (const machineGroupSpan of machineGroupSpans) {
      const machineName = machineGroupSpan.textContent?.trim() || "";
      if (!machineName) continue;

      // Find the status for this machine
      const statusSpan = machineGroupSpan
        .closest("div[id$='_divexpand']")
        ?.nextElementSibling?.querySelector("span[id$='LabelStatus']");
      const status = statusSpan?.textContent?.trim() || "";

      // Determine machine state based on name and status
      let state: MachineState = "available";

      if (machineName.toLowerCase().includes("ej ledig")) {
        // Check if it's currently in use (taken) or not bookable
        if (
          machineName.toLowerCase().includes("startad") ||
          machineName.toLowerCase().includes("pågående")
        ) {
          state = "taken";
        } else {
          state = "not_bookable";
        }
      }

      machines.push({
        name: machineName,
        status,
        state,
      });
    }

    if (machines.length > 0) {
      resourceGroups.push({
        name: groupName,
        machines,
      });
    }
  }

  return resourceGroups;
}
