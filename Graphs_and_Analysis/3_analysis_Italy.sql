--------------------------------------------------------------------------------------------------------------------------------------------
/* ANALISI DEI DATI 3/3 - Terzo Focus: Italia - analisi su paese specifico.

7) Conteggio totale e annuale di diplomatici per genere.
	A) Crescita percentuale maggiore di diplomatici di genere maschile.

8) Media annuale percentuale dei membri di genere femminile, appartenenti alla Camera Bassa.
	A) Crescita media % annuale dei membri di genere femminile, appartenenti alla Camera Bassa.
	
9) Come si classifica l'Italia per quanto riguarda la media percentuale dei membri di genere femminile, 
appartenenti alla Camera Bassa. */
----------------------------------------------------------------------------------------------------------------------------------------------

-- 7) Conteggio totale e annuale di diplomatici per genere.
-- Similitudine col codice di 1. Analisi - 1. quesito.

SELECT COALESCE( CAST(Y.year AS VARCHAR(10)), 
	   'tot')										AS year,

	   FORMAT( COUNT( CASE WHEN D.gender = 1 THEN 1 
					  END)
	   , '#,0')										AS femaleDiplomats,

       FORMAT( COUNT( CASE WHEN D.gender = 0 THEN 1 
					  END)
	   , '#,0')										AS maleDiplomats

FROM dbo.diplomats AS D
	INNER JOIN dbo.targetArea AS T 
		ON D.diplomatID = T.diplomatID
	INNER JOIN dbo.sendingCountries AS SC 
		ON T.sendingCountryID = SC.sendingCountryID
	LEFT JOIN vw_unifiedCountries AS VW 
		ON SC.countryID = VW.countryID
	INNER JOIN dbo.years AS Y 
		ON T.yearID = Y.yearID
WHERE VW.alpcode = 'ITA'
GROUP BY Y.year
		 WITH ROLLUP -- La clausola WITH ROLLUP consentirà di 
ORDER BY Y.year ASC; -- ottenere anche il totale generale delle colonne.

---

-- 7a) Crescita percentuale maggiore di diplomatici di genere maschile.
-- Similitudine col codice di 1. Analisi - 1b. quesito.

/* Dettaglio calcolo:
(2014) 172 - 105 (2013) = 67 - ( 67 / 195 (2013) ) * 100 = 63,81% 
Crescita del 2014 rispetto al 2013. */

/* Nella CTE diplomatsCounts_CTE visualizzo il conteggio annuale dei diplomatici maschili.

Nella CTE maleDiplomatsDiff_CTE viene calcolato il numero di diplomatici di genere maschile per ogni anno 
e la differenza tra il numero di diplomatici maschili di un determinato anno rispetto a quello precedente.
Nello specifico:
- con la funzione finestra LAG mostro il numero di diplomatici maschili dell'anno precedente per ogni riga.
- con il codice 'maleDiplomats - LAG(maleDiplomats) OVER (ORDER BY Year) AS male_diff' 
  calcolo la variazione tra il numero di diplomatici maschili dell'anno corrente e quello dell'anno precedente.

Nella CTE malePct_CTE vegono calcolate le percentuali di variazione tra 
il numero di diplomatici maschili di un anno e quello dell'anno precedente.

Nella SELECT finale viene visualizzato il valore d'incremento percentuale massimo di diplomatici maschili. */

WITH diplomatsCounts_CTE 
	AS( SELECT Y.year, 
			   COUNT(D.gender) AS maleDiplomats
		FROM dbo.targetArea AS TA
			LEFT JOIN dbo.sendingCountries AS SC 
				ON TA.sendingCountryID = SC.sendingCountryID
			LEFT JOIN vw_unifiedCountries AS VW 
				ON SC.countryID = VW.countryID
			LEFT JOIN dbo.diplomats AS D 
				ON TA.diplomatID = D.diplomatID
			LEFT JOIN dbo.years AS Y 
				ON TA.yearID = Y.yearID
		WHERE VW.alpcode = 'ITA' 
				AND D.gender = 0
		GROUP BY Y.year
),

maleDiplomatsDiff_CTE 
	AS( SELECT year, 
			   maleDiplomats,

			   LAG(maleDiplomats) 
				OVER (
					ORDER BY Year)					   AS male_prevYearCount,

			   maleDiplomats - LAG(maleDiplomats) 
									OVER (
										ORDER BY Year) AS male_diff

    FROM 
        diplomatsCounts_CTE
),

malePct_CTE
	AS( SELECT year, 
			   maleDiplomats, 
			   male_prevYearCount, 
			   male_diff,
			   CAST(ROUND( ((CONVERT(DECIMAL(18,2), male_diff) / male_prevYearCount) * 100)
					, 2) 
			   AS DECIMAL(18,2)) AS pct
		FROM 
			maleDiplomatsDiff_CTE)

SELECT CONCAT( MAX(pct), '%' ) AS malePct_MAX
FROM malePct_CTE;
--  malePct_MAX: 63.81%

---

-- 8) Media annuale percentuale dei membri di genere femminile, appartenenti alla Camera Bassa.
-- Similitudine col codice di 2. Analisi - 4. quesito.

SELECT Y.year,
       CAST(ROUND( AVG( COALESCE(FL.femaleLegislatorPercentage, 0) )
			, 2) 
	   AS DECIMAL(18,2)) AS femPct_avg
FROM dbo.targetArea AS TA
	LEFT JOIN dbo.sendingCountries AS SC 
		ON TA.sendingCountryID = SC.sendingCountryID
    LEFT JOIN vw_unifiedCountries AS VW 
		ON SC.countryID = VW.countryID
    LEFT JOIN dbo.femaleLegislators AS FL 
		ON SC.femaleLegislatorID = FL.femaleLegislatorID
    LEFT JOIN dbo.years AS Y 
		ON TA.yearID = Y.yearID
WHERE VW.alpcode = 'ITA'
GROUP BY Y.year
ORDER BY Y.year ASC;

---

-- 8a) Crescita media % annuale della presenza di diplomatici di genere femminile.
-- Similitudine col codice di 2. Analisi - 4a. quesito.

/* Nella CTE femPctAvg_CTE visualizzo la media percentuale annuale 
dei legislatori femminili, appartenenti alla Camera Bassa.

Nella CTE femPctAvg_annual_growth_CTE  viene espressa la crescita annua media 
percentuale della presenza di legislatori femminili. 

Nello specifico:
- con la funzione finestra LAG mostro la media percentuale dell'anno precedente per ogni riga.
- con il codice 'femPct_avg - LAG(femPct_avg) OVER (ORDER BY year) AS annual_avgPct_growth'
  calcolo la differenza tra la media percentuale dell'anno corrente e quella dell'anno precedente.
Nella SELECT finale viene calcolata la crescita media annuale delle percentuali di legislatori femminili. 
Prima si somma le variazioni annuali delle percentuali, poi le si divide per il numero di anni meno uno,
ottenendo una media. Infine, si formatta il risultato come percentuale con due cifre decimali. */

WITH femPctAvg_CTE
	AS( SELECT Y.year, 
			   CAST(ROUND (AVG(COALESCE(FL.femaleLegislatorPercentage, 0))
					, 2) 
			   AS DECIMAL(18,2)) AS femPct_avg

					FROM dbo.targetArea AS TA
						LEFT JOIN dbo.sendingCountries AS SC 
							ON TA.sendingCountryID = SC.sendingCountryID
						LEFT JOIN vw_unifiedCountries AS VW 
							ON SC.countryID = VW.countryID
						LEFT JOIN dbo.femaleLegislators AS FL 
							ON SC.femaleLegislatorID = FL.femaleLegislatorID
						LEFT JOIN dbo.years AS Y 
							ON TA.yearID = Y.yearID
		WHERE VW.alpcode = 'ITA'
		GROUP BY Y.year),

femPctAvg_annual_growth_CTE 
	AS(SELECT year, 
			  femPct_avg, 
			   
			  LAG(femPct_avg) 
				OVER (
					ORDER BY year)			   AS femPct_avg_prevYear,

			  femPct_avg - LAG(femPct_avg) 
							OVER (
								ORDER BY year) AS femPctAvg_annual_growth
	  FROM femPctAvg_CTE)

SELECT CAST(ROUND((SUM(femPctAvg_annual_growth)/(COUNT(year)-1)),2) AS DECIMAL(18,2)) AS femPct_avg_growth
FROM femPctAvg_annual_growth_CTE;
-- avgPct_growth: 3,67

---

-- 9) Come si classifica l'Italia per quanto riguarda la media percentuale dei membri di genere femminile, 
-- appartenenti alla Camera Bassa.
-- Similitudine col codice di 2. Analisi - 51. quesito.

WITH femPctAvg_rowNumber_CTE
	AS( SELECT unifiedCountries,

	    CAST(ROUND( AVG(COALESCE(FL.femaleLegislatorPercentage, 0))
			 , 2) 
	    AS DECIMAL(18,2))						AS femPct_avg,

	    ROW_NUMBER() 
			 OVER (
				 ORDER BY AVG( COALESCE(FL.femaleLegislatorPercentage, 0) ) 
				 DESC)							AS femPctAvg_rowNumber

		FROM dbo.targetArea AS TA
			LEFT JOIN dbo.sendingCountries AS SC 
				ON TA.sendingCountryID = SC.sendingCountryID
			LEFT JOIN vw_unifiedCountries AS VW 
				ON SC.countryID = VW.countryID
			LEFT JOIN dbo.femaleLegislators AS FL 
				ON SC.femaleLegislatorID = FL.femaleLegislatorID
			LEFT JOIN dbo.years AS Y 
				ON TA.yearID = Y.yearID
		GROUP BY unifiedCountries)

SELECT unifiedCountries, femPct_avg, femPctAvg_rowNumber
FROM femPctAvg_rowNumber_CTE
WHERE unifiedCountries = 'Italy';
-- 21,60% 57esima su 203

----------------------------------------------------------------------------------------------------------------------------------------------