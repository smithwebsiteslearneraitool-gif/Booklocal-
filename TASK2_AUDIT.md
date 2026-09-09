# TASK 2 — Audit, fake-data cleanup, and Supabase schema

## Existing site structure

The static application uses hash routing from `app.js` and contains these routes:

| Route | Purpose | Status after cleanup |
|---|---|---|
| `#home` | BookLocal landing page, search entry point, category links | UI present; live listings pending Supabase |
| `#discover` | Services discovery and search | UI present; empty until live services load |
| `#discover/Beauty` | Beauty category filter | Route present; live data pending |
| `#discover/Wellness` | Wellness category filter | Route present; live data pending |
| `#discover/Fitness` | Fitness category filter | Route present; live data pending |
| `#book/:serviceId` | Booking form for a selected service | Validated UI; submit marked TODO until API and Paystack are connected |
| `#confirmation/:bookingId` | Booking confirmation | Present for future API-backed booking records |
| `#account` | Customer bookings | Empty state; Supabase connection pending |
| `#business` | Business dashboard | Empty state and TODO controls; Supabase connection pending |
| `#admin` | Admin overview | Empty state and TODO controls; Supabase connection pending |
| `#about` | About page | Present |
| `#contact` | Contact page | Present; support contact marked TODO |
| `#terms` | Terms page | Present |
| `#privacy` | Privacy page | Present |
| fallback | Branded 404 state | Present |

Global links include the BookLocal logo to `#home`, Explore to `#discover`, For businesses/List your business to `#business`, My bookings to `#account`, and footer links to About, Contact, Terms, and Privacy.

## Prototype data found and removed

The original front-end contained three hard-coded service/business records: Moss & Mane, Body Bloom Studio, and Harbour Pilates. It also contained an eight-item hard-coded time-slot array, browser `localStorage` booking persistence, generated local booking IDs, hard-coded dashboard totals derived from that browser storage, a hard-coded profile-view count of 248, and a hard-coded 4.9 rating. These records and persistence paths were removed.

The cleaned UI now renders live-data empty states instead of pretending that businesses, services, customers, bookings, ratings, or revenue exist. The booking form remains as a validated interface, but its submit action is explicitly marked TODO until it can call the database and Paystack securely.

## TODO controls

Database-dependent actions are visibly disabled or labelled TODO, including booking submission, business service management, booking export, admin customer management, and admin reports. No fake booking, cancellation, rescheduling, review, payment, or analytics action is presented as working.

## Supabase migration

`supabase/schema.sql` defines the requested tables:

- `customers`
- `businesses`
- `services`
- `business_hours`
- `blocked_times`
- `bookings`
- `reviews`
- `favourites`
- `payments`

It also defines booking and payment status types, foreign keys, validation constraints, RLS enablement and baseline authenticated-user policies. The migration includes `check_availability(business_id, date, start, end)`, which checks pending/confirmed/rescheduled bookings and blocked times with interval overlap checks. A GiST exclusion constraint provides database-level protection against concurrent double-booking. A trigger prevents reviews unless the linked booking is completed and belongs to the same customer and business.

## Provisioning status

The Supabase and Supabase API connectors were disabled in this session. Therefore, no hosted Supabase project was created or modified. Run `supabase/schema.sql` in the authorized Supabase SQL Editor or enable the project's Supabase connector before claiming the database is provisioned.

The production timezone must be configured as `Africa/Johannesburg` in the Supabase project and application runtime. Paystack test keys must be added through secure project secrets; they must not be placed in this repository.
