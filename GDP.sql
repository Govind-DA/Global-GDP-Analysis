create Database GDP;
use GDP;

SET SQL_SAFE_UPDATES = 0;

UPDATE GDP
SET 
    gdp_2020 = CASE WHEN gdp_2020 IS NULL OR TRIM(gdp_2020) = '' THEN '0' ELSE gdp_2020 END,
    gdp_2021 = CASE WHEN gdp_2021 IS NULL OR TRIM(gdp_2021) = '' THEN '0' ELSE gdp_2021 END,
    gdp_2022 = CASE WHEN gdp_2022 IS NULL OR TRIM(gdp_2022) = '' THEN '0' ELSE gdp_2022 END,
    gdp_2023 = CASE WHEN gdp_2023 IS NULL OR TRIM(gdp_2023) = '' THEN '0' ELSE gdp_2023 END,
    gdp_2024 = CASE WHEN gdp_2024 IS NULL OR TRIM(gdp_2024) = '' THEN '0' ELSE gdp_2024 END,
    gdp_2025 = CASE WHEN gdp_2025 IS NULL OR TRIM(gdp_2025) = '' THEN '0' ELSE gdp_2025 END;


ALTER TABLE GDP
MODIFY COLUMN gdp_2020 DECIMAL(15,2),
MODIFY COLUMN gdp_2021 DECIMAL(15,2),
MODIFY COLUMN gdp_2022 DECIMAL(15,2),
MODIFY COLUMN gdp_2023 DECIMAL(15,2),
MODIFY COLUMN gdp_2024 DECIMAL(15,2),
MODIFY COLUMN gdp_2025 DECIMAL(15,2);

-- --------------------------------------------------------------------------------------------------------

-- Added new column for Average GDP
ALTER TABLE GDP
ADD COLUMN avg_gdp DECIMAL(15,2);

-- Updated average gdp 
UPDATE GDP
SET avg_gdp = ROUND((
    (CASE WHEN gdp_2020 > 0 THEN gdp_2020 ELSE 0 END) +
    (CASE WHEN gdp_2021 > 0 THEN gdp_2021 ELSE 0 END) +
    (CASE WHEN gdp_2022 > 0 THEN gdp_2022 ELSE 0 END) +
    (CASE WHEN gdp_2023 > 0 THEN gdp_2023 ELSE 0 END) +
    (CASE WHEN gdp_2024 > 0 THEN gdp_2024 ELSE 0 END) +
    (CASE WHEN gdp_2025 > 0 THEN gdp_2025 ELSE 0 END)
) / 
NULLIF((
    (CASE WHEN gdp_2020 > 0 THEN 1 ELSE 0 END) +
    (CASE WHEN gdp_2021 > 0 THEN 1 ELSE 0 END) +
    (CASE WHEN gdp_2022 > 0 THEN 1 ELSE 0 END) +
    (CASE WHEN gdp_2023 > 0 THEN 1 ELSE 0 END) +
    (CASE WHEN gdp_2024 > 0 THEN 1 ELSE 0 END) +
    (CASE WHEN gdp_2025 > 0 THEN 1 ELSE 0 END)
), 0), 2);



-- Replace 0 with avg_gdp

UPDATE GDP
SET 
    gdp_2020 = IF(gdp_2020 = 0, avg_gdp, gdp_2020),
    gdp_2021 = IF(gdp_2021 = 0, avg_gdp, gdp_2021),
    gdp_2022 = IF(gdp_2022 = 0, avg_gdp, gdp_2022),
    gdp_2023 = IF(gdp_2023 = 0, avg_gdp, gdp_2023),
    gdp_2024 = IF(gdp_2024 = 0, avg_gdp, gdp_2024),
    gdp_2025 = IF(gdp_2025 = 0, avg_gdp, gdp_2025);
    
-- -------------------------------------------------------------------------------------------------------

-- Transpose the table and took out Year 

    
CREATE TABLE GDP_Long AS
SELECT Country, '2020' AS Years, gdp_2020 AS GDP, avg_gdp FROM GDP
UNION ALL
SELECT Country, '2021' AS Years, gdp_2021 AS GDP, avg_gdp FROM GDP
UNION ALL
SELECT Country, '2022' AS Years, gdp_2022 AS GDP, avg_gdp FROM GDP
UNION ALL
SELECT Country, '2023' AS Years, gdp_2023 AS GDP, avg_gdp FROM GDP
UNION ALL
SELECT Country, '2024' AS Years, gdp_2024 AS GDP, avg_gdp FROM GDP
UNION ALL
SELECT Country, '2025' AS Years, gdp_2025 AS GDP, avg_gdp FROM GDP;

select * from gdp_long;

describe gdp_long;

ALTER TABLE gdp_long MODIFY Year INT;

-- ----------------------------------------------------------------------------------------------------------

 -- CAGR

ALTER TABLE GDP_long
ADD COLUMN CAGR DECIMAL(10,2);
UPDATE GDP_long g
JOIN (
    -- Get the Start and End Year GDPs
    SELECT
        t1.Country,
        t1.GDP AS Start_GDP,
        t2.GDP AS End_GDP,
        (t2.Years - t1.Years) AS Num_Years
    FROM
        GDP_long t1
    JOIN
        (SELECT Country, MIN(Years) AS MinYear, MAX(Years) AS MaxYear FROM GDP_long GROUP BY Country) AS  yr
        ON t1.Country = yr.Country AND t1.Years = yr.MinYear
    JOIN
        GDP_long t2
        ON t2.Country = yr.Country AND t2.Years = yr.MaxYear
) AS c ON g.Country = c.Country
SET
    g.CAGR = ROUND(
        (POW(c.End_GDP / c.Start_GDP, 1 / c.Num_Years) - 1) * 100,
        2
    )
WHERE
    c.Num_Years > 0;
-- ---------------------------------------------------------------------------------------------------------

SELECT
    CONCAT(ROUND((POWER((T.End_GDP / T.Start_GDP),(1.0 / T.Num_Years))- 1) * 100,2),'%') AS overall_cagr_value
FROM
(    SELECT
        (SELECT SUM(GDP) FROM gdp_long WHERE Years = (SELECT MIN(Years) FROM gdp_long)) AS Start_GDP,
        (SELECT SUM(GDP) FROM gdp_long WHERE Years = (SELECT MAX(Years) FROM gdp_long)) AS End_GDP,
        ((SELECT MAX(Years) FROM gdp_long) - (SELECT MIN(Years) FROM gdp_long)) AS Num_Years
) AS T;

-- -------------------------------------------------------------------------------------------------------------------
ALTER TABLE gdp_long
ADD COLUMN GDP_Growth_Percentage VARCHAR(10);

UPDATE gdp_long AS d
JOIN (
    WITH CountryGrowth AS (
        SELECT MIN(t.Years) AS StartYear,MAX(t.Years) AS EndYear
        FROM gdp_long AS t
    ),
    CountryGDPs AS (
        SELECT t.Country,
            SUM(CASE WHEN t.Years = (SELECT StartYear FROM CountryGrowth) THEN t.GDP ELSE 0 END) AS Start_GDP,
            SUM(CASE WHEN t.Years = (SELECT EndYear FROM CountryGrowth) THEN t.GDP ELSE 0 END) AS End_GDP
        FROM gdp_long AS t
        GROUP BY t.Country
    )
    SELECT  cg.Country,
        CASE
			WHEN cg.Start_GDP > 0 THEN
				CONCAT( ROUND(((cg.End_GDP - cg.Start_GDP) / cg.Start_GDP) * 100,2 ),'%')
			ELSE NULL
        END AS Calculated_Growth
    FROM CountryGDPs AS cg
) AS GrowthData
ON d.Country = GrowthData.Country
SET d.GDP_Growth_Percentage = GrowthData.Calculated_Growth;

select * from gdp_long;

WITH YearTotals AS (
    SELECT Years,SUM(GDP) AS TotalGDP
    FROM gdp_long 
    GROUP BY Years
),
StartEndTotals AS (
    SELECT
        (SELECT TotalGDP FROM YearTotals WHERE Years = (SELECT MIN(Years) FROM YearTotals)) AS StartYearGDP,
        (SELECT TotalGDP FROM YearTotals WHERE Years = (SELECT MAX(Years) FROM YearTotals)) AS EndYearGDP
)
SELECT
    CASE
        WHEN StartYearGDP IS NULL OR StartYearGDP = 0 THEN 'N/A'
        ELSE
            CONCAT( FORMAT(((EndYearGDP - StartYearGDP) / StartYearGDP) * 100,2 ),'%')
    END AS OverallGDPGrowth
FROM StartEndTotals;

-- Top 10 Countries by GDP (latest year)
select country,gdp 
from gdp_long
where years = (
	select max(years) 
    from gdp_long)
order by gdp desc
limit 10;

-- Bottomm 10 Countries by GDP (latest year)
select country,gdp 
from gdp_long
where years = (
	select max(years) 
    from gdp_long)
order by gdp 
limit 10;

-- Countries with Highest Average GDP
SELECT DISTINCT country, avg_gdp
FROM gdp_long
ORDER BY avg_gdp DESC
LIMIT 10;

-- Countries with Highest GDP Growth % (overall)

select distinct country,GDP_Growth_Percentage 
from gdp_long
order by GDP_Growth_Percentage desc
limit 5;

-- Countries with Lowest GDP Growth % (overall)

select distinct country,GDP_growth_percentage 
from gdp_long
order by GDP_growth_percentage 
limit 5;

-- Countries with Highest CAGR
select distinct country,CAGR 
from gdp_long
order by CAGR desc
limit 5;

-- Countries with Negative Growth
SELECT DISTINCT country, GDP_Growth_Percentage
FROM gdp_long
WHERE GDP_Growth_Percentage < 0
order by GDP_Growth_Percentage;

-- World GDP by Year
SELECT years, SUM(GDP) AS Total_World_GDP
FROM gdp_long
GROUP BY years
ORDER BY years;

-- Global YoY Growth (%)

WITH yearly AS (
    SELECT years, SUM(GDP) AS total_gdp
    FROM gdp_long
    GROUP BY years
)
SELECT 
    y1.years AS Year,
    y1.total_gdp,
    ROUND(((y1.total_gdp - y0.total_gdp) / y0.total_gdp) * 100, 2) AS YoY_Growth
FROM yearly y1
JOIN yearly y0 ON y1.years = y0.years + 1;

-- Rank Countries by GDP in Each Year

SELECT country, years, GDP,
       RANK() OVER (PARTITION BY years ORDER BY GDP DESC) AS GDP_rank
FROM gdp_long;

-- Rank Countries by CAGR

SELECT country, CAGR,
       RANK() OVER (ORDER BY CAGR DESC) AS CAGR_rank
FROM gdp_long
GROUP BY country, CAGR;


