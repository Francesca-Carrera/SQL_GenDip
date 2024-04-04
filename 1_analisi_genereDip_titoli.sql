--------------------------------------------------------------------------------------------------------------------------------------------
/* ANALISI DEI DATI 1/3 - Primo Focus: genere e titoli dei diplomatici.

1) Conteggio totale e annuale di diplomatici per genere.
	A) Maggior numero di diplomatici per genere e in quale anno.
	B) Rapporto di crescita di diplomatici, per genere, del 2021 rispetto al 1968.
	C) Crescita percentuale maggiore di diplomatici di genere maschile.

2) Paesi con più diplomatici di genere femminile per anno e in assoluto.
	A) Regioni geografiche con più diplomatici di genere femminile in assoluto.

3) Conteggio dei titoli per tipo e per genere.
	A)Conteggio di ogni titolo per genere. */
-------------------------------------------------------------------------------------------------------------------------------------------------
/* Ho progettato la vista vw_unifiedCountries per raggruppare i paesi esistenti e datati sotto un'unica denominazione, 
rappresentando il nome attuale e definitivo di ciascun paese. 
Questo ha reso i dati più chiari e comprensibili, evitando la duplicazione dei paesi con nomi diversi 
ma con lo stesso significato durante l'analisi dei dati. 
Inoltre, ciò ha eliminato la necessità di gestire manualmente le varianti dei nomi dei paesi.

La vista si concentra sui paesi che hanno cambiato nome ma hanno mantenuto la loro identità nazionale fondamentale. 
Per questo motivo, ho scelto di escludere dalla vista paesi come Yugoslavia, Serbia e Montenegro e Czechoslovakia, 
poiché hanno subito divisioni che hanno generato nuove entità nazionali. */

-- vw_unifiedCountries
CREATE VIEW vw_unifiedCountries AS
	SELECT countryID, alpcode, regionID,
		CASE
			WHEN country = 'Central African Empire' THEN
						   'Central African Republic' --> DA: id 41 - A: 42
			WHEN country IN ('German Democratic Republic', 
							 'Germany, Federal Republic of') 
							 THEN 'Germany'			  --> DA: id 82 e 84 - A: 83
			WHEN country = 'Kampuchea' THEN 
						   'Cambodia'				  --> DA: id 111 - A: 37
			WHEN country = 'USSR' THEN 
						   'Russian Federation'		  --> DA: id 232 - A: 180
			WHEN country IN ('Viet Nam, Democratic Republic of', 
							 'Viet Nam, Republic of') 
							 THEN 'Viet Nam'		  --> DA: id 237 e 238 - A: 236
			WHEN country IN ('Yemen, Arab Republic of', 
							 'Yemen, People''s Democratic Republic of') 
							 THEN 'Yemen'			  --> DA: id 243 e 244 - A: 242
			ELSE country 
		END AS unifiedCountries
	FROM dbo.countries
	GROUP BY countryID, alpcode, regionID,
		CASE
			WHEN country = 'Central African Empire' THEN
						   'Central African Republic' --> DA: id 41 - A: 42
			WHEN country IN ('German Democratic Republic', 
							 'Germany, Federal Republic of') 
							 THEN 'Germany'			  --> DA: id 82 e 84 - A: 83
			WHEN country = 'Kampuchea' THEN 
						   'Cambodia'				  --> DA: id 111 - A: 37
			WHEN country = 'USSR' THEN 
						   'Russian Federation'		  --> DA: id 232 - A: 180
			WHEN country IN ('Viet Nam, Democratic Republic of', 
							 'Viet Nam, Republic of') 
							 THEN 'Viet Nam'		  --> DA: id 237 e 238 - A: 236
			WHEN country IN ('Yemen, Arab Republic of', 
							 'Yemen, People''s Democratic Republic of') 
							 THEN 'Yemen'			  --> DA: id 243 e 244 - A: 242
			ELSE country 
		END;
-------------------------------------------------------------------------------------------------------------------------------------------------
-- 1) Conteggio totale e annuale di diplomatici per genere.
SELECT  COALESCE(CAST(Y.year AS VARCHAR(10)), 'tot') AS year,
		FORMAT(COUNT(CASE 
						WHEN D.gender = 1 THEN 1 
					 END), '#,0')					 AS femaleDiplomats,
		FORMAT(COUNT(CASE 
						WHEN D.gender = 0 THEN 1 
					 END), '#,0')					 AS maleDiplomats
FROM dbo.diplomats AS D
	INNER JOIN dbo.targetArea AS T 
			ON D.diplomatID = T.diplomatID
	INNER JOIN dbo.years AS Y 
			ON T.yearID = Y.yearID
GROUP BY Y.year WITH ROLLUP 
-- La clausola WITH ROLLUP consentirà di ottenere 
-- anche il totale generale delle colonne.
ORDER BY Y.year ASC;

/* Il codice 'COALESCE(CAST(Y.year AS VARCHAR(10)), 'tot') AS year' 
restituirà la colonna year, che sarà il valore di Y.year convertito 
in stringa se non è nullo, altrimenti restituirà il valore 'tot'. 
Con la clausola WITH ROLLUP, il valore 'tot' verrà utilizzato per 
rappresentare il totale generale. */

---

-- Creazione vista con conteggio annuale di diplomatici femminili e maschili 
-- (senza formattazione e clausola WITH ROLLUP) da riutilizzare.
CREATE VIEW VW_diplomatsByGender AS
	SELECT Y.year,
			COUNT(CASE 
					WHEN D.gender = 1 THEN 1 
				  END)							AS femaleDiplomats,
			COUNT(CASE WHEN D.gender = 0 THEN 1 
				  END)							AS maleDiplomats
	FROM dbo.diplomats AS D
		INNER JOIN dbo.targetArea AS T 
			ON D.diplomatID = T.diplomatID
		INNER JOIN dbo.years AS Y 
			ON T.yearID = Y.yearID
		GROUP BY Y.year;

---

-- 1a) Maggior numero di diplomatici per genere e in quale anno.
WITH femaleDiplomats_CTE
	 AS (SELECT TOP 1 year, 
	    FORMAT(femaleDiplomats, '#,0') AS femDip_MAX
		FROM VW_diplomatsByGender
		ORDER BY femaleDiplomats DESC)

, maleDiplomats_CTE 
  AS (SELECT TOP 1 year, 
	    FORMAT(maleDiplomats, '#,0') AS maleDip_MAX
		FROM VW_diplomatsByGender
		ORDER BY maleDiplomats DESC)

SELECT FD.year, FD.femDip_MAX, 
	   MD.maleDip_MAX, MD.year 
FROM femaleDiplomats_CTE AS FD
	 CROSS JOIN maleDiplomats_CTE  AS MD; 
-- Year: 2021 - femaleDip_MAX: 3.482
-- Year: 2014 - maleDip_MAX: 12.224

---

-- 1b) Crescita percentuale maggiore di diplomatici di genere maschile.

/* Nella CTE maleDiff_CTE viene calcolato il numero di diplomatici di genere maschile per ogni anno 
e la differenza tra il numero di diplomatici maschili di un determinato anno rispetto a quello precedente.
Nello specifico:
- con la funzione finestra LAG mostro il numero di diplomatici maschili dell'anno precedente per ogni riga.
- con il codice 'maleDiplomats - LAG(maleDiplomats) OVER (ORDER BY Year) AS male_diff' 
  calcolo la differenza tra il numero di diplomatici maschili dell'anno corrente e quello dell'anno precedente.
  
Nella CTE maleDiff_pct_CTE vegono calcolate le percentuali di variazione tra 
il numero di diplomatici maschili di un anno e quello dell'anno precedente.
Nello specifico:
- 'NULLIF(male_prevYearCount, 0)' gestisce i casi in cui il numero di diplomatici maschili dell'anno precedente è zero. 
   Restituisce NULL se il valore è zero, altrimenti restituisce il numero di diplomatici maschili dell'anno precedente.
- 'ROUND( (male_diff * 100.0 / NULLIF(male_prevYearCount, 0) ), 2)' calcola la variazione percentuale tra il numero di 
   diplomatici maschili dell'anno corrente e quello dell'anno precedente, ROUND 2 per arrotondare il risultato a due cifre decimali.
- 'FORMAT(..., '0.00') + '%' AS maleDiff_pct' per formattare il risultato come stringa, aggiungendo il simbolo percentuale 
   alla fine, creando così la rappresentazione della variazione percentuale. 
   
Nella SELECT finale viene visualizzato il maggior incremento percentuale di diplomatici maschili con l'anno di riferimento.*/

WITH maleDiff_CTE 
	AS ( SELECT year, 
				maleDiplomats,

				LAG(maleDiplomats) 
					OVER (
						ORDER BY Year)				   AS male_prevYearCount,

				maleDiplomats - LAG(maleDiplomats) 
									OVER (
										ORDER BY Year) AS male_diff

		 FROM VW_diplomatsByGender
),
maleDiff_pct_CTE 
	AS ( SELECT year, 
				FORMAT(ROUND( (male_diff * 100.0 / NULLIF(male_prevYearCount, 0) )
					   , 2)
				, '0.00') + '%' AS maleDiff_pct
		 FROM maleDiff_CTE
)
SELECT TOP 1 year, maleDiff_pct
FROM maleDiff_pct_CTE
ORDER BY maleDiff_pct DESC;
-- Nel 2014 rispetto al 2013, del 77.55% .

---

-- 1c) Rapporto di crescita di diplomatici, per genere, del 2021 rispetto al 1968.

/* Nella CTE femaleDip_CTE vengono calcolate le somme dei diplomatici di genere femminili per due anni specifici, il 2021 e il 1968.
  Nella CTE maleDip_CTE vengono calcolate le somme dei diplomatici di genere maschile per due anni specifici, il 2021 e il 1968.

Nella SELECT finale, viene calcolata il tasso di crescita dei diplomatici, di genere maschile e femminile, tra il 1968 e il 2021.

Nello specifico:
- In 'NULLIF(maleDiplomats_1968, 0)' se maleDiplomats_1968 è zero, viene restituito NULL per evitare l'errore di divisione per zero. 
- In '(CONVERT(DECIMAL(18,2), maleDiplomats_2021) / NULLIF(CONVERT(DECIMAL(18,2), maleDiplomats_1968), 0)' 
  maleDiplomats_2021 e maleDiplomats_1968 vengono convertiti in formato decimale prima di eseguire la divisione.
- In 'ROUND(..., maleDiplomats_2021) / ...(..., maleDiplomats_1968), ...), 2)' il risultato ottenuto dalla divisione viene arrotondato 
  a due cifre decimali. Tuttavia, questo risultato non mostra solo due decimali, ma aggiunge zeri aggiuntivi alla fine.
- In 'FORMAT(ROUND(..., maleDiplomats_2021) / ...(..., maleDiplomats_1968), ...), ...), '0.00')' si formatta il risultato arrotondato 
  come stringa con due cifre decimali
 
   CONVERT(DECIMAL(18,2), maleDiplomats_2021) / NULLIF(maleDiplomats_1968, 0) : 3.00
   CONVERT(DECIMAL(18,2), maleDiplomats_2021) / NULLIF(CONVERT(DECIMAL(18,2), maleDiplomats_1968), 0) : 3.82110969387755102040
   ROUND(CONVERT(DECIMAL(18,2), maleDiplomats_2021) / NULLIF(CONVERT(DECIMAL(18,2), maleDiplomats_1968), 0), 2) : 3.82000000000000000000
   FORMAT(ROUND(CONVERT(DECIMAL(18,2), maleDiplomats_2021) / NULLIF(CONVERT(DECIMAL(18,2), maleDiplomats_1968), 0), 2), '0.00') : 3.82 */

WITH femaleDip_CTE AS (
    SELECT 
        SUM(CASE 
			  WHEN year = 2021 THEN femaleDiplomats 
			END)									AS femaleDiplomats_2021,
        SUM(CASE 
			  WHEN year = 1968 THEN femaleDiplomats 
			END)									AS femaleDiplomats_1968
    FROM VW_diplomatsByGender
),

maleDip_CTE AS (
    SELECT 
        SUM(CASE 
			  WHEN year = 2021 THEN maleDiplomats 
			END)									AS maleDiplomats_2021,
        SUM(CASE 
			  WHEN year = 1968 THEN maleDiplomats 
			END)									AS maleDiplomats_1968
    FROM VW_diplomatsByGender
)

SELECT FORMAT(ROUND  ( CONVERT(DECIMAL(18,2), femaleDiplomats_2021 ) / 
					   NULLIF( CONVERT(DECIMAL(18,2), femaleDiplomats_1968 ), 0 )
		      , 2)
	   , '0.00')																AS femaleDip_growthRatio,
       FORMAT(ROUND  ( CONVERT(DECIMAL(18,2), maleDiplomats_2021 ) / 
					   NULLIF( CONVERT(DECIMAL(18,2), maleDiplomats_1968 ), 0 )
			  , 2)
	   , '0.00')																AS maleDip_growthRatio
FROM femaleDip_CTE
	 CROSS JOIN maleDip_CTE;
-- femaleDip_growthRatio: 120.07 -- maleDip_growthRatio: 3.82

---

-- 2 pt1) Paesi con più diplomatici femminili per anno.

/* Nella CTE femDip_count_CTE, si calcola il numero di diplomatici femminili 
per ogni anno e paese, utilizzando l'alias femDip_count per questa misura.
Impiegando la funzione finestra DENSE_RANK(), viene assegnata un'etichetta 
di ordinamento basata su questo conteggio, classificando le combinazioni 
anno-paese in base al numero più alto di diplomatici femminili. 

Nella SELECT si seleziona la prima combinazione anno-paese in base alla 
classificazione determinata dalla funzione finestra DENSE_RANK(). 
Tramite la clausola 'WHERE ROW_order = 1' viene assicurato il risultato 
corrispondente al conteggio più alto di diplomatici femminili.  */

WITH femDip_count_CTE

	AS( SELECT												  Y.year, 

			   VW.unifiedCountries, 
			   COUNT( CASE 
						WHEN gender = 1 THEN 1 
					  END )									   AS femDip_count,

	    DENSE_RANK() 
			OVER ( PARTITION BY Y.year 
				   ORDER BY COUNT( CASE 
									 WHEN gender = 1 THEN 1 
								   END ) 
				   DESC )										AS ROW_order

		FROM targetArea AS T
			LEFT JOIN dbo.years AS Y
				ON T.yearID = Y.yearID
			LEFT JOIN sendingCountries AS S
				ON T.sendingCountryID = S.sendingCountryID
			LEFT JOIN vw_unifiedCountries AS VW
				ON S.countryID = VW.countryID
			LEFT JOIN dbo.diplomats AS D
				ON T.diplomatID = D.diplomatID
		GROUP BY Y.year, 
				 VW.unifiedCountries
		HAVING COUNT(CASE 
						WHEN gender = 1 THEN 1 
					 END) 
		 > 1)

SELECT year, 
	   unifiedCountries, 
	   femDip_count
FROM femDip_count_CTE
WHERE ROW_order = 1
ORDER BY year;

---

-- 2 pt2) Paesi con più diplomatici femminili in assoluto.

/* Utilizzo la clausola TOP 10 WITH TIES in modo che, 
se dovessero esserci più paesi con lo stesso numero massimo 
di diplomatici femminili, verranno restituiti tutti questi 
paesi oltre ai primi 10 (con ordine decrescente). */

SELECT TOP 10 WITH TIES VW.unifiedCountries, 
	   COUNT(D.gender) AS femDip_count
FROM targetArea AS T
	LEFT JOIN dbo.years AS Y 
		ON T.yearID = Y.yearID
	LEFT JOIN sendingCountries AS S 
		ON T.sendingCountryID = S.sendingCountryID
	LEFT JOIN vw_unifiedCountries AS VW 
		ON S.countryID = VW.countryID
	LEFT JOIN dbo.diplomats AS D 
		ON T.diplomatID = D.diplomatID
WHERE D.gender = 1
GROUP BY VW.unifiedCountries
ORDER BY femDip_count DESC;

-- 2a) Regioni geografiche  con più diplomatici femminili in assoluto.

WITH femDip_regionCount_CTE
	AS( SELECT R.region, 
			   COUNT(D.gender) AS unformatted_count
		FROM dbo.targetArea AS TA
			LEFT JOIN dbo.sendingCountries AS S 
				ON TA.sendingCountryID = S.sendingCountryID
			LEFT JOIN vw_unifiedCountries AS VW 
				ON S.countryID = VW.countryID
			LEFT JOIN dbo.regions AS R 
				ON VW.regionID = R.regionID
			LEFT JOIN dbo.diplomats AS D 
				ON TA.diplomatID = D.diplomatID
			LEFT JOIN dbo.years AS Y 
				ON TA.yearID = Y.yearID
		WHERE D.gender = 1
		GROUP BY R.region)
SELECT region, 
	   FORMAT(unformatted_count, '#,0') AS femDip_regionCount
FROM femDip_regionCount_CTE
ORDER BY unformatted_count DESC;

---

-- 3)Conteggio dei titoli per tipo (NB. nel conto è compreso il genere NULL ma non title NULL).

/* Essendo i titoli di Ambassador e Chargé d’affaires numericamente 
i più presenti, ho incluso gli altri nell'etichetta 'other titles'. */

WITH titles_count_CTE
	AS( SELECT 
				CASE 
					WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
					WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
				END AS title,
				COUNT(TA.diplomatID) AS unformatted_count
		FROM dbo.targetArea AS TA 
			LEFT JOIN diplomats AS D 
				ON TA.diplomatID = D.diplomatID
			LEFT JOIN dbo.titles AS T 
				ON D.titleID = T.titleID
		WHERE T.title IS NOT NULL
		GROUP BY 
				CASE 
					WHEN T.title NOT IN ('Ambassador', 'Chargé d’affaires') THEN 'other titles'
					WHEN T.title IN ('Ambassador', 'Chargé d’affaires') THEN T.title
				END)
SELECT title, 
	   FORMAT(unformatted_count, '#,0') AS titles_count
FROM titles_count_CTE
ORDER BY unformatted_count ASC;

-- 3a)Conteggio di ogni titolo per genere (NB. nel conto non è compreso il title NULL).

SELECT T.title, 
       CASE 
           WHEN D.gender = 0 THEN 'male'
           WHEN D.gender = 1 THEN 'female'
       END AS gender,
       FORMAT(COUNT(D.gender), '#,0') AS titles_count
FROM dbo.targetArea AS TA 
	LEFT JOIN diplomats AS D 
		ON TA.diplomatID = D.diplomatID
	LEFT JOIN dbo.titles AS T 
		ON D.titleID = T.titleID
WHERE D.gender IS NOT NULL 
				  AND T.title IS NOT NULL
GROUP BY T.title, 
         CASE 
             WHEN D.gender = 0 THEN 'male'
             WHEN D.gender = 1 THEN 'female'
         END
ORDER BY T.title ASC,
		 gender ASC;
-------------------------------------------------------------------------------------------------------------------------------------------------