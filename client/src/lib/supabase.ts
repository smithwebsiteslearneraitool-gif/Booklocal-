import { createClient } from "@supabase/supabase-js";

export const supabase = createClient(
  "https://fohsdblvlgeijzpbjhle.supabase.co",
  "sb_publishable_AbvOQBQat83L6c4sWkwDlA_Exyn5VE9",
);

export type Profile = { id: string; role: "customer" | "business" | "admin"; full_name: string | null; phone: string | null; city: string | null };
export type Business = { id: string; name: string; category: string; city: string | null; address: string | null; whatsapp: string | null; description: string | null; is_active: boolean; rating_avg: number; price_from: number; latitude?: number | null; longitude?: number | null };
export type Service = { id: string; business_id: string; name: string; price: number; duration_minutes: number; is_active: boolean };
export type Booking = { id: string; customer_id: string; business_id: string; service_id: string; date: string; booking_date: string | null; start_time: string; end_time: string; status: string; total_price: number; notes: string | null; businesses?: Business; services?: Service };

export const formatZar = (value: number) => new Intl.NumberFormat("en-ZA", { style: "currency", currency: "ZAR", maximumFractionDigits: 0 }).format(value);
export const formatDate = (value: string) => new Intl.DateTimeFormat("en-ZA", { dateStyle: "medium", timeZone: "Africa/Johannesburg" }).format(new Date(`${value}T12:00:00+02:00`));

export async function getProfile() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase.from("profiles").select("id,role,full_name,phone,city").eq("id", user.id).maybeSingle();
  return data as Profile | null;
}

const minutes = (value: string) => { const [h, m] = value.slice(0, 5).split(":").map(Number); return h * 60 + m; };
const time = (value: number) => `${String(Math.floor(value / 60)).padStart(2, "0")}:${String(value % 60).padStart(2, "0")}:00`;

export async function getAvailableSlots(businessId: string, serviceId: string, date: string) {
  const { data: service, error: serviceError } = await supabase.from("services").select("duration_minutes").eq("id", serviceId).single();
  if (serviceError) throw serviceError;
  const day = new Date(`${date}T12:00:00+02:00`).getDay();
  const { data: hours, error: hourError } = await supabase.from("business_hours").select("open_time,close_time,is_closed").eq("business_id", businessId).eq("day_of_week", day).maybeSingle();
  if (hourError) throw hourError;
  if (!hours || hours.is_closed) return [];
  const [{ data: bookings, error: bookingsError }, { data: blocked, error: blockedError }] = await Promise.all([
    supabase.from("bookings").select("start_time,end_time").eq("business_id", businessId).eq("date", date).in("status", ["pending", "confirmed", "rescheduled"]),
    supabase.from("blocked_times").select("start_time,end_time").eq("business_id", businessId).eq("date", date),
  ]);
  if (bookingsError) throw bookingsError;
  if (blockedError) throw blockedError;
  const unavailable = [...(bookings ?? []), ...(blocked ?? [])].map((slot) => [minutes(slot.start_time), minutes(slot.end_time)]);
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Johannesburg" }).format(new Date());
  const now = minutes(new Intl.DateTimeFormat("en-GB", { timeZone: "Africa/Johannesburg", hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date()));
  const result: { start: string; end: string; label: string }[] = [];
  for (let start = minutes(hours.open_time); start + service.duration_minutes <= minutes(hours.close_time); start += service.duration_minutes) {
    const end = start + service.duration_minutes;
    if (date === today && start <= now) continue;
    if (!unavailable.some(([usedStart, usedEnd]) => start < usedEnd && end > usedStart)) result.push({ start: time(start), end: time(end), label: time(start).slice(0, 5) });
  }
  return result;
}

export async function createBooking(input: { business_id: string; service_id: string; date: string; start_time: string; end_time: string; total_price: number; notes: string }) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Please sign in before booking.");
  const { data, error } = await supabase.rpc("create_booking", { p_business_id: input.business_id, p_service_id: input.service_id, p_date: input.date, p_start: input.start_time, p_end: input.end_time, p_notes: input.notes });
  if (error) throw error;
  return data as unknown as Booking;
}

export const cancelBooking = (id: string) => supabase.rpc("cancel_booking", { p_booking_id: id });
export async function rescheduleBooking(id: string, _oldDate: string, date: string, start_time: string, end_time: string) {
  const { data, error } = await supabase.rpc("reschedule_booking", { p_booking_id: id, p_date: date, p_start: start_time, p_end: end_time });
  return { data, error };
}
