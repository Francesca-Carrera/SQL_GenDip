
/* Solo valori NULL:
IN ('Saint Lucia', 'Holy See','Grenada', 'Micronesia, Federated States of', 'Faroe Islands',
	'Niue','Dominica','Tuvalu','Saint Vincent and the Grenadines','Tonga', 'Belize',
	'Brunei Darussalam','Palestine, State of','Liechtenstein','Kiribati','Western Sahara',
	'San Marino','Marshall Islands','Samoa','Bahamas','Antigua and Barbuda','Saint Kitts and Nevis',
	'Serbia and Montenegro','Andorra','Nauru','Monaco','Palau') */

-- prova generica da workingArea.
SELECT cname_send, v2lgfemleg_send AS pct, COUNT(cname_send) AS conteggio
FROM dbo.workingArea
GROUP BY cname_send, v2lgfemleg_send

-- Media per ogni anno:
SELECT 
    year, 
    CAST(ROUND(AVG(COALESCE(FL.femaleLegislatorPercentage, 0)), 2) AS DECIMAL(18,2)) AS media
FROM
    dbo.targetArea AS TA
    LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
    LEFT JOIN dbo.femaleLegislators AS FL ON SC.femaleLegislatorID = FL.femaleLegislatorID
    LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
GROUP BY year
ORDER BY year ASC;

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
				LEFT JOIN dbo.femaleLegislators AS FL ON SC.femaleLegislatorID = FL.femaleLegislatorID
				LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
			GROUP BY Y.year) AS sub )
SELECT CAST(ROUND((SUM(annual_avgPct_growth)/(COUNT(year)-1)),2) AS DECIMAL(18,2)) AS avgPct_growth
FROM CTE;
-- avgPct_growth: 2.36

-- -- Per ogni anno, il paese col valore più alto + In quale anno si è arrivati al 50% di pct (2008)
SELECT year, country_GROUP_BY, pct
FROM (
		SELECT 
			year, VW.country_GROUP_BY,
			COALESCE(FL.femaleLegislatorPercentage, 0) AS pct,
			DENSE_RANK() OVER (PARTITION BY Y.year ORDER BY COALESCE(FL.femaleLegislatorPercentage, 0) DESC) AS dense
		FROM
			dbo.targetArea AS TA
			LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
			LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
			LEFT JOIN dbo.femaleLegislators AS FL ON SC.femaleLegislatorID = FL.femaleLegislatorID
			LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
		GROUP BY 
			Y.year, VW.country_GROUP_BY, FL.femaleLegislatorPercentage) AS sub
WHERE dense = 1
ORDER BY year ASC;

-- TOP 10 paesi con media più alta
SELECT 
	TOP 10 VW.country_GROUP_BY,
    CAST(ROUND(AVG(COALESCE(FL.femaleLegislatorPercentage, 0)), 2) AS DECIMAL(18,2)) AS media
FROM
    dbo.targetArea AS TA
    LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
    LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
    LEFT JOIN dbo.femaleLegislators AS FL ON SC.femaleLegislatorID = FL.femaleLegislatorID
    LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
GROUP BY VW.country_GROUP_BY
ORDER BY media DESC;

-- Media delle regioni geografiche.
SELECT 
	R.region,
    CAST(ROUND(AVG(COALESCE(FL.femaleLegislatorPercentage, 0)), 2) AS DECIMAL(18,2)) AS media
FROM
    dbo.targetArea AS TA
    LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
    LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
	LEFT JOIN dbo.regions AS R ON VW.regionID = R.regionID
    LEFT JOIN dbo.femaleLegislators AS FL ON SC.femaleLegislatorID = FL.femaleLegislatorID
    LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
GROUP BY R.region
ORDER BY media ASC;


