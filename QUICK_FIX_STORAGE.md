# Quick Fix for Storage Permission Error

## The Error
```
ERROR: 42501: must be owner of table objects
```

This error occurs because you're trying to modify the `storage.objects` table directly, which is managed by Supabase.

## Quick Fix Steps

### Step 1: Create Bucket via Dashboard (Recommended)

1. **Go to Supabase Dashboard**
   - Open your project
   - Click "Storage" in the left sidebar

2. **Create Bucket**
   - Click "Create a new bucket"
   - Name: `post-images`
   - ✅ Check "Public bucket"
   - Click "Create bucket"

3. **Configure Settings**
   - Click on the `post-images` bucket
   - Go to "Settings" tab
   - Set file size limit to `10485760` (10MB)
   - Set allowed MIME types to: `image/jpeg, image/png, image/gif, image/webp`

### Step 2: Add Policies via SQL

Run this SQL in your Supabase SQL Editor:

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

### Step 3: Test

1. Run your app
2. Go to `/debug/storage` in your browser
3. Click "Test Storage Connection"
4. If successful, try uploading an image

## Alternative: If Dashboard Method Fails

If you can't create the bucket via dashboard, try this SQL:

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

Then run the policies SQL above.

## Why This Error Happens

- The `storage.objects` table is managed by Supabase
- You can't directly modify it with `ALTER TABLE`
- You can only create policies on it
- RLS is already enabled by default

## Success Indicators

After following these steps, you should see:
- ✅ Bucket `post-images` exists in Storage
- ✅ Storage test passes at `/debug/storage`
- ✅ Image upload works in the Post screen
- ✅ No permission errors in console 