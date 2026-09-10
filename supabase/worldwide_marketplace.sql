-- BookLocal worldwide marketplace update
-- Existing businesses.city is free text; this adds global currency and map coordinates.
alter table public.businesses add column if not exists currency text not null default 'ZAR';
alter table public.businesses drop constraint if exists businesses_currency_check;
alter table public.businesses add constraint businesses_currency_check check (currency in ('ZAR','USD','GBP','EUR','NGN','KES','AUD','CAD','INR','Other'));
alter table public.businesses add column if not exists latitude double precision;
alter table public.businesses add column if not exists longitude double precision;

update public.businesses set name='PMB Cuts', category='Barber', city='Pietermaritzburg', address='Scottsville', currency='ZAR', price_from=20, latitude=-29.8587, longitude=30.3679, is_active=true where id='11111111-1111-4111-8111-111111111111';

do $$
declare
  v_durban uuid;
  v_london uuid;
begin
  select id into v_durban from public.businesses where name='Durban Braids' limit 1;
  if v_durban is null then
    insert into public.businesses(email,name,category,city,address,description,is_active,is_suspended,price_from,currency,latitude,longitude)
    values('durban.demo@booklocal.global','Durban Braids','Braiding','Durban','Durban, South Africa','Braiding services in Durban.',true,false,20,'ZAR',-29.8587,31.0218)
    returning id into v_durban;
  end if;
  update public.businesses set category='Braiding',city='Durban',address='Durban, South Africa',currency='ZAR',price_from=20,latitude=-29.8587,longitude=31.0218,is_active=true where id=v_durban;
  insert into public.services(business_id,name,price,duration_minutes,is_active) select v_durban,'Braiding',20,60,true where not exists(select 1 from public.services where business_id=v_durban and name='Braiding');

  select id into v_london from public.businesses where name='London Cuts' limit 1;
  if v_london is null then
    insert into public.businesses(email,name,category,city,address,description,is_active,is_suspended,price_from,currency,latitude,longitude)
    values('london.demo@booklocal.global','London Cuts','Barber','London','London, United Kingdom','A local barber service in London.',true,false,20,'GBP',51.5072,-0.1276)
    returning id into v_london;
  end if;
  update public.businesses set category='Barber',city='London',address='London, United Kingdom',currency='GBP',price_from=20,latitude=51.5072,longitude=-0.1276,is_active=true where id=v_london;
  insert into public.services(business_id,name,price,duration_minutes,is_active) select v_london,'Haircut',20,30,true where not exists(select 1 from public.services where business_id=v_london and name='Haircut');
end $$;

update public.businesses set is_active=false where id in ('22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333');
