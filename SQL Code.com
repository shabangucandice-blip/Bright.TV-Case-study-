
--------------------------------------
QUERY RAN ON THE VIEWERSHIP DATASET
--------------------------------------
select * from `workspace`.`default`.`book_3_view` limit 100;
--convert record_date_sast to 01 january 2016 format
select 
  *,
  date_format(
    cast(`RecordDate2` as timestamp),
    'dd MMMM yyyy'
  ) as formatted_record_date
from `workspace`.`default`.`book_3_view`
limit 100;

--convert record_time_sast
select 
  *,
  date_format(cast(`RecordDate2` AS timestamp ), 'HH:mm:ss') AS formatted_record_time
from `workspace`.`default`.`book_3_view`
limit 100;
--convert to sast
select 
  *,
  date_format(
    from_utc_timestamp(cast(`RecordDate2` as timestamp), 'Africa/Johannesburg'),
    'HH:mm:ss'
  ) as formatted_record_time_sast
from `workspace`.`default`.`book_3_view`
limit 100;
--check min date 
select min(`RecordDate2`) as min_record_date from `workspace`.`default`.`book_3_view`;
--check max date
select max(`RecordDate2`) as max_record_date from `workspace`.`default`.`book_3_view`;

--check the unique channels @Bright-tv
select distinct Channel2 from `workspace`.`default`.`book_3_view`;


---------------------------------------------------------------------------------------
select 
  UserID,
  Channel2,
  date_format(
    cast(`RecordDate2` as timestamp),
    'dd MM yyyy'
  ) as formatted_record_date,
  date_format(
    from_utc_timestamp(
      cast(`RecordDate2` as timestamp),
      'Africa/Johannesburg'
    ),
    'HH:mm:ss'
  ) as formatted_record_time_sast,
  date_format(
    cast(`RecordDate2` as timestamp),
    'HH:mm:ss'
  ) as formatted_record_time
from `workspace`.`default`.`book_3_view`

-----------------------------------------------------------------
  
Query Ran on the Subscribers datset 
------------------------------------------------------------------


select * from `kenzowealth`.`default`.`Subscribers_5`;

--Check number of provinces 
select distinct Province from `kenzowealth`.`default`.`Subscribers_5`;

-- Address none values under the column -Province 

SELECT 
  CASE 
    WHEN LOWER(TRIM(Province)) = 'none' THEN 'Unknown'
    ELSE Province
  END AS Province
FROM `kenzowealth`.`default`.`Subscribers_5`;


--Fix casing on the column -Race

UPDATE `kenzowealth`.`default`.`Subscribers_5`
SET Race = CASE
    WHEN LOWER(TRIM(Race)) = 'white' THEN 'White'
    WHEN LOWER(TRIM(Race)) = 'black' THEN 'Black'
    WHEN LOWER(TRIM(Race)) = 'coloured' THEN 'Colored'
    WHEN LOWER(TRIM(Race)) = 'other' THEN 'Other'
    WHEN LOWER(TRIM(Race)) = 'indian_asian' THEN 'Indian_Asian'
    ELSE Race
END; 
-----------------------------------------

--replace none values under gender with other and fix casing 

UPDATE `kenzowealth`.`default`.`Subscribers_5`
SET Gender = CASE
    WHEN LOWER(TRIM(Gender)) = 'male' THEN 'Male'
    WHEN LOWER(TRIM(Gender)) = 'female' THEN 'Female'
    WHEN LOWER(TRIM(Gender)) = 'none' THEN 'Other'
    ELSE Gender
END;
-------------------------------------------------------------------------
SELECT 
  UserID,
  Age,
  CASE 
    WHEN LOWER(TRIM(Province)) = 'none' THEN 'Unknown'
    ELSE Province
  END AS Province,
  CASE
    WHEN LOWER(TRIM(Race)) = 'white' THEN 'White'
    WHEN LOWER(TRIM(Race)) = 'black' THEN 'Black'
    WHEN LOWER(TRIM(Race)) = 'coloured' THEN 'Colored'
    WHEN LOWER(TRIM(Race)) = 'other' THEN 'Other'
    WHEN LOWER(TRIM(Race)) = 'indian_asian' THEN 'Indian_Asian'
    ELSE Race
  END AS Race,
  CASE
    WHEN LOWER(TRIM(Gender)) = 'male' THEN 'Male'
    WHEN LOWER(TRIM(Gender)) = 'female' THEN 'Female'
    WHEN LOWER(TRIM(Gender)) = 'none' THEN 'Other'
    ELSE Gender
  END AS Gender
FROM `kenzowealth`.`default`.`Subscribers_5`;


-----------------------------------------------------------------------
  Big Query on my (Left Joined ) tables 
-----------------------------------------------------------------------


select * from `workspace`.`default`.`Ishe_an_view` limit 100;
select * from `workspace`.`default`.`Ishe_subscribers0` limit 100;

select 
  --Join my tables using left join (Base table.
  v.*,
  s.Age,
  s.Province,
  s.Race,
  s.Gender
from `workspace`.`default`.`Ishe_an_view` v
left join `workspace`.`default`.`Ishe_subscribers0` s
  on v.UserID = s.UserID;


-----------------------------------------------------------------------------

SELECT 
  v.UserID,
  v.Channel2 as Channel,
  v.record_date_sast,
  v.record_time_sast,
  
  -- Keep original HH:MM:SS format for Excel pivoting
  v.`Duration 2` as Duration,
  
  -- Subscriber Demographics (with NULL handling)
  
COALESCE(s.Age, 32) as Age,
  COALESCE(s.Province, 'unkown') as Province,
  COALESCE(s.Race, 'Other') as Race,
  COALESCE(s.Gender, 'Unknown') as Gender,
  
 
-- Date/Time Enrichments
 
TO_DATE(v.record_date_sast, 'd-MMM-yyyy') as Record_Date,
  DATE_FORMAT(TO_DATE(v.record_date_sast, 'd-MMM-yyyy'), 'EEEE') as Day_of_Week,
  DATE_FORMAT(TO_DATE(v.record_date_sast, 'd-MMM-yyyy'), 'MMMM') as Month_Name,
  
  -- Time Buckets
  CASE 
    WHEN CAST(SUBSTRING(v.record_time_sast, 1, 2) AS INT) BETWEEN 5 AND 11 THEN '1. Morning (5AM-11AM)'
    WHEN CAST(SUBSTRING(v.record_time_sast, 1, 2) AS INT) BETWEEN 12 AND 16 THEN '2. Afternoon (12PM-4PM)'
    WHEN CAST(SUBSTRING(v.record_time_sast, 1, 2) AS INT) BETWEEN 17 AND 21 THEN '3. Evening (5PM-9PM)'
    ELSE '4. Night (10PM-4AM)'
  END as Time_Bucket,
  
  -- Age Bands (with NULL handling)
  CASE 
    WHEN s.Age IS NULL THEN '8. Unknown'
    WHEN s.Age < 18 THEN 'Minors. Under 18'
    WHEN s.Age BETWEEN 18 AND 24 THEN 'Young adults. 18-24' 
    WHEN s.Age BETWEEN 25 AND 34 THEN 'Millennials. 25-34'
    WHEN s.Age BETWEEN 35 AND 44 THEN 'Established. 35-44'
    WHEN s.Age BETWEEN 45 AND 54 THEN 'Mature adults. 45-54'
    WHEN s.Age BETWEEN 55 AND 64 THEN 'Pre-retirement. 55-64'
    WHEN s.Age BETWEEN 65 AND 89 THEN 'Retirement. 65-89'
    WHEN s.Age BETWEEN 90 AND 114 THEN 'Golden'
    ELSE '8. Unknown'
  END as Age_Band,
  
  -- Weekend Flag
  
CASE 
    WHEN DAYOFWEEK(TO_DATE(v.record_date_sast, 'd-MMM-yyyy')) IN (1, 7) THEN 'Weekend'
    ELSE 'Weekday'
  END as Day_Type

FROM `workspace`.`default`.`Ishe_an_view` v
LEFT JOIN `workspace`.`default`.`Ishe_subscribers0` s
  ON v.UserID = s.UserID;























