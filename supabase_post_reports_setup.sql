-- Create post_reports table
CREATE TABLE IF NOT EXISTS post_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_resolved BOOLEAN DEFAULT FALSE,
  resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at TIMESTAMP WITH TIME ZONE,
  resolution TEXT,
  
  -- Ensure one report per user per post
  UNIQUE(post_id, reporter_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_post_reports_post_id ON post_reports(post_id);
CREATE INDEX IF NOT EXISTS idx_post_reports_reporter_id ON post_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_post_reports_is_resolved ON post_reports(is_resolved);
CREATE INDEX IF NOT EXISTS idx_post_reports_created_at ON post_reports(created_at);

-- Enable Row Level Security
ALTER TABLE post_reports ENABLE ROW LEVEL SECURITY;

-- Policy: Users can create reports
CREATE POLICY "Users can create post reports" ON post_reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- Policy: Users can view their own reports
CREATE POLICY "Users can view their own reports" ON post_reports
  FOR SELECT USING (auth.uid() = reporter_id);

-- Policy: Admins, moderators, and superadmins can view all reports
CREATE POLICY "Moderators can view all reports" ON post_reports
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('admin', 'moderator', 'superadmin')
    )
  );

-- Policy: Admins, moderators, and superadmins can update reports (resolve them)
CREATE POLICY "Moderators can update reports" ON post_reports
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('admin', 'moderator', 'superadmin')
    )
  );

-- Policy: Admins, moderators, and superadmins can delete reports
CREATE POLICY "Moderators can delete reports" ON post_reports
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('admin', 'moderator', 'superadmin')
    )
  );

-- Function to automatically set post_owner_id when creating a report
CREATE OR REPLACE FUNCTION set_post_owner_id()
RETURNS TRIGGER AS $$
BEGIN
  SELECT user_id INTO NEW.post_owner_id
  FROM posts
  WHERE id = NEW.post_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically set post_owner_id
CREATE TRIGGER set_post_owner_id_trigger
  BEFORE INSERT ON post_reports
  FOR EACH ROW
  EXECUTE FUNCTION set_post_owner_id(); 