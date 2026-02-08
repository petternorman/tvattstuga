export type MachineState = 'available' | 'taken' | 'not_bookable' | 'recently_used';

export interface Machine {
	name: string;
	status: string;
	state: MachineState;
}

export interface ResourceGroup {
	name: string;
	machines: Machine[];
}
