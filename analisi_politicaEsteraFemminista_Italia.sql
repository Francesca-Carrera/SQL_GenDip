
/* 1 FFP_send / FeministForeignPolicy_S:
2014: Sweden
2019: Canada, France, Mexico, Sweden
2021: Canada, France, Libya, Luxembourg, Mexico, Spain, Sweden.

 1 FFP_receive / FeministForeignPolicy_S:
2014: Sweden
2019: Canada, France, Mexico, Sweden
2021: Canada, France, Libya, Luxembourg, Mexico, Spain, Sweden. */

-- prova generica da workingArea.
SELECT year, cname_send, FFP_send
FROM dbo.workingArea
WHERE FFP_send = 1
GROUP BY year, cname_send, FFP_send; -- 12 righe dal 2014

SELECT year, cname_receive, FFP_receive
FROM dbo.workingArea
WHERE FFP_receive = 1
GROUP BY year, cname_receive, FFP_receive; -- 12 righe dal 2014

-- Paesi d'origine aderenti ad una politica estera femminista.
SELECT Y.year, VW.country_GROUP_BY, SC.feministForeignPolicy
FROM dbo.targetArea AS TA
LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
WHERE SC.feministForeignPolicy = 1
GROUP BY Y.year, VW.country_GROUP_BY, SC.feministForeignPolicy;

-- Paesi di destinazione aderenti ad una politica estera femminista.
SELECT Y.year, VW.country_GROUP_BY, RC.feministForeignPolicy
FROM dbo.targetArea AS TA
LEFT JOIN dbo.receivingCountries AS RC ON TA.receivingCountryID = RC.receivingCountryID
LEFT JOIN vw_country_GROUP_BY AS VW ON RC.countryID = VW.countryID
LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
WHERE RC.feministForeignPolicy = 1
GROUP BY Y.year, VW.country_GROUP_BY, RC.feministForeignPolicy;

---

-- ITALIA

-- Conteggio totale e annuale di diplomatici per genere.
SELECT 
    COALESCE(CAST(Y.year AS VARCHAR(10)), 'tot') AS year,
    FORMAT(COUNT(CASE WHEN D.gender = 1 THEN 1 END), '#,0') AS femaleDiplomats,
    FORMAT(COUNT(CASE WHEN D.gender = 0 THEN 1 END), '#,0') AS maleDiplomats
FROM 
    dbo.diplomats AS D
INNER JOIN 
    dbo.targetArea AS T ON D.diplomatID = T.diplomatID
INNER JOIN dbo.sendingCountries AS SC ON T.sendingCountryID = SC.sendingCountryID
LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
INNER JOIN 
    dbo.years AS Y ON T.yearID = Y.yearID
WHERE VW.alpcode = 'ITA'
GROUP BY 
    Y.year
WITH ROLLUP -- La clausola WITH ROLLUP ti consentirà  di ottenere anche il totale generale delle colonne.
ORDER BY 
    Y.year ASC;

-- Crescita percentuale maggiore di diplomatici di genere maschile in Italia.

-- 2014 172 - 2013 105 = 67 - 67 /195 (2013) * 100 = 63,81% 
-- Crescita del 2014 rispetto al 2013

-- 1) risultato senza anno
WITH DiplomatsCounts AS (
    SELECT 
        Y.year, 
        COUNT(D.gender) AS maleDiplomats
    FROM 
        dbo.targetArea AS TA
        LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
        LEFT JOIN dbo.vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
        LEFT JOIN dbo.diplomats AS D ON TA.diplomatID = D.diplomatID
        LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
    WHERE 
        VW.alpcode = 'ITA' AND D.gender = 0
    GROUP BY 
        Y.year
),
MaleDiplomatsDiff AS (
    SELECT 
        year, 
        maleDiplomats,
        LAG(maleDiplomats) OVER (ORDER BY Year) AS male_prevYearCount,
        maleDiplomats - LAG(maleDiplomats) OVER (ORDER BY Year) AS male_diff
    FROM 
        DiplomatsCounts
),
malePct_MAX AS (
	SELECT 
		CONCAT(MAX(pct), '%') AS malePct_MAX
	FROM (
		SELECT 
			year, 
			maleDiplomats, 
			male_prevYearCount, 
			male_diff,
			CAST(ROUND(((CONVERT(DECIMAL(18,2), male_diff) / male_prevYearCount) * 100), 2) AS DECIMAL(18,2)) AS pct
		FROM 
			MaleDiplomatsDiff) AS sub )
SELECT malePct_MAX
FROM malePct_MAX AS MM

-- 2) risultato anche con anno ma più complicato.
WITH DiplomatsCounts AS (
    SELECT 
        Y.year, 
        COUNT(D.gender) AS maleDiplomats
    FROM 
        dbo.targetArea AS TA
        LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
        LEFT JOIN dbo.vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
        LEFT JOIN dbo.diplomats AS D ON TA.diplomatID = D.diplomatID
        LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
    WHERE 
        VW.alpcode = 'ITA' AND D.gender = 0
    GROUP BY 
        Y.year
),
MaleDiplomatsDiff AS (
    SELECT 
        year, 
        maleDiplomats,
        LAG(maleDiplomats) OVER (ORDER BY Year) AS male_prevYearCount,
        maleDiplomats - LAG(maleDiplomats) OVER (ORDER BY Year) AS male_diff
    FROM 
        DiplomatsCounts
),
MaxPct AS (
    SELECT 
        MAX(pct) AS max_pct
    FROM (
        SELECT 
            year, 
            CAST(ROUND(((CONVERT(DECIMAL(18,2), male_diff) / male_prevYearCount) * 100), 2) AS DECIMAL(18,2)) AS pct
        FROM 
            MaleDiplomatsDiff
    ) AS Subquery
)
SELECT 
    CONCAT(max_pct, '%') AS malePct_MAX,
    year AS year_malePct_MAX
FROM 
    MaxPct
JOIN 
    (
        SELECT 
            year, 
            CAST(ROUND(((CONVERT(DECIMAL(18,2), male_diff) / male_prevYearCount) * 100), 2) AS DECIMAL(18,2)) AS pct
        FROM 
            MaleDiplomatsDiff
    ) AS Subquery ON MaxPct.max_pct = Subquery.pct;

---

-- Media percentuale annuale della presenza di diplomatici di genere femminile in Italia.
SELECT Y.year,
    CAST(ROUND(AVG(COALESCE(FL.femaleLegislatorPercentage, 0)), 2) AS DECIMAL(18,2)) AS media
FROM
    dbo.targetArea AS TA
    LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
    LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
    LEFT JOIN dbo.femaleLegislators AS FL ON SC.femaleLegislatorID = FL.femaleLegislatorID
    LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
WHERE VW.alpcode = 'ITA'
GROUP BY Y.year
ORDER BY Y.year ASC;

-- Media percentuale della presenza di diplomatici di genere femminile in Italia.
SELECT country_GROUP_BY, media, posizionamento
FROM (
		SELECT 
			VW.country_GROUP_BY,
			CAST(ROUND(AVG(COALESCE(FL.femaleLegislatorPercentage, 0)), 2) AS DECIMAL(18,2)) AS media,
			ROW_NUMBER() OVER (ORDER BY AVG(COALESCE(FL.femaleLegislatorPercentage, 0)) DESC) AS posizionamento
		FROM
			dbo.targetArea AS TA
			LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
			LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
			LEFT JOIN dbo.femaleLegislators AS FL ON SC.femaleLegislatorID = FL.femaleLegislatorID
			LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
		GROUP BY VW.country_GROUP_BY ) AS sub
WHERE country_GROUP_BY = 'Italy'; -- 21,60% 57esima su 203

-- Crescita media % annuale.
WITH CTE AS (
	SELECT year, media, LAG(media) OVER (ORDER BY year) AS avgPct_prevYear,
			media - LAG(media) OVER (ORDER BY year) AS annual_avgPct_growth
	FROM (
			SELECT 
				Y.year, 
				CAST(ROUND(AVG(COALESCE(FL.femaleLegislatorPercentage, 0)), 2) AS DECIMAL(18,2)) AS media
			FROM
				dbo.targetArea AS TA
				LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
				LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
				LEFT JOIN dbo.femaleLegislators AS FL ON SC.femaleLegislatorID = FL.femaleLegislatorID
				LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
			WHERE VW.alpcode = 'ITA'
			GROUP BY Y.year) AS sub )
SELECT CAST(ROUND((SUM(annual_avgPct_growth)/(COUNT(year)-1)),2) AS DECIMAL(18,2)) AS avgPct_growth
FROM CTE;
-- avgPct_growth: 3,67







