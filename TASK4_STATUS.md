# TASK 4 status

Three test businesses were created in the active Booklocal Supabase project for Pietermaritzburg, KwaZulu-Natal:

- uMgeni Beauty Studio — 2 services
- Midlands Massage & Wellness — 2 services
- Capital Pilates PMB — 2 services

Verification returned 3 businesses, 6 services, and 15 weekly business-hour records. All are active and use South African Rand pricing.

The managed WebDev preview homepage fetches active businesses and services from Supabase REST using the public publishable key. It includes live loading, error/retry, category filtering, search, service counts, PMB location copy, ZAR formatting, and service detail dialogs. No mock marketplace records are used.

The live preview is available at the WebDev preview URL reported in the TASK 4 delivery. The GitHub root source has also been localized to Pietermaritzburg and ZAR and triggers the live Supabase service load on the homepage.

Timezone is Africa/Johannesburg in the Supabase migration and availability client. Server-only Supabase service and Paystack secrets remain intentionally absent from browser code.
