-- Development data - sample devices and sensors
-- Only load when developing/testing

INSERT INTO devices (id, name, type, location, status) VALUES
    ('660e8400-e29b-41d4-a716-446655440001', 'PhytoPi-Prototype-001', 'phyto_pi', 'Development Lab', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO sensors (id, device_id, type, calibration_data) VALUES
    ('770e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', 'temperature', '{"offset": 0.0, "scale": 1.0, "unit": "celsius"}'),
    ('770e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440001', 'humidity', '{"offset": 0.0, "scale": 1.0, "unit": "percent"}'),
    ('770e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440001', 'light', '{"offset": 0.0, "scale": 1.0, "unit": "lux"}'),
    ('770e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440001', 'soil_moisture', '{"offset": 0.0, "scale": 1.0, "unit": "percent"}')
ON CONFLICT (id) DO NOTHING;

SELECT 'Development data loaded' as status;