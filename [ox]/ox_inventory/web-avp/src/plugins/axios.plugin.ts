/* VoidLine: this used to build a real axios instance pointed at the AVP
   resource. The AVP components are unmodified and still import AxiosInstance
   from here, so swapping what this exports is all it takes to redirect every
   UI action at ox_inventory's NUI callbacks instead.

   See ./ox-adapter.ts for the action mapping. */
import { OxAxiosShim } from "./ox-adapter";

export const AxiosInstance = OxAxiosShim;
