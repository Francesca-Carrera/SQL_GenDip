--------------------------------------------------------------------------------------------------------------------------------------------
/* ANALISI DEI DATI 2/3 - Secondo Focus: membri del Parlamento e politica estera femminista.

4) Media percentuale annuale dei membri di genere femminile, appartenenti alla Camera Bassa.
	A) Crescita media annuale.

5) I paesi con la percentuale annuale maggiore di legislatori femminili.
	A) TOP 10 paesi con media percentuale più alta in assoluto.
	B) La media percentuale delle regioni geografiche. */
------------------------------------------------------------------------------------------------------------------------------------------------

-- 4) Media percentuale annuale dei membri di genere femminile, appartenenti alla Camera Bassa.

SELECT year, 
	   FORMAT(ROUND( AVG( COALESCE(FL.femaleLegislatorPercentage, 0))
			  , 2)
	   , '0.00') AS femPct_avg
FROM
    dbo.targetArea AS TA
    LEFT JOIN dbo.sendingCountries AS SC 
		ON TA.sendingCountryID = SC.sendingCountryID
    LEFT JOIN dbo.femaleLegislators AS FL 
		ON SC.femaleLegislatorID = FL.femaleLegislatorID
    LEFT JOIN dbo.years AS Y 
		ON TA.yearID = Y.yearID
GROUP BY year
ORDER BY year ASC;

/* - AVG(COALESCE(FL.femaleLegislatorPercentage, 0)) : 4.956390
- ROUND(AVG(COALESCE(FL.femaleLegislatorPercentage, 0)),2) : 4.960000
- FORMAT(ROUND(AVG(COALESCE(FL.femaleLegislatorPercentage, 0)),2), '0.00') : 4,96 */

-- 4a) Crescita media annuale.

/* Nella CTE femPct_avg_CTE visualizzo la media percentuale annuale 
dei membri di genere femminile, appartenenti alla Camera Bassa.
Nella CTE avgPct_CTE viene calcolata la media percentuale 
di crescita annuale delle percentuali di legislatori femminili. 
Nello specifico:
- con la funzione finestra LAG mostro la media percentuale dell'anno precedente per ogni riga.
- con il codice 'femPct_avg - LAG(femPct_avg) OVER (ORDER BY year) AS annual_avgPct_growth'
  calcolo la differenza tra la media percentuale dell'anno corrente e quella dell'anno precedente.
Nella SELECT finale viene calcolata la crescita media annuale delle percentuali di legislatori femminili. 
Prima si somma le variazioni annuali delle percentuali, poi le si divide per il numero di anni meno uno,
ottenendo una media. Infine, si formatta il risultato come percentuale con due cifre decimali. */

WITH femPct_avg_CTE
	AS( SELECT year, 
			   ROUND( AVG( COALESCE(FL.femaleLegislatorPercentage, 0))
				   , 2) AS femPct_avg
		FROM
			dbo.targetArea AS TA
			LEFT JOIN dbo.sendingCountries AS SC 
				ON TA.sendingCountryID = SC.sendingCountryID
			LEFT JOIN dbo.femaleLegislators AS FL 
				ON SC.femaleLegislatorID = FL.femaleLegislatorID
			LEFT JOIN dbo.years AS Y 
				ON TA.yearID = Y.yearID
		GROUP BY year),

avgPct_CTE
	AS (SELECT year, 
			   femPct_avg, 

			   LAG(femPct_avg) 
				OVER (
					ORDER BY year)		   AS avgPct_prevYear,

			   femPct_avg - LAG(femPct_avg) 
						OVER (
							ORDER BY year) AS annual_avgPct_growth

		FROM femPct_avg_CTE)

SELECT FORMAT(ROUND( SUM(COALESCE(annual_avgPct_growth, 0)) / (COUNT(year)-1)
			  , 2)
	   , '0.00') AS avgPct_growth
FROM avgPct_CTE
-- avgPct_growth: 2.36

---

-- 5) I paesi con la percentuale annuale maggiore di legislatori femminili.

/* In questo blocco di codice viene calcolata la percentuale di legislatori femminili per ogni anno e paese. 
Nello specifico:
- Nella CTE femPct_CTE viene attribuito un numero di rango basato sulle percentuali 
per ogni anno e ogni paese, tramite la funzione finestra DENSE RANK.
- Nella SELECT finale vengono selezionate solo le righe con il rango uguale a 1, 
ovvero il paese con le percentuali annuali più alte. */

WITH femPct_CTE
	AS( SELECT year, 
			   VW.unifiedCountries,
			   COALESCE(FL.femaleLegislatorPercentage, 0) AS femPct,

			   DENSE_RANK() 
					OVER (PARTITION BY Y.year 
					  ORDER BY COALESCE(FL.femaleLegislatorPercentage, 0) 
					  DESC)								  AS femPct_denseRank

		FROM
			dbo.targetArea AS TA
				LEFT JOIN dbo.sendingCountries AS SC 
					ON TA.sendingCountryID = SC.sendingCountryID
				LEFT JOIN vw_unifiedCountries AS VW 
					ON SC.countryID = VW.countryID
				LEFT JOIN dbo.femaleLegislators AS FL 
					ON SC.femaleLegislatorID = FL.femaleLegislatorID
				LEFT JOIN dbo.years AS Y 
					ON TA.yearID = Y.yearID
		GROUP BY 
			Y.year, 
			VW.unifiedCountries, 
			FL.femaleLegislatorPercentage)
SELECT year, unifiedCountries, femPct
FROM femPct_CTE
WHERE femPct_denseRank = 1;

---

-- 5a) TOP 10 paesi con media percentuale più alta in assoluto.

-- NB. Forma+Round+Avg risultato inatteso es. '9,98'.

/* 'CAST( ... AS DECIMAL(18,2))' converte la media arrotondata di 
'femaleLegislatorPercentage' in un numero decimale con due cifre decimali. */
SELECT 
	TOP 10 VW.unifiedCountries,
    CAST(ROUND( AVG( COALESCE(FL.femaleLegislatorPercentage, 0))
		 , 2) AS DECIMAL(18,2)) AS femPct
FROM
    dbo.targetArea AS TA
    LEFT JOIN dbo.sendingCountries AS SC 
		ON TA.sendingCountryID = SC.sendingCountryID
    LEFT JOIN vw_unifiedCountries AS VW 
		ON SC.countryID = VW.countryID
    LEFT JOIN dbo.femaleLegislators AS FL 
		ON SC.femaleLegislatorID = FL.femaleLegislatorID
    LEFT JOIN dbo.years AS Y 
		ON TA.yearID = Y.yearID
GROUP BY VW.unifiedCountries
ORDER BY femPct DESC;

-- 5b) La media percentuale delle regioni geografiche.

-- NB. qui FORMAT funziona ma ho preferito utilizzare CAST.

SELECT 
	R.region,
    CAST(ROUND( AVG( COALESCE(FL.femaleLegislatorPercentage, 0))
		 , 2) AS DECIMAL(18,2)) AS femPct
FROM
    dbo.targetArea AS TA
    LEFT JOIN dbo.sendingCountries AS SC 
		ON TA.sendingCountryID = SC.sendingCountryID
    LEFT JOIN vw_unifiedCountries AS VW 
		ON SC.countryID = VW.countryID
	LEFT JOIN dbo.regions AS R 
		ON VW.regionID = R.regionID
    LEFT JOIN dbo.femaleLegislators AS FL 
		ON SC.femaleLegislatorID = FL.femaleLegislatorID
    LEFT JOIN dbo.years AS Y 
		ON TA.yearID = Y.yearID
GROUP BY R.region
ORDER BY femPct ASC;


