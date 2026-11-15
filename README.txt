APNA JOB HUB - QUICK SETUP

Files:
1) index.html   - website frontend
2) setup.sql    - database tables, login profile trigger, and Row Level Security

STEP A - Supabase
1. Open https://supabase.com and open your existing project (or create a free one).
2. Open SQL Editor > New query.
3. Paste all of setup.sql and click Run.
4. Open Project Settings > API (or Connect). Copy the Project URL and the Publishable key / anon public key.
   NEVER use the secret key or service_role key in the website.

STEP B - Add keys
1. Open index.html in a text editor.
2. Find SUPABASE_URL and SUPABASE_ANON_KEY near the bottom.
3. Replace the two PASTE... values with your Project URL and Publishable/anon public key.
4. Save index.html.

STEP C - Make your admin account
1. Register on your website using the email you want as admin.
2. In Supabase SQL Editor, run this query after replacing the email:
   update public.profiles
   set role = 'admin'
   where id = (select id from auth.users where email = 'YOUR_EMAIL_HERE');
3. Log out and log in again. Admin Approval tab will appear.

STEP D - Publish free
1. Create a GitHub repository.
2. Upload index.html to the repository root.
3. Open repository Settings > Pages.
4. Choose Deploy from a branch, select main and /(root), Save.
5. Open the published GitHub Pages URL.

NOTES
- Candidate accounts can search/apply. Recruiter accounts can post jobs.
- New jobs stay pending until admin approves them.
- Email confirmation settings may require users to verify email before login.
- This is a starter portal, not a byte-for-byte copy of WorkIndia. Do not use WorkIndia branding or proprietary assets.
- Free tiers have quotas and can change.
- Do not put a Supabase secret/service_role key in index.html.
- For production, add spam protection, stronger recruiter verification, privacy policy, terms, and backups.
