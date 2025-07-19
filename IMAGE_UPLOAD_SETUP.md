# Image Upload Setup Guide

## Problem
The image upload feature is not working in your Nature Peaks app. This guide will help you fix it.

## Root Cause
The issue is likely that the Supabase storage bucket and policies are not properly configured.

## Solution Steps

### 1. Set Up Supabase Storage

1. **Go to your Supabase Dashboard**
   - Navigate to your project
   - Go to the "Storage" section in the left sidebar

2. **Create the Storage Bucket**
   - Click "Create a new bucket"
   - Name: `post-images`
   - Make it **Public** (check the box)
   - Set file size limit to `10485760` (10MB)
   - Click "Create bucket"

3. **Set Up Storage Policies**
   - Run the SQL script in `storage_setup.sql` in your Supabase SQL Editor
   - This will create the necessary RLS policies

### 2. Set Up Storage Bucket (Dashboard Method)

**Option A: Using Supabase Dashboard (Recommended)**

1. **Go to Storage in Supabase Dashboard**
   - Navigate to your project
   - Click "Storage" in the left sidebar

2. **Create the Bucket**
   - Click "Create a new bucket"
   - Name: `post-images`
   - Check "Public bucket" (this allows public read access)
   - Click "Create bucket"

3. **Configure Bucket Settings**
   - Click on the `post-images` bucket
   - Go to "Settings" tab
   - Set "File size limit" to `10485760` (10MB)
   - Set "Allowed MIME types" to: `image/jpeg, image/png, image/gif, image/webp`
   - Save changes

**Option B: Using SQL (Alternative)**

If the dashboard method doesn't work, try this SQL:

```sql
-- Create the storage bucket for post images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post-images',
  'post-images',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;
```

### 3. Set Up Storage Policies

After creating the bucket, run this SQL in your Supabase SQL Editor:

```sql
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
```

### 3. Test the Storage Setup

1. **Run the app** and navigate to `/debug/storage` in your browser
2. **Click "Test Storage Connection"** to verify the setup
3. **Check the console logs** for detailed information

### 4. Verify Environment Variables

Make sure your `.env` file has the correct Supabase credentials:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 5. Test Image Upload

1. **Go to the Post screen** in your app
2. **Try uploading an image** (gallery or camera)
3. **Check the console logs** for any error messages

## Troubleshooting

### Common Issues:

1. **"Bucket not found" error**
   - Make sure the `post-images` bucket exists in Supabase Storage
   - Check the bucket name spelling

2. **"Permission denied" error**
   - Run the storage setup SQL script
   - Check that RLS policies are enabled

3. **"File too large" error**
   - The file size limit is 10MB
   - Try compressing the image or using a smaller file

4. **"Invalid file type" error**
   - Only JPG, PNG, GIF, and WebP files are allowed
   - Check the file extension

### Debug Steps:

1. **Check console logs** for detailed error messages
2. **Use the debug screen** at `/debug/storage`
3. **Verify Supabase connection** in the main app
4. **Test with a small image** first

## Code Changes Made

The following improvements were made to the image upload code:

1. **Better error handling** with detailed logging
2. **File validation** (size, type, extension)
3. **Image compression** for better performance
4. **Progress feedback** during upload
5. **Dedicated storage service** for better organization
6. **Debug screen** for testing storage setup

## Next Steps

After fixing the storage setup:

1. **Test the image upload** functionality
2. **Remove the debug route** from production
3. **Consider adding image optimization** for better performance
4. **Add image deletion** when posts are deleted

## Support

If you're still having issues:

1. Check the Supabase documentation on storage
2. Verify your project's storage settings
3. Check the browser console for error messages
4. Test with the debug screen to isolate the issue 