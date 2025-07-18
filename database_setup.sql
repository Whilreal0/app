-- Check if comment_likes table exists and create if missing
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'comment_likes') THEN
        CREATE TABLE comment_likes (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(comment_id, user_id)
        );
        
        -- Enable RLS on comment_likes table
        ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;
        
        -- Create RLS policies for comment_likes
        CREATE POLICY "Users can view all comment likes" ON comment_likes
            FOR SELECT USING (true);

        CREATE POLICY "Users can insert their own comment likes" ON comment_likes
            FOR INSERT WITH CHECK (auth.uid() = user_id);

        CREATE POLICY "Users can delete their own comment likes" ON comment_likes
            FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- Create or replace function to update comment like count
CREATE OR REPLACE FUNCTION update_comment_like_count(comment_id UUID, increment INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE comments 
    SET likes_count = GREATEST(0, likes_count + increment)
    WHERE id = comment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION update_comment_like_count(UUID, INTEGER) TO authenticated; 