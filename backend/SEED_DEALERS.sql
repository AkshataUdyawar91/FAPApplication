-- =============================================
-- Seed: Sample Dealers data
-- Run AFTER ADD_DEALER_STATECITY_TABLES.sql
-- =============================================

SET NOCOUNT ON;

-- Clear existing seed data (optional, comment out if you want to keep existing)
-- DELETE FROM Dealers;

INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), DealerCode, DealerName, State, City, 1, 0, GETUTCDATE()
FROM (VALUES
    ('DL001', 'Bajaj Auto Mumbai Central',     'Maharashtra', 'Mumbai'),
    ('DL002', 'Bajaj Auto Pune West',           'Maharashtra', 'Pune'),
    ('DL003', 'Bajaj Auto Nagpur',              'Maharashtra', 'Nagpur'),
    ('DL004', 'Bajaj Auto Nashik',              'Maharashtra', 'Nashik'),
    ('DL005', 'Bajaj Auto Delhi North',         'Delhi',       'New Delhi'),
    ('DL006', 'Bajaj Auto Delhi South',         'Delhi',       'New Delhi'),
    ('DL007', 'Bajaj Auto Gurugram',            'Haryana',     'Gurugram'),
    ('DL008', 'Bajaj Auto Faridabad',           'Haryana',     'Faridabad'),
    ('DL009', 'Bajaj Auto Bengaluru Central',   'Karnataka',   'Bengaluru'),
    ('DL010', 'Bajaj Auto Bengaluru East',      'Karnataka',   'Bengaluru'),
    ('DL011', 'Bajaj Auto Mysuru',              'Karnataka',   'Mysuru'),
    ('DL012', 'Bajaj Auto Chennai Central',     'Tamil Nadu',  'Chennai'),
    ('DL013', 'Bajaj Auto Chennai South',       'Tamil Nadu',  'Chennai'),
    ('DL014', 'Bajaj Auto Coimbatore',          'Tamil Nadu',  'Coimbatore'),
    ('DL015', 'Bajaj Auto Hyderabad Central',   'Telangana',   'Hyderabad'),
    ('DL016', 'Bajaj Auto Hyderabad West',      'Telangana',   'Hyderabad'),
    ('DL017', 'Bajaj Auto Secunderabad',        'Telangana',   'Secunderabad'),
    ('DL018', 'Bajaj Auto Kolkata North',       'West Bengal', 'Kolkata'),
    ('DL019', 'Bajaj Auto Kolkata South',       'West Bengal', 'Kolkata'),
    ('DL020', 'Bajaj Auto Ahmedabad',           'Gujarat',     'Ahmedabad'),
    ('DL021', 'Bajaj Auto Surat',               'Gujarat',     'Surat'),
    ('DL022', 'Bajaj Auto Vadodara',            'Gujarat',     'Vadodara'),
    ('DL023', 'Bajaj Auto Jaipur',              'Rajasthan',   'Jaipur'),
    ('DL024', 'Bajaj Auto Jodhpur',             'Rajasthan',   'Jodhpur'),
    ('DL025', 'Bajaj Auto Lucknow',             'Uttar Pradesh','Lucknow'),
    ('DL026', 'Bajaj Auto Kanpur',              'Uttar Pradesh','Kanpur'),
    ('DL027', 'Bajaj Auto Agra',                'Uttar Pradesh','Agra'),
    ('DL028', 'Bajaj Auto Bhopal',              'Madhya Pradesh','Bhopal'),
    ('DL029', 'Bajaj Auto Indore',              'Madhya Pradesh','Indore'),
    ('DL030', 'Bajaj Auto Patna',               'Bihar',       'Patna')
) AS T(DealerCode, DealerName, State, City)
WHERE NOT EXISTS (
    SELECT 1 FROM Dealers d WHERE d.DealerCode = T.DealerCode
);

PRINT CAST(@@ROWCOUNT AS NVARCHAR) + ' dealer(s) inserted.';
