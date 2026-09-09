# TASK 3 status

The active Supabase project is `Booklocal` (`fohsdblvlgeijzpbjhle`) in `eu-west-1`. The `task3_booking_core` migration was applied successfully, and the `bookings_no_overlap` exclusion constraint and public `check_availability` function are present.

The browser now imports the Supabase JavaScript client from `supabase-client.js`, loads live services through the public publishable key, and computes available slots using business hours, service duration, active bookings, blocked times, and the `Africa/Johannesburg` timezone. No businesses or services are seeded.

The browser does not contain service keys or Paystack secret keys. A server-side API is still required for JWT/session policy, transactional booking inserts, Paystack verification, webhook handling, refunds, cancellation notifications, and secure secret storage. These values belong in the secure environment configuration described in `.env.example`.

The static booking form validates input and live slot loading is connected; final booking submission remains explicitly marked TODO until the server endpoint exists. This is intentional: a browser must not receive `SUPABASE_SERVICE_KEY` or `PAYSTACK_SECRET_KEY`, and it must not claim a payment is verified without server-side verification.
