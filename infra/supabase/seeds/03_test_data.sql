-- Test data - sample readings and alerts
-- Only load when testing

INSERT INTO readings (sensor_id, timestamp, value, unit, metadata) VALUES
    ('770e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '1 hour', 22.5, 'celsius', '{"quality": "good", "battery": 100}'),
    ('770e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '2 hours', 22.3, 'celsius', '{"quality": "good", "battery": 100}'),
    ('770e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '3 hours', 22.7, 'celsius', '{"quality": "good", "battery": 100}'),
    ('770e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '1 hour', 65.2, 'percent', '{"quality": "good", "battery": 100}'),
    ('770e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '2 hours', 64.8, 'percent', '{"quality": "good", "battery": 100}'),
    ('770e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '3 hours', 66.1, 'percent', '{"quality": "good", "battery": 100}')
ON CONFLICT DO NOTHING;

INSERT INTO alerts (device_id, sensor_id, type, triggered_at, message, severity, metadata) VALUES
    ('660e8400-e29b-41d4-a716-446655440001', '770e8400-e29b-41d4-a716-446655440001', 'threshold_exceeded', NOW() - INTERVAL '2 hours', 'Temperature approaching upper limit', 'medium', '{"threshold": 25.0, "current_value": 24.5, "unit": "celsius"}')
ON CONFLICT DO NOTHING;

SELECT 'Test data loaded' as status;