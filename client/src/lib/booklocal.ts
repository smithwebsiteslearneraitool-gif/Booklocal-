export type Business = {
  id: string;
  name: string;
  category: string;
  address: string | null;
  description: string | null;
  logo_url: string | null;
  is_suspended: boolean;
};

export type Service = {
  id: string;
  business_id: string;
  name: string;
  price: number;
  duration_minutes: number;
  is_active: boolean;
};

const SUPABASE_URL = "https://fohsdblvlgeijzpbjhle.supabase.co";
const SUPABASE_PUBLIC_KEY = "sb_publishable_AbvOQBQat83L6c4sWkwDlA_Exyn5VE9";
const headers = {
  apikey: SUPABASE_PUBLIC_KEY,
  Authorization: `Bearer ${SUPABASE_PUBLIC_KEY}`,
};

async function fetchTable<T>(table: string, query: string): Promise<T[]> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, { headers });
  if (!response.ok) throw new Error(`Unable to load ${table}`);
  return response.json() as Promise<T[]>;
}

export async function fetchMarketplace() {
  const [businesses, services] = await Promise.all([
    fetchTable<Business>(
      "businesses",
      "select=id,name,category,address,description,logo_url,is_suspended&is_suspended=eq.false&order=name.asc",
    ),
    fetchTable<Service>(
      "services",
      "select=id,business_id,name,price,duration_minutes,is_active&is_active=eq.true&order=name.asc",
    ),
  ]);
  return { businesses, services };
}

export const zar = new Intl.NumberFormat("en-ZA", {
  style: "currency",
  currency: "ZAR",
  maximumFractionDigits: 0,
});

export const formatZar = (amount: number) => zar.format(amount);

export const shortAddress = (address: string | null) =>
  address?.replace(", KwaZulu-Natal", "") ?? "Pietermaritzburg";
