-- BookLocal Full Marketplace migration
-- Project: fohsdblvlgeijzpbjhle
-- Run after schema.sql. Timezone: Africa/Johannesburg. No payment processor is used.
set timezone = 'Africa/Johannesburg';

alter table public.businesses add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.businesses add column if not exists city text;
alter table public.businesses add column if not exists whatsapp text;
alter table public.businesses add column if not exists is_active boolean not null default true;
alter table public.businesses add column if not exists rating_avg numeric(3,2) not null default 0;
alter table public.businesses add column if not exists price_from numeric(12,2) not null default 0;
alter table public.business_hours add column if not exists weekday smallint;
update public.business_hours set weekday=day_of_week where weekday is null;
alter table public.blocked_times add column if not exists start_at timestamptz;
alter table public.blocked_times add column if not exists end_at timestamptz;
alter table public.bookings add column if not exists booking_date date;
alter table public.bookings add column if not exists notes text;
update public.bookings set booking_date=date where booking_date is null;

create table if not exists public.profiles (id uuid primary key references auth.users(id) on delete cascade, role text not null default 'customer' check (role in ('customer','business','admin')), full_name text, phone text, city text, created_at timestamptz not null default now());
alter table public.profiles enable row level security;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare requested_role text := new.raw_user_meta_data->>'role'; v_name text := coalesce(new.raw_user_meta_data->>'full_name',split_part(new.email,'@',1)); v_phone text := new.raw_user_meta_data->>'phone'; v_city text := coalesce(new.raw_user_meta_data->>'city','Pietermaritzburg');
begin
  if requested_role not in ('customer','business') then requested_role := 'customer'; end if;
  insert into public.profiles(id,role,full_name,phone,city) values (new.id,requested_role,v_name,v_phone,v_city) on conflict (id) do update set role=excluded.role,full_name=excluded.full_name,phone=excluded.phone,city=excluded.city;
  if requested_role='customer' then insert into public.customers(id,email,phone,name,is_suspended) values(new.id,new.email,v_phone,v_name,false) on conflict (id) do update set email=excluded.email,phone=excluded.phone,name=excluded.name; end if;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.current_user_role() returns text language sql stable security definer set search_path=public as $$ select role from public.profiles where id=auth.uid(); $$;
create or replace function public.is_booklocal_admin() returns boolean language sql stable security definer set search_path=public as $$ select public.current_user_role()='admin'; $$;

-- The deployed policies are intentionally non-recursive. Public discovery can read only active places.
-- Keep the existing project policies if applying this file to a fresh copy; on an existing project, drop conflicting policies first.

create unique index if not exists reviews_booking_id_unique on public.reviews(booking_id);
create or replace function public.refresh_business_rating() returns trigger language plpgsql security definer set search_path=public as $$ begin update public.businesses set rating_avg=coalesce((select round(avg(rating)::numeric,2) from public.reviews where business_id=coalesce(new.business_id,old.business_id)),0) where id=coalesce(new.business_id,old.business_id); return coalesce(new,old); end; $$;
drop trigger if exists reviews_refresh_business_rating on public.reviews;
create trigger reviews_refresh_business_rating after insert or update or delete on public.reviews for each row execute function public.refresh_business_rating();

create or replace function public.create_booking(p_business_id uuid,p_service_id uuid,p_date date,p_start time,p_end time,p_notes text default null) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_user uuid := auth.uid(); v_price numeric; v_business_active boolean; v_booking public.bookings;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from public.profiles where id=v_user and role='customer') then raise exception 'Customer account required'; end if;
  select b.is_active and not b.is_suspended into v_business_active from public.businesses b where b.id=p_business_id;
  if coalesce(v_business_active,false)=false then raise exception 'Business is not active'; end if;
  select price into v_price from public.services where id=p_service_id and business_id=p_business_id and is_active=true;
  if v_price is null then raise exception 'Service is not available'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||p_date::text,0));
  if not public.check_availability(p_business_id,p_date,p_start,p_end) then raise exception 'That time is no longer available'; end if;
  insert into public.bookings(customer_id,business_id,service_id,date,booking_date,start_time,end_time,status,payment_status,total_price,notes) values(v_user,p_business_id,p_service_id,p_date,p_date,p_start,p_end,'confirmed','unpaid',v_price,p_notes) returning * into v_booking;
  return to_jsonb(v_booking);
end; $$;

create or replace function public.cancel_booking(p_booking_id uuid) returns boolean language plpgsql security definer set search_path=public as $$ begin update public.bookings set status='cancelled',cancelled_at=now(),cancel_reason='Cancelled by customer' where id=p_booking_id and customer_id=auth.uid() and status in ('pending','confirmed','rescheduled'); return found; end; $$;
create or replace function public.reschedule_booking(p_booking_id uuid,p_date date,p_start time,p_end time) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_user uuid := auth.uid(); v_booking public.bookings; v_old_date date;
begin
  select * into v_booking from public.bookings where id=p_booking_id and customer_id=v_user and status in ('pending','confirmed','rescheduled') for update;
  if not found then raise exception 'Booking not found or cannot be rescheduled'; end if;
  v_old_date := v_booking.date;
  perform pg_advisory_xact_lock(hashtextextended(v_booking.business_id::text||p_date::text,0));
  if exists(select 1 from public.bookings b where b.id<>p_booking_id and b.business_id=v_booking.business_id and b.date=p_date and b.status in ('pending','confirmed','rescheduled') and (b.start_time,b.end_time) overlaps (p_start,p_end)) then raise exception 'That time is no longer available'; end if;
  if exists(select 1 from public.blocked_times bt where bt.business_id=v_booking.business_id and bt.date=p_date and (bt.start_time,bt.end_time) overlaps (p_start,p_end)) then raise exception 'That time is blocked'; end if;
  update public.bookings set date=p_date,booking_date=p_date,start_time=p_start,end_time=p_end,status='rescheduled',rescheduled_from=v_old_date,reschedule_count=reschedule_count+1 where id=p_booking_id returning * into v_booking;
  return to_jsonb(v_booking);
end; $$;
revoke all on function public.create_booking(uuid,uuid,date,time,time,text) from public; grant execute on function public.create_booking(uuid,uuid,date,time,time,text) to authenticated;
revoke all on function public.cancel_booking(uuid) from public; grant execute on function public.cancel_booking(uuid) to authenticated;
revoke all on function public.reschedule_booking(uuid,date,time,time) from public; grant execute on function public.reschedule_booking(uuid,date,time,time) to authenticated;

-- Seed records are intentionally managed separately in the deployment migration so they can be replaced without touching bookings.
