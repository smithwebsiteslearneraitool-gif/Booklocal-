import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const config = globalThis.BOOKLOCAL_CONFIG || {};
export const SUPABASE_URL = config.SUPABASE_URL || '';
export const SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY || '';
export const supabase = SUPABASE_URL && SUPABASE_ANON_KEY
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  : null;

export const isSupabaseConfigured = () => Boolean(supabase);

export const formatZar = amount => new Intl.NumberFormat('en-ZA', {
  style: 'currency',
  currency: 'ZAR',
  maximumFractionDigits: 0
}).format(Number(amount));

const toMinutes = value => {
  const [hours, minutes] = String(value).slice(0, 5).split(':').map(Number);
  return hours * 60 + minutes;
};
const asTime = minutes => `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}:00`;
const overlaps = (start, end, otherStart, otherEnd) => start < otherEnd && end > otherStart;

export async function getLiveServices(category = '') {
  if (!supabase) return [];
  let query = supabase.from('services').select('id,business_id,name,price,duration_minutes,businesses!inner(id,name,category,address,description,logo_url,is_suspended)').eq('is_active', true).eq('businesses.is_suspended', false).order('name');
  if (category) query = query.eq('businesses.category', category);
  const { data, error } = await query;
  if (error) throw error;
  return (data || []).map(row => ({
    id: row.id,
    businessId: row.business_id,
    name: row.businesses.name,
    category: row.businesses.category,
    service: row.name,
    duration: `${row.duration_minutes} min`,
    durationMinutes: row.duration_minutes,
    price: Number(row.price),
    address: row.businesses.address,
    description: row.businesses.description || 'A local service ready to welcome you.',
    icon: '✦'
  }));
}

export async function getAvailableSlots(businessId, date, serviceId) {
  if (!supabase) return [];
  const serviceResult = await supabase.from('services').select('duration_minutes').eq('id', serviceId).eq('business_id', businessId).eq('is_active', true).single();
  if (serviceResult.error) throw serviceResult.error;
  const dayOfWeek = new Date(`${date}T12:00:00+02:00`).getDay();
  const hoursResult = await supabase.from('business_hours').select('open_time,close_time,is_closed').eq('business_id', businessId).eq('day_of_week', dayOfWeek).maybeSingle();
  if (hoursResult.error) throw hoursResult.error;
  if (!hoursResult.data || hoursResult.data.is_closed) return [];
  const [bookingsResult, blockedResult] = await Promise.all([
    supabase.from('bookings').select('start_time,end_time').eq('business_id', businessId).eq('date', date).in('status', ['pending', 'confirmed', 'rescheduled']),
    supabase.from('blocked_times').select('start_time,end_time').eq('business_id', businessId).eq('date', date)
  ]);
  if (bookingsResult.error) throw bookingsResult.error;
  if (blockedResult.error) throw blockedResult.error;
  const unavailable = [...(bookingsResult.data || []), ...(blockedResult.data || [])].map(x => [toMinutes(x.start_time), toMinutes(x.end_time)]);
  const duration = serviceResult.data.duration_minutes;
  const open = toMinutes(hoursResult.data.open_time);
  const close = toMinutes(hoursResult.data.close_time);
  const nowInSouthAfrica = new Intl.DateTimeFormat('en-GB', { timeZone: 'Africa/Johannesburg', hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date());
  const todayInSouthAfrica = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Johannesburg' }).format(new Date());
  const currentMinutes = toMinutes(nowInSouthAfrica);
  const result = [];
  for (let start = open; start + duration <= close; start += duration) {
    const end = start + duration;
    if (date === todayInSouthAfrica && start <= currentMinutes) continue;
    if (!unavailable.some(([usedStart, usedEnd]) => overlaps(start, end, usedStart, usedEnd))) result.push({ start: asTime(start), end: asTime(end), label: asTime(start).slice(0, 5) });
  }
  return result;
}
