-- ============================================================================
-- 002_delete_my_account.sql
-- ----------------------------------------------------------------------------
-- In-app account deletion (App Store Review Guideline 5.1.1(v)).
-- Called from Profile > Delete account via supabase.rpc('delete_my_account').
-- Deletes everything tied to the signed-in user, then the auth user itself.
-- Runs as one transaction: if any delete fails, nothing is deleted.
--
-- Beyond the rows that belong to the user (their swipes, job swipes, messages
-- they sent, certifications, endorsements and ratings they wrote, profile and
-- users row) it also removes rows that point AT the user: swipes on them,
-- endorsements and ratings about them, their matches with the rest of those
-- conversations, and jobs they posted with the swipes on those jobs. That way
-- no foreign key can block the delete, and other users never see a match or a
-- job from an account that no longer exists.
--
-- Uploaded photo files are not touched here (Supabase blocks direct SQL
-- deletes on storage.objects). The app removes them through the Storage API
-- right after this function succeeds.
-- ============================================================================

begin;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  -- Messages they sent, then the rest of their conversations.
  delete from public.chat_messages where sender_id = v_uid;
  delete from public.chat_messages
   where match_id in (select id from public.matches
                       where journeyman_id = v_uid or helper_id = v_uid);

  -- Swipes by them and on them.
  delete from public.swipes where swiper_id = v_uid or swiped_id = v_uid;

  -- Job swipes by them and on jobs they posted.
  delete from public.job_swipes
   where user_id = v_uid
      or job_id in (select id from public.jobs where journeyman_id = v_uid);

  -- Endorsements and ratings they wrote, and those written about them.
  delete from public.endorsements where from_user_id = v_uid or to_user_id = v_uid;
  delete from public.ratings      where from_user_id = v_uid or to_user_id = v_uid;

  -- Their matches, then the jobs they posted.
  delete from public.matches where journeyman_id = v_uid or helper_id = v_uid;
  update public.matches set job_id = null
   where job_id in (select id from public.jobs where journeyman_id = v_uid);
  delete from public.jobs where journeyman_id = v_uid;

  delete from public.certifications where user_id = v_uid;
  delete from public.profiles       where user_id = v_uid;
  delete from public.users          where id = v_uid;

  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
revoke all on function public.delete_my_account() from anon;
grant execute on function public.delete_my_account() to authenticated;

commit;

select '002_delete_my_account.sql' as migration_applied;
