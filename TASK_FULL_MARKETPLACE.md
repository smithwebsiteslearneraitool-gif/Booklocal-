# Full marketplace implementation

## Delivered

BookLocal now uses the locked off-white, hot-pink, mint, light-pink and black design system across the homepage, business pages, booking form, account pages, dashboards and admin page. The homepage includes the original hero, search and Pietermaritzburg selector, category filters, nearby map section, community card, business cards and footer links.

The marketplace reads active businesses and services from Supabase and includes the seeded PMB Cuts, PMB Beauty Spot and PMB Plumbing Help listings. Business pages show live services, prices in ZAR, duration and ratings. Booking is service-first, date-constrained, timezone-aware and pay-at-venue only. All public marketplace prices display a minimum of From R20, while businesses can set any starting price at or above R20.

Customer authentication and business authentication use Supabase Auth. Profiles store roles, customer sign-up records are mirrored into the legacy customers table for foreign-key compatibility, and admin roles cannot be created through public sign-up. Customer routes are protected by the customer profile; business dashboard access requires a business profile; admin.html requires an admin profile.

Booking creation, cancellation and rescheduling use security-definer Supabase RPCs. Booking creation locks the business/date pair, derives the service price from the database, rechecks availability and inserts a confirmed appointment. Cancellation frees the slot. Rescheduling locks the target business/date pair and rechecks bookings and blocked times. Reviews are restricted to completed bookings and are unique per booking; business rating averages refresh automatically.

## Verification

The production build passed with `pnpm run build`. Public REST reads returned three active Pietermaritzburg businesses and six active services. The availability RPC returned an open future slot for PMB Cuts and verified six open days plus Sunday closed. An unauthenticated booking RPC was rejected with `Sign in required`. Visual verification covered the homepage, business page, booking page, auth page and customer dashboard.

## Seeded records

| Business | Category | Area | Services |
|---|---|---|---|
| PMB Cuts | Barber | Scottsville | Haircut — From R20 / 30 minutes; Beard — From R20 / 15 minutes |
| PMB Beauty Spot | Beauty | Hayfields | Gel Nails — From R20 / 60 minutes; Lashes — From R20 / 90 minutes |
| PMB Plumbing Help | Plumbing | Central PMB | Leak Repair — From R20 / 60 minutes; Geyser — From R20 / 45 minutes |

All three businesses operate Monday–Saturday from 08:00–18:00 and are closed Sunday.

## Remaining launch configuration

A real admin user must be assigned `role='admin'` directly in Supabase by an authorized operator; public sign-up cannot create admins. Google Maps continues to use the existing Forge proxy configuration; a valid map key/proxy configuration is required for live tiles. Password reset remains marked TODO. Business owners can register and access the protected dashboard; service, hour and blocked-time editing should be the next business-dashboard feature before onboarding real businesses.
