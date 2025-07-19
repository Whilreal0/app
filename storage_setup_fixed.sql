-- Storage bucket setup for image uploads (Fixed for Supabase permissions)
-- Run this in your Supabase SQL editor

-- Create the storage bucket for post images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post-images',
  'post-images',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Note: RLS is already enabled on storage.objects by Supabase
-- We just need to create the policies

-- Policy to allow authenticated users to upload images
CREATE POLICY "Allow authenticated users to upload images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'post-images' 
    AND auth.role() = 'authenticated'
  );

-- Policy to allow public read access to images
CREATE POLICY "Allow public read access to images" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'post-images'
  );

-- Policy to allow users to update their own uploaded images
CREATE POLICY "Allow users to update their own images" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'post-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy to allow users to delete their own uploaded images
CREATE POLICY "Allow users to delete their own images" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'post-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  ); 