-- Foundation data - always needed
-- Users and basic system setup

INSERT INTO users (id, email, role) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'admin@phytopi.local', 'admin'),
    ('550e8400-e29b-41d4-a716-446655440002', 'developer@phytopi.local', 'researcher')
ON CONFLICT (email) DO NOTHING;

SELECT 'Foundation data loaded' as status;
