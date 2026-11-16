-- ════════════════════════════════════════════════════════════════════
--  Vally Business — 6/6 : photos des articles (Supabase Storage)
--
--  Bucket privé « photos-articles ». Chemin des fichiers :
--    <boutique_id>/<article_id>.jpg
--  Chaque membre ne lit et n'écrit que dans le dossier de sa boutique.
--  L'appli affiche les photos avec des URL signées.
-- ════════════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos-articles', 'photos-articles', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

create policy photos_articles_select on storage.objects
  for select to authenticated
  using (bucket_id = 'photos-articles'
         and (storage.foldername(name))[1] = (select private.ma_boutique())::text);

create policy photos_articles_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos-articles'
              and (storage.foldername(name))[1] = (select private.ma_boutique())::text);

create policy photos_articles_update on storage.objects
  for update to authenticated
  using (bucket_id = 'photos-articles'
         and (storage.foldername(name))[1] = (select private.ma_boutique())::text)
  with check (bucket_id = 'photos-articles'
              and (storage.foldername(name))[1] = (select private.ma_boutique())::text);

create policy photos_articles_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos-articles'
         and (storage.foldername(name))[1] = (select private.ma_boutique())::text);
