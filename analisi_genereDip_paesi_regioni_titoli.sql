-- vw_country_GROUP_BY
CREATE VIEW vw_country_GROUP_BY AS
	SELECT countryID, alpcode, regionID,
		CASE
			WHEN country = 'Central African Empire' THEN 'Central African Republic' -- id 41 -> 42
			WHEN country IN ('German Democratic Republic', 'Germany, Federal Republic of') THEN 'Germany' -- id 82, 84 -> 83
			WHEN country = 'Kampuchea' THEN 'Cambodia' -- id 111 -> 37
			WHEN country = 'USSR' THEN 'Russian Federation' -- id 232 -> 180
			WHEN country IN ('Viet Nam, Democratic Republic of', 'Viet Nam, Republic of') THEN 'Viet Nam' -- id 237, 238 -> 236
			WHEN country IN ('Yemen, Arab Republic of', 'Yemen, People''s Democratic Republic of') THEN 'Yemen' -- id 243, 244 -> 242
			ELSE country 
		END AS country_GROUP_BY
	FROM dbo.countries
	GROUP BY countryID, alpcode, regionID,
		CASE
			WHEN country = 'Central African Empire' THEN 'Central African Republic' -- id 41 -> 42
			WHEN country IN ('German Democratic Republic', 'Germany, Federal Republic of') THEN 'Germany' -- id 82, 84 -> 83
			WHEN country = 'Kampuchea' THEN 'Cambodia' -- id 111 -> 37
			WHEN country = 'USSR' THEN 'Russian Federation' -- id 232 -> 180
			WHEN country IN ('Viet Nam, Democratic Republic of', 'Viet Nam, Republic of') THEN 'Viet Nam' -- id 237, 238 -> 236
			WHEN country IN ('Yemen, Arab Republic of', 'Yemen, People''s Democratic Republic of') THEN 'Yemen' -- id 243, 244 -> 242
			ELSE country 
		END;

SELECT * FROM vw_country_GROUP_BY
-------------------------------------------------------------------------------------------------------------------------------------------------
/* FOGLIO 1:
1) Conteggio totale e annuale di diplomatici per genere.
	2) Maggior numero di diplomatici di genere femminile e in quale anno.
	3) Maggior numero di diplomatici di genere maschile e in quale anno.
	4) Rapporto di crescita di diplomatici di genere maschile e femminile del 2021 rispetto al 1968.
	5) Crescita percentuale maggiore di diplomatici di genere maschile.

6) Paesi con più diplomatici di genere femminile per anno e (8) in assoluto.
	7)Paese con più diplomatici di genere femminile in un singolo anno.
	9) Continenti con più diplomatici di genere femminile in assoluto.

10) Conteggio dei titoli per tipo e (12)per genere.
	11) Conteggio dei titoli per tipo negli anni.
	-)Conteggio di ogni titolo per genere maschile.
	-)Conteggio di ogni titolo per genere femminile.
*/

-- 1) Conteggio totale e annuale di diplomatici per genere.
SELECT 
    COALESCE(CAST(Y.year AS VARCHAR(10)), 'tot') AS year,
    FORMAT(COUNT(CASE WHEN D.gender = 1 THEN 1 END), '#,0') AS femaleDiplomats,
    FORMAT(COUNT(CASE WHEN D.gender = 0 THEN 1 END), '#,0') AS maleDiplomats
FROM 
    dbo.diplomats AS D
INNER JOIN 
    dbo.targetArea AS T ON D.diplomatID = T.diplomatID
INNER JOIN 
    dbo.years AS Y ON T.yearID = Y.yearID
GROUP BY 
    Y.year
WITH ROLLUP -- La clausola WITH ROLLUP ti consentirà  di ottenere anche il totale generale delle colonne.
ORDER BY 
    Y.year ASC;

-- Creazione vista di "Conteggio di diplomatici femminili e maschili in (a) generale e per (b) anno" senza formattazione da riutilizzare.
CREATE VIEW VW_diplomats_GROUP_BY_gender AS
	SELECT Y.year,
			COUNT(CASE WHEN D.gender = 1 THEN 1 END) AS femaleDiplomats,
			COUNT(CASE WHEN D.gender = 0 THEN 1 END) AS maleDiplomats,
			COUNT(CASE WHEN D.gender IS NULL THEN 1 END) AS nullDiplomats
		FROM 
			dbo.diplomats AS D
		INNER JOIN 
			dbo.targetArea AS T ON D.diplomatID = T.diplomatID
		INNER JOIN 
			dbo.years AS Y ON T.yearID = Y.yearID
		GROUP BY 
			Y.year;

-- 2) Maggior numero di diplomatici di genere femminile e in quale anno.
SELECT TOP 1 year, FORMAT(femaleDiplomats, '#,0') AS femDip_MAX
FROM VW_diplomats_GROUP_BY_gender
ORDER BY femaleDiplomats DESC;
-- Year: 2021 - femaleDip_MAX: 3.482

-- 3) Maggior numero di diplomatici di genere maschile e in quale anno.
SELECT TOP 1 year, FORMAT(maleDiplomats, '#,0') AS maleDip_MAX
FROM VW_diplomats_GROUP_BY_gender
ORDER BY maleDiplomats DESC;
-- Year: 2014 - maleDip_MAX: 12.224

-- 4) Crescita percentuale maggiore di diplomatici di genere maschile.
WITH CTE AS (
			SELECT year, maleDiplomats, male_prevYearCount, male_diff,
				   CAST(ROUND(((CONVERT(DECIMAL(18,2), male_diff) / male_prevYearCount) * 100), 2) AS DECIMAL(18,2)) AS pct
			FROM (
				SELECT year, 
					   maleDiplomats,
					   LAG(maleDiplomats) OVER (ORDER BY Year) AS male_prevYearCount,
					   maleDiplomats - LAG(maleDiplomats) OVER (ORDER BY Year) AS male_diff
				FROM VW_diplomats_GROUP_BY_gender ) AS sub)
SELECT CONCAT(MAX(pct), '%') AS malePct_MAX
FROM CTE;
-- Nel 2014 rispetto al 2013, del 77.55% .

-- 5) Rapporto di crescita di diplomatici di genere maschile e femminile del 2021 rispetto al 1968.
SELECT 
    CAST(ROUND(SUM(CONVERT(DECIMAL(18,2), CASE WHEN year = 2021 THEN femaleDiplomats END)) /
               SUM(CONVERT(DECIMAL(18,2), CASE WHEN year = 1968 THEN femaleDiplomats END)), 2) AS DECIMAL(18,2)) AS femaleDip_growthRatio,
    CAST(ROUND(SUM(CONVERT(DECIMAL(18,2), CASE WHEN year = 2021 THEN maleDiplomats END)) /
               SUM(CONVERT(DECIMAL(18,2), CASE WHEN year = 1968 THEN maleDiplomats END)), 2) AS DECIMAL(18,2)) AS maleDip_growthRatio
FROM VW_diplomats_GROUP_BY_gender;
-- femaleDip_growthRatio: 120.07 -- maleDip_growthRatio: 3.82

---

-- 6) Paesi con più diplomatici di genere femminile per anno.
SELECT year, country_GROUP_BY, conteggio
FROM (
SELECT Y.year, VW.country_GROUP_BY, COUNT(CASE WHEN gender = 1 THEN 1 END) AS conteggio,
	   DENSE_RANK() OVER (PARTITION BY Y.year ORDER BY COUNT(CASE WHEN gender = 1 THEN 1 END) DESC) AS ROW_order
FROM targetArea AS T
LEFT JOIN dbo.years AS Y
	ON T.yearID = Y.yearID
LEFT JOIN sendingCountries AS S
	ON T.sendingCountryID = S.sendingCountryID
LEFT JOIN vw_country_GROUP_BY AS VW
	ON S.countryID = VW.countryID
LEFT JOIN dbo.diplomats AS D
	ON T.diplomatID = D.diplomatID
GROUP BY Y.year, VW.country_GROUP_BY
HAVING COUNT(CASE WHEN gender = 1 THEN 1 END) > 1) AS sub
WHERE ROW_order = 1
ORDER BY year;

--7) Paese con più diplomatici di genere femminile in un singolo anno.
SELECT TOP 1 year, country_GROUP_BY, conteggio
FROM (
		SELECT  Y.year, VW.country_GROUP_BY, COUNT(CASE WHEN gender = 1 THEN 1 END) AS conteggio
		FROM targetArea AS T
		LEFT JOIN dbo.years AS Y
			ON T.yearID = Y.yearID
		LEFT JOIN sendingCountries AS S
			ON T.sendingCountryID = S.sendingCountryID
		LEFT JOIN vw_country_GROUP_BY AS VW
			ON S.countryID = VW.countryID
		LEFT JOIN dbo.diplomats AS D
			ON T.diplomatID = D.diplomatID
		GROUP BY Y.year, VW.country_GROUP_BY) AS sub
ORDER BY conteggio DESC;
-- 2021 Madagascar 120

-- 8) Paesi con più diplomatici di genere femminile in assoluto.
SELECT TOP 10 WITH TIES VW.country_GROUP_BY, COUNT(D.gender) AS conteggio
FROM targetArea AS T
LEFT JOIN dbo.years AS Y ON T.yearID = Y.yearID
LEFT JOIN sendingCountries AS S ON T.sendingCountryID = S.sendingCountryID
LEFT JOIN vw_country_GROUP_BY AS VW ON S.countryID = VW.countryID
LEFT JOIN dbo.diplomats AS D ON T.diplomatID = D.diplomatID
WHERE D.gender = 1
GROUP BY VW.country_GROUP_BY
ORDER BY conteggio DESC;

-- 9) Continenti con più diplomatici di genere femminile in assoluto.
SELECT region, FORMAT(unformatted_count, '#,0') AS conteggio
FROM (
		SELECT R.region, COUNT(D.gender) AS unformatted_count
		FROM dbo.targetArea AS TA
		LEFT JOIN dbo.sendingCountries AS S ON TA.sendingCountryID = S.sendingCountryID
		LEFT JOIN vw_country_GROUP_BY AS VW ON S.countryID = VW.countryID
		LEFT JOIN dbo.regions AS R ON VW.regionID = R.regionID
		LEFT JOIN dbo.diplomats AS D ON TA.diplomatID = D.diplomatID
		LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
		WHERE D.gender = 1
		GROUP BY R.region) AS sub
ORDER BY unformatted_count DESC;

---

-- 10) Conteggio dei titoli per tipo e (12)per genere.

-- prova generica da workingArea.
SELECT title, gender, COUNT(gender) AS conteggio
FROM dbo.workingArea
WHERE gender IS NOT NULL
GROUP BY title, gender
ORDER BY title, gender;

-- 10)Conteggio dei titoli per tipo (NB. compreso il conto per il genere NULL ma non title NULL).
SELECT title, FORMAT(unformatted_count, '#,0') AS conteggio
FROM (
		SELECT 
				CASE 
					WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
					WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
				END AS title,
				COUNT(TA.diplomatID) AS unformatted_count
		FROM dbo.targetArea AS TA 
		LEFT JOIN diplomats AS D ON TA.diplomatID = D.diplomatID
		LEFT JOIN dbo.titles AS T ON D.titleID = T.titleID
		WHERE T.title IS NOT NULL
		GROUP BY 
				CASE 
					WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
					WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
				END) AS sub
ORDER BY unformatted_count ASC;

-- 11) Lista dei titoli presenti negli anni con conteggio
WITH CTE AS (
			SELECT Y.year, 
				   CASE 
						WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
						WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
				   END AS title,
				   COUNT(title) AS unformatted_count
			FROM dbo.targetArea AS TA 
			LEFT JOIN diplomats AS D ON TA.diplomatID = D.diplomatID
			LEFT JOIN dbo.titles AS T ON D.titleID = T.titleID
			LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
			WHERE T.title IS NOT NULL
			GROUP BY Y.year, 
						CASE 
							WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
							WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
						END)
-- +
SELECT year, title, FORMAT(unformatted_count, '#,0') AS conteggio
FROM CTE
ORDER BY year, unformatted_count DESC;

-- ) Conteggio del titolo 'Ambassador' negli anni.
SELECT Y.year, FORMAT(COUNT(TA.diplomatID), '#,0') AS conteggio
FROM dbo.targetArea AS TA 
LEFT JOIN diplomats AS D ON TA.diplomatID = D.diplomatID
LEFT JOIN dbo.titles AS T ON D.titleID = T.titleID
LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
WHERE T.title = 'Ambassador'
GROUP BY Y.year, T.title
ORDER BY year;

-- 12) Conteggio di ogni titolo per genere (NB. escluso il genere e title a NULL).
SELECT T.title, 
       CASE 
           WHEN D.gender = 0 THEN 'male'
           WHEN D.gender = 1 THEN 'female'
       END AS gender,
       FORMAT(COUNT(D.gender), '#,0') AS conteggio
FROM dbo.targetArea AS TA 
LEFT JOIN diplomats AS D ON TA.diplomatID = D.diplomatID
LEFT JOIN dbo.titles AS T ON D.titleID = T.titleID
WHERE D.gender IS NOT NULL AND T.title IS NOT NULL
GROUP BY T.title, 
         CASE 
             WHEN D.gender = 0 THEN 'male'
             WHEN D.gender = 1 THEN 'female'
         END
ORDER BY T.title, gender DESC;

-- -)Conteggio di ogni titolo per genere maschile.
SELECT title, FORMAT(unformatted_count, '#,0') AS conteggio
FROM (
		SELECT
			CASE 
				WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
				WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
			END AS title,
			D.gender, COUNT(D.gender) AS unformatted_count
		FROM dbo.targetArea AS TA 
		LEFT JOIN diplomats AS D ON TA.diplomatID = D.diplomatID
		LEFT JOIN dbo.titles AS T ON D.titleID = T.titleID
		WHERE D.gender = 0 AND T.title IS NOT NULL
		GROUP BY 
			CASE 
				WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
				WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
			END,
			D.gender) AS sub
ORDER BY unformatted_count ASC;

-- -)Conteggio di ogni titolo per genere femminile.
SELECT title, FORMAT(unformatted_count, '#,0') AS conteggio
FROM (
		SELECT
			CASE 
				WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
				WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
			END AS title,
			D.gender, COUNT(D.gender) AS unformatted_count
		FROM dbo.targetArea AS TA 
		LEFT JOIN diplomats AS D ON TA.diplomatID = D.diplomatID
		LEFT JOIN dbo.titles AS T ON D.titleID = T.titleID
		WHERE D.gender = 1 AND T.title IS NOT NULL
		GROUP BY 
			CASE 
				WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
				WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
			END,
			D.gender) AS sub
ORDER BY unformatted_count ASC;




