-- BookLocal production schema
set timezone = 'Africa/Johannesburg';
-- Run in Supabase SQL Editor. All timestamps are stored as timestamptz;
-- the application timezone is Africa/Johannesburg.
create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create type booking_status as enum ('pending','confirmed','completed','cancelled','rescheduled');
create type payment_status as enum ('not_required','pending','paid','failed','refunded');

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  phone text,
  name text not null,
  password_hash text,
  is_suspended boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists businesses (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  name text not null,
  category text not null,
  address text,
  description text,
  logo_url text,
  is_suspended boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  name text not null,
  price numeric(12,2) not null check (price >= 0),
  duration_minutes integer not null check (duration_minutes > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists business_hours (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  open_time time,
  close_time time,
  is_closed boolean not null default false,
  unique (business_id, day_of_week),
  check (is_closed or (open_time is not null and close_time is not null and open_time < close_time))
);

create table if not exists blocked_times (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  date date not null,
  start_time time not null,
  end_time time not null,
  check (start_time < end_time)
);

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  business_id uuid not null references businesses(id),
  service_id uuid not null references services(id),
  date date not null,
  start_time time not null,
  end_time time not null,
  status booking_status not null default 'pending',
  payment_status payment_status not null default 'not_required',
  paystack_ref text unique,
  total_price numeric(12,2) not null check (total_price >= 0),
  created_at timestamptz not null default now(),
  check (start_time < end_time)
);

create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references bookings(id) on delete cascade,
  customer_id uuid not null references customers(id),
  business_id uuid not null references businesses(id),
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create table if not exists favourites (
  customer_id uuid not null references customers(id) on delete cascade,
  business_id uuid not null references businesses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (customer_id, business_id)
);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  paystack_ref text not null unique,
  amount numeric(12,2) not null check (amount >= 0),
  status payment_status not null default 'pending',
  created_at timestamptz not null default now()
);

-- A review is only valid after the linked appointment is completed.
create or replace function enforce_completed_review()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from bookings b where b.id = new.booking_id and b.status = 'completed' and b.customer_id = new.customer_id and b.business_id = new.business_id) then
    raise exception 'Reviews are only allowed for completed bookings belonging to the same customer and business';
  end if;
  return new;
end;
$$;
drop trigger if exists reviews_only_after_completion on reviews;
create trigger reviews_only_after_completion before insert or update on reviews for each row execute function enforce_completed_review();

-- Returns true only when the requested interval overlaps neither an active booking nor a blocked interval.
create or replace function check_availability(
  p_business_id uuid,
  p_date date,
  p_start time,
  p_end time
) returns boolean language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from bookings b
    where b.business_id = p_business_id
      and b.date = p_date
      and b.status in ('pending','confirmed','rescheduled')
      and (b.start_time, b.end_time) overlaps (p_start, p_end)
  ) and not exists (
    select 1 from blocked_times bt
    where bt.business_id = p_business_id
      and bt.date = p_date
      and (bt.start_time, bt.end_time) overlaps (p_start, p_end)
  );
$$;

-- Database-level exclusion constraint is the final protection against concurrent double-booking.
alter table bookings drop constraint if exists bookings_no_overlap;
alter table bookings add constraint bookings_no_overlap exclude using gist (
  business_id with =,
  date with =,
  tsrange(date + start_time, date + end_time, '[)') with &&
) where (status in ('pending','confirmed','rescheduled'));

-- RLS is enabled on every application table. Policies should be refined with the project's auth role mapping.
DO $$ declare t text; begin
  foreach t in array array['customers','businesses','services','business_hours','blocked_times','bookings','reviews','favourites','payments'] loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

-- Minimal authenticated-user policies; service-role operations bypass RLS.
create policy "customers read own row" on customers for select using (id = auth.uid());
create policy "customers update own row" on customers for update using (id = auth.uid()) with check (id = auth.uid());
create policy "businesses public read active" on businesses for select using (not is_suspended);
create policy "businesses owner update" on businesses for update using (id = auth.uid()) with check (id = auth.uid());
create policy "services public read active" on services for select using (is_active);
create policy "hours public read" on business_hours for select using (true);
create policy "blocked public read" on blocked_times for select using (true);
create policy "customers read own bookings" on bookings for select using (customer_id = auth.uid());
create policy "customers create own bookings" on bookings for insert with check (customer_id = auth.uid());
create policy "customers update own bookings" on bookings for update using (customer_id = auth.uid()) with check (customer_id = auth.uid());
create policy "reviews public read" on reviews for select using (true);
create policy "customers create own reviews" on reviews for insert with check (customer_id = auth.uid());
create policy "favourites own rows" on favourites for all using (customer_id = auth.uid()) with check (customer_id = auth.uid());
create policy "payments own booking read" on payments for select using (exists (select 1 from bookings b where b.id = booking_id and b.customer_id = auth.uid()));
