-- Demo data - for presentations and demos
-- Only load when demonstrating

INSERT INTO devices (id, name, type, location, status) VALUES
    ('660e8400-e29b-41d4-a716-446655440002', 'PhytoPi-Demo-001', 'phyto_pi', 'Demo Room', 'active'),
    ('660e8400-e29b-41d4-a716-446655440003', 'PhytoPi-Demo-002', 'phyto_pi', 'Demo Room', 'active')
ON CONFLICT (id) DO NOTHING;

-- Add more demo sensors and data here...

SELECT 'Demo data loaded' as status;