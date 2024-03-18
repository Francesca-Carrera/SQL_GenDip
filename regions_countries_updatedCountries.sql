-- DEFINITIVO
-------------------------------------------------------------------------------------------------------------------------------
-- Tab regions: creazione e popolamento.

CREATE TABLE dbo.regions (
    regionID INT IDENTITY(1,1),
    region NVARCHAR(25) NULL,
    CONSTRAINT PK_regions PRIMARY KEY (regionID), -- PK_TargetTable
    CONSTRAINT UQ_regions_region UNIQUE (region) -- UQ_TargetTable_TargetColumn
)
GO

-- Modello a sette continenti: Africa, Asia, Europa, Sudamerica, Nordamerica, Oceania, (Antartica esclusa).
INSERT INTO dbo.regions (region)
VALUES (NULL), ('Africa'), ('Antarctica'), ('Asia'), ('Europe'), 
	   ('North America'), ('Oceania'), ('South America'); -- 8 righe

 /* VECCHIO + NUOVO
-- 1 NULL -> 1
-- 2 Africa –> 2
-- 3 Asia -> 4
-- 4 Europe -> 5
-- 5 North America -> 6
-- 6 Oceania -> 7
-- 7 South America -> 8 

WHEN '0' THEN '2' -- Africa
WHEN '1' THEN '4' -- Asia 
WHEN '2' THEN '6' -- DA: Central and North America - A: North America
WHEN '3' THEN '5' -- Europe
WHEN '4' THEN '4' -- DA: Middle East - AD: Asia
WHEN '5' THEN '5' -- DA: Nordic countries - AD: Europe
WHEN '6' THEN '7' -- Oceania
WHEN '7' THEN '8' -- South America
ELSE '1'

-- VALORE NUOVO: -- 3 Antarctica */
-------------------------------------------------------------------------------------------------------------------------------
-- Creazione tab Countries e popolamento, 
-- crezione countryID2 (copia della futura PK countryID),
-- creazione di updatedCountry (futura FK, in riferimento alla PK della futura tab updatedCountries). 

WITH cnameUNION_CTE AS 
	(SELECT cname_send, ccodealp_send, region_send
	 FROM dbo.workingArea
		UNION
	SELECT cname_receive, ccodealp_receive, region_receive
	FROM dbo.workingArea)
SELECT 
	IDENTITY(INT, 1,1) AS countryID,
	NULL AS countryID2, -- Sarà la copia di countryID, in versione non IDENTITY in modo che sia modificabile.
	cname_send AS country, -- NULL altrimenti non potrò inserire FK updatedCountryID a NULL.
	ccodealp_send AS alpcode,
	region_send AS regionID,
	NULL AS updatedCountryID -- Sarà la FK in riferimento alla PK di una futura tabella chiamata updatedCountries. 
INTO dbo.countries
FROM cnameUNION_CTE; -- 259 righe

-- Popolamento di countryID2, copia di countryID.
UPDATE dbo.countries 
SET countryID2 = countryID; -- 259 righe

SELECT * FROM dbo.countries; -- 235 id - TUV - Tuvalu - 7 (Oceania, è corretto).
-------------------------------------------------------------------------------------------------------------------------------
-- Popolamento delle due future FK di tab workingArea (REFERENCES countries(countryID)).

-- FK cname_sendID
CREATE PROCEDURE usp_cnameSendID_UPDATE -- userStoredProcedure_column_action
AS
BEGIN
	SET NOCOUNT OFF; -- implicito ma lo scrivo: desidero vedere il conteggio delle righe

	UPDATE W
	SET W.cname_sendID = C.countryID
	FROM dbo.workingArea AS W
	LEFT JOIN dbo.countries AS C 
		ON EXISTS (SELECT W.cname_send, W.ccodealp_send, W.region_send
						INTERSECT
				   SELECT C.country, C.alpcode, C.regionID) 
END;
GO

EXEC usp_cnameSendID_UPDATE; -- 94.509 righe

-- FK cname_receiveID
CREATE PROCEDURE usp_cnameReceiveID_UPDATE -- userStoredProcedure_column_action
AS
BEGIN
	SET NOCOUNT OFF; -- implicito ma lo scrivo: desidero vedere il conteggio delle righe.

	UPDATE W
	SET W.cname_receiveID = C.countryID
	FROM dbo.workingArea AS W
	LEFT JOIN dbo.countries AS C 
		ON EXISTS (SELECT W.cname_receive, W.ccodealp_receive, W.region_receive
						INTERSECT
				   SELECT C.country, C.alpcode, C.regionID) 
END;
GO

EXECUTE usp_cnameReceiveID_UPDATE; -- 94.509 righe
-----------------------------------------------------------------------------------------------------------------------------
-- Tab Countries: controllo di valori country e alpcode multipli (così avevo scoperto il problema del quarto spazio)

WITH country_row AS (
					SELECT countryID2, country, alpcode, regionID,
						   ROW_NUMBER() OVER(PARTITION BY country ORDER BY country) AS  double_country,
						   ROW_NUMBER() OVER(PARTITION BY alpcode ORDER BY country) AS  double_alpcode,
						   ROW_NUMBER() OVER(PARTITION BY country, alpcode ORDER BY country) AS  double_country_alpcode,
						   ROW_NUMBER() OVER(PARTITION BY country, alpcode, regionID ORDER BY country) AS  double_country_alpcode_regionID
					FROM dbo.countries
					WHERE alpcode IS NOT NULL)
SELECT countryID2, country, alpcode, regionID, double_country, double_alpcode, double_country_alpcode, double_country_alpcode_regionID
FROM country_row
WHERE double_country > 1
	  OR double_alpcode > 1
	  OR double_country_alpcode > 1
	  OR double_country_alpcode_regionID > 1; -- 16 righe
--------------------------------------------------------------------------------------------------------------------------------
-- NON SERVE PIU':

-- Eliminazione valori multipli nella colonna country con valori alpcode uguali in tab countries.

/* FORMULA
Delete T 
From (Select Row_Number() Over(Partition By [IndustryType], [IndustryDescription] order By [ID]) As RowNumber,* 
From dbo.industry) T
Where T.RowNumber > 1 */

-- Controllo
SELECT *
FROM (SELECT countryID2, country, alpcode, regionID,
		ROW_NUMBER() OVER (PARTITION BY alpcode, country, regionID ORDER BY alpcode) AS ROW_CountingCheck
	  FROM dbo.countries) AS C
WHERE C.ROW_CountingCheck > 1
ORDER BY alpcode ASC;

-- + Eliminazione vera e propria
DELETE clone_country_alpcode
FROM (SELECT countryID2, country, alpcode, regionID,
		ROW_NUMBER() OVER (PARTITION BY alpcode, country, regionID ORDER BY alpcode) AS ROW_CountingCheck
	  FROM dbo.countries) AS clone_country_alpcode
WHERE clone_country_alpcode.ROW_CountingCheck > 1; -- 101 righe

SELECT * FROM dbo.countries; -- 259 righe

EXEC usp_cnameSendID_UPDATE; -- 94.509 righe
EXECUTE usp_cnameReceiveID_UPDATE; -- 94.509 righe
-----------------------------------------------------------------------------------------------------------------------------
-- Tab countries: verifica dei valori NULL della colonna alpcode. 

SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID 
FROM dbo.countries 
WHERE alpcode IS NULL; -- 7 righe

/* Paesi con alpcode a NULL:
(1)15 id Azores, (2)118 id Korea, (3)121 id Kosovo, (4)212 id South Ossetia, (5)249 id Virgin Islands, (6)252 id Yemen. */

---

-- (1) Azores fa parte del Portogallo.
SELECT countryID2, country, alpcode, regionID  FROM dbo.countries WHERE country IN ('Azores', 'Portugal');
-- DA: 15 id - Azores - NULL alpcode - 6 regionID --> A: 182 id - Portugal - PRT alpcode - 5 regionID.
DELETE FROM dbo.countries WHERE countryID2 = 15;

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('Azores', 'Portugal')
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

UPDATE dbo.workingArea
SET cname_receiveID = 182, cname_receive = 'Portugal', ccodealp_receive = 'PRT', region_receive = 5
WHERE cname_receiveID = 15; -- 1 riga.

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send IN ('Azores', 'Portugal')
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID FROM dbo.countries WHERE country LIKE '%Korea%';
-- (2) Korea ha l'alpcode a NULL perché non è meglio specificato se sia Nord o Sud.

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive LIKE '%Korea%'
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send LIKE '%Korea%'
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID FROM dbo.countries WHERE country = 'Kosovo';
/* (3) Vi sono 2 record con country Kosovo, uno con alpcode a NULL e l'altro con XKO.
Kosovo non ha un alpcode riconosciuto in maniera ufficiale, quindi il record con id 122 e alpcode XKO non è corretto.
DA: 122 id - Kosovo - XKO alpcode - 5 regionID --> A: 121 id - Kosovo - NULL alpcode - 5 regionID. */
DELETE FROM dbo.countries WHERE countryID2 = 122;

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive = 'Kosovo'
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

UPDATE dbo.workingArea
SET cname_receiveID = 121, ccodealp_receive = NULL
WHERE cname_receiveID = 122; -- 138 righe

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send = 'Kosovo'
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

-- (4) South Ossetia fa ufficialmente parte della Georgia.
SELECT countryID2, country, alpcode, regionID FROM dbo.countries WHERE country IN ('South Ossetia', 'Georgia');
-- DA: 212 id - South Ossetia - NULL alpcode - 4 regionID --> A: 83 id - Georgia - GEO alpcode - 4 regionID.
DELETE FROM dbo.countries WHERE countryID2 = 212;

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('South Ossetia', 'Georgia')
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

UPDATE dbo.workingArea
SET cname_receiveID = 83, cname_receive = 'Georgia', ccodealp_receive = 'GEO'
WHERE cname_receiveID = 212; -- 1 riga

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send IN ('South Ossetia', 'Georgia')
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID FROM dbo.countries WHERE country LIKE '%Virgin Islands%';
-- (5) Virgin Islands ha l'alpcode a NULL perché non è meglio specificato se sia British o Usa.

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive LIKE '%Virgin Islands%'
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send LIKE '%Virgin Islands%'
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID FROM dbo.countries WHERE country LIKE '%Yemen%';
/* Vi sono 5 record con country Yemen, uno di questi ha alpcode NULL.
DA: 252 id - NULL alpcode --> A: 253 id - Yemen - YEM alpocode - 4 regionID.

255 id con alpcode scorretto.
DA: 255 id - YME --> A: 254 id - YEM - Yemen, Arab Republic of.

256 id - YMD - Yemen, People's Democratic Republic of. */
DELETE FROM dbo.countries WHERE countryID2 IN (252, 255);

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive LIKE '%Yemen%'
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send LIKE '%Yemen%'
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

UPDATE dbo.workingArea 
SET cname_sendID = 253, ccodealp_send = 'YEM' 
WHERE cname_sendID = 252; -- 1 riga.

UPDATE dbo.workingArea 
SET cname_sendID = 254, ccodealp_send = 'YEM' 
WHERE cname_sendID = 255; -- 67 righe.
-----------------------------------------------------------------------------------------------------------------------------
-- Controllo e correzione di regionID discordanti per valori country multipli:

-- Versione con ROW_NUMBER + DENSE_RANK e INNER JOIN + INNER JOIN

WITH COUNT_country_CTE AS (
	SELECT multiple_country_sub.country, multiple_country_sub.regionID
	FROM (SELECT countryID2, country, alpcode, regionID,
		  ROW_NUMBER() OVER(PARTITION BY country ORDER BY country) AS ROW_country
		  FROM dbo.countries) AS multiple_country_sub
	WHERE multiple_country_sub.ROW_country > 1)

SELECT C2.countryID2, C2.country, C2.alpcode, C2.regionID
FROM (SELECT C1.country, C1.regionID, 
		DENSE_RANK() OVER(PARTITION BY C1.country ORDER BY C1.regionID) AS DENSE_clone_regionID
	  FROM COUNT_country_CTE AS CTE1
	  INNER JOIN dbo.countries AS C1
		  ON CTE1.country = C1.country) AS clone_regionID
INNER JOIN dbo.countries AS C2
	ON clone_regionID.country = C2.country
WHERE clone_regionID.DENSE_clone_regionID > 1;

/*  Valori regionID da correggere:
DA 137 id - Maldives - MDV alpcode - 2 regionID --> A: 138 id - 4 regionID
DA: 168 id - North Macedonia - MKD alpcode - 7 regionID --> A: 167 id - 5 regionID.
DA: 208 id - Solomon Islands - SLB alpcode - 4 regionID --> A: 209 id - 7 regionID. */

DELETE FROM dbo.countries WHERE countryID2 IN (137, 168, 208);

-- workingArea: controllo nei paesi di destinazione
 

/* DA 137 id - Maldives - MDV alpcode - 2 regionID --> A: 138 id - 4 regionID
DA: 208 id - Solomon Islands - SLB alpcode - 4 regionID --> A: 209 id - 7 regionID. */
UPDATE dbo.workingArea SET cname_receiveID = 138, region_receive = 4 WHERE cname_receive = 'Maldives'; -- 170 righe.

UPDATE dbo.workingArea SET cname_receiveID = 209, region_receive = 7 WHERE cname_receive = 'Solomon Islands'; -- 131 righe.

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_sendID IN (137, 168, 208, 138, 167, 209)
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

UPDATE dbo.workingArea SET cname_sendID = 167, region_send = 5 WHERE cname_sendID = 168; -- 1 riga

------------------------------------------------------------------------------------------------------------------------------
-- Controllo di alpcode discordanti per valori country multipli:

WITH COUNT_alpcode_CTE AS ( 
	SELECT multiple_alpcode_sub.alpcode
	FROM (SELECT alpcode, country,
			RANK() OVER (PARTITION BY alpcode ORDER BY country ) AS ROW_cloneAlpcode
		  FROM dbo.countries) AS multiple_alpcode_sub
	WHERE multiple_alpcode_sub.ROW_cloneAlpcode > 1 AND multiple_alpcode_sub.alpcode IS NOT NULL
	GROUP BY multiple_alpcode_sub.alpcode)
-- +
SELECT C.countryID2, C.country, C.alpcode
FROM COUNT_alpcode_CTE AS CTE2
INNER JOIN dbo.countries AS C
	 ON CTE2.alpcode = C.alpcode
ORDER BY C.alpcode ASC;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country IN ('Turkmenistan', 'Azerbaijan');
-- DA: 232 id - Turkmenistan - AZE --> A: 233 id - TKM.
DELETE FROM dbo.countries WHERE countryID2 = 232;

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('Turkmenistan', 'Azerbaijan')
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

UPDATE dbo.workingArea SET cname_receiveID = 233, ccodealp_receive = 'TKM' WHERE cname_receiveID = 232; -- 1 riga

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send IN ('Turkmenistan', 'Azerbaijan')
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country IN ('Belize', 'Honduras');
-- DA: 100 id - Honduras - BLZ --> A: 101 id - HND.

DELETE FROM dbo.countries WHERE countryID2 = 100;

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('Belize', 'Honduras')
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

UPDATE dbo.workingArea SET cname_receiveID = 101, ccodealp_receive = 'HND' WHERE cname_receiveID = 100; -- 1 riga

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send IN ('Belize', 'Honduras')
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country IN ('Central African Empire', 'Central African Republic');

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('Central African Empire', 'Central African Republic')
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send IN ('Central African Empire', 'Central African Republic')
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country IN ('Cyprus', 'Czechia');
-- DA: 58 id - Czechia - CYP --> A: 59 id - CZE.
DELETE FROM dbo.countries WHERE countryID2 = 58;

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('Cyprus', 'Czechia')
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

UPDATE dbo.workingArea SET cname_receiveID = 59, ccodealp_receive = 'CZE' WHERE cname_receiveID = 58; -- 1 riga

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send IN ('Cyprus', 'Czechia')
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country LIKE '%German%';

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive LIKE '%German%'
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send LIKE '%German%'
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country IN ('Kampuchea', 'Cambodia');

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('Kampuchea', 'Cambodia')
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send IN ('Kampuchea', 'Cambodia')
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country = 'Niue' OR country LIKE '%Korea%'
-- DA: 166 id - Niue - PRK --> A: 165 id - NIU.
DELETE FROM dbo.countries WHERE countryID2 = 166;

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive = 'Niue' OR cname_receive LIKE '%Korea%'
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

UPDATE dbo.workingArea SET cname_receiveID = 165, ccodealp_receive = 'NIU' WHERE cname_receiveID = 166; -- 12 righe

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send = 'Niue' OR cname_send LIKE '%Korea%'
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country LIKE '%Viet Nam%';

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive LIKE '%Viet Nam%'
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send LIKE '%Viet Nam%'
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

---

SELECT countryID2, country, alpcode, regionID 
FROM dbo.countries
WHERE country LIKE 'Yemen%';

-- workingArea: controllo nei paesi di destinazione
SELECT cname_receiveID, cname_receive, ccodealp_receive, region_receive
FROM dbo.workingArea
WHERE cname_receive LIKE 'Yemen%'
GROUP BY cname_receiveID, cname_receive, ccodealp_receive, region_receive;

-- workingArea: controllo nei paesi d'origine
SELECT cname_sendID, cname_send, ccodealp_send, region_send
FROM dbo.workingArea
WHERE cname_send LIKE 'Yemen%'
GROUP BY cname_sendID, cname_send, ccodealp_send, region_send;

-----------------------------------------------------------------------------------------------------------------------------
-- Creazione e popolamento tab updatedCountries. 
-- Paragone con tab contries con eventuali cancellazioni nella stessa e aggiornamenti in tab workingarea.

-- Ho scaricato da Wikipedia un file con dati aggiornati sui paesi attuali (nome completo e alpcode).
-- Con i paesi scritti allo stesso modo di quelli presenti nella tab. countries.
-- Tasto destro su GenDip -> Attività -> Importa file flat -> nomino la tabella "updatedCountries"
-- Flaggare "Consenti valori NULL".
-- Ho impostato manualmente column1 come NVARCHAR(10) e l'ho rinominato 'updatedAlpcode'.
-- Ho impostato manualmente column2 come NVARCHAR(100) e l'ho rinominato 'updatedCountry'.

SELECT updatedAlpcode, updatedCountry FROM dbo.updatedCountries;
-- Nella colonna updatedCountry sono presenti anche delle cifre numeriche a rappresentanza del valore "regionID".

-- Aggiunta colonna regionID.
ALTER TABLE dbo.updatedCountries ADD updatedRegionID INT NULL;

-- Controllo pre UPDATE
SELECT TRIM(SUBSTRING(updatedCountry, 1, CHARINDEX(RIGHT(updatedCountry, 1), updatedCountry) - 1)) AS country,
	   TRIM(RIGHT(updatedCountry, 1)) AS updatedRegionID
FROM dbo.updatedCountries;

/* TRIM:  rimuove gli spazi vuoti all'inizio e alla fine di una stringa, 
	oppure i caratteri specificati (non solo spazi vuoti).

SUBSTRING è utilizzata per estrarre una parte specifica di una stringa.
SUBSTRING(string_expression, start, length)

Per dividere una stringa basata su un delimitatore, si usano generalmente funzioni come 
SUBSTRING, CHARINDEX, LEFT, RIGHT e LEN per ottenere i risultati desiderati.
CHARINDEX(substring, string_expression, start_position)


SUBSTRING viene utilizzata per estrarre una sottostringa da una stringa più grande,
CHARINDEX può essere utilizzata per trovare la posizione di un delimitatore all'interno di una stringa. */

/* CHARINDEX(RIGHT(updatedCountry, 1), updatedCountry) - 1) --> -1 viene utilizzato per estrarre la sottostringa 
dalla posizione 1 fino alla posizione prima dell'ultimo carattere, rimarrà quindi lo spazio ' ' dopo il nome
del paese che verrà eliminato da TRIM. */

/* Rimuovere tutti gli spazi vuoti.
SELECT REPLACE(updatedCountry, ' ', '') FROM dbo.updatedCountries; */

UPDATE dbo.updatedCountries
SET updatedCountry = TRIM(SUBSTRING(updatedCountry, 1, CHARINDEX(RIGHT(updatedCountry, 1), updatedCountry) - 1)),
    updatedRegionID = TRIM(RIGHT(updatedCountry, 1)); -- 249 righe

-- Aggiunta colonna che fungerà da PK.
ALTER TABLE dbo.updatedCountries ADD updatedCountryID INT IDENTITY(1,1);

ALTER TABLE dbo.updatedCountries ADD CONSTRAINT PK_updatedCountries PRIMARY KEY (updatedCountryID); -- PK_TargetTable

-- Replico come per tab countries: se faccio solo Alpcode UNIQUE mi da errore perché più valori NULL non sono possibili.
ALTER TABLE dbo.updatedCountries ADD CONSTRAINT UQ_updatedCountries_alpcode_country UNIQUE (updatedAlpcode, updatedCountry); 
-- UQ_TargetTable_TargetColumn1_TargetColumn2

SELECT updatedCountryID, updatedAlpcode, updatedCountry, updatedRegionID FROM dbo.updatedCountries; -- 249 righe

-- Differenze tra countries e updatedCountries 

-- EXCEPT in CTE
WITH CTE AS (
			 SELECT country, alpcode, regionID
			 FROM dbo.countries
				 EXCEPT
			 SELECT updatedCountry, updatedAlpcode, updatedRegionID 
			 FROM dbo.updatedCountries)
SELECT C.countryID2, C.alpcode, C.country, C.regionID, UC.updatedRegionID
FROM dbo.countries AS C
INNER JOIN CTE
	ON C.country = CTE.country
LEFT JOIN dbo.updatedCountries AS UC
	ON C.country = UC.updatedCountry
ORDER BY C.alpcode; -- 22 righe

/* 1) Paesi con alpcode a NULL:
115 id Korea - 118 id Kosovo - 239 id Virgin Islands --> per imprecisazione geografica o alpcode non ufficialmente riconosciuto.

2) Paesi non più esistenti (unupdatedCountry):
- 41 id CAF Central African Empire CAF --> dal 1976 al 1979. - OGGI: 42 id - CAF - Central African Republic
- 58 id CSK Czechoslovakia CSK --> dal 1918 al 1992. - OGGI: Czechia, Slovakia.
- 82 id DDR German Democratic Republic --> dal 1968 al 1990. - OGGI: Germany.
- 84 id DEU Germany, Federal Republic of --> dal 1968 al 1990. - OGGI: Germany.
- 111 id KHM Kampuchea --> dal 1976 al 1979. - OGGI: Cambodia.
- 194 id SCG Serbia and Montenegro --> dal 2003 al 2006. OGGI: Serbia, Montenegro.
- 232 id SUN USSR --> dal 1922 al 1991. - OGGI: Russian Federation.
- 237 id VDR Viet Nam, Democratic Republic of --> dal 1955 al 1975 (North Viet Nam). - OGGI: Viet Nam.
- 238 VNM Viet Nam, Republic of --> dal 1955 al 1975 (South Viet Nam). - OGGI: Viet Nam.
- 243 id YEM Yemen, Arab Republic of --> dal 1962 al 1990. - OGGI: Yemen.
- 244 id YMD Yemen, People's Democratic Republic of --> dal 1967 al 1990. - OGGI: Yemen.
- 245 id YUG - Yugoslavia YUG - dal 1918 al 1991/1992. 
	- EX COUNTRY: Serbia, Croazia, Macedonia, Montenegro, Slovenia e Bosnia-Erzegovina 
	e le due province autonome serbe del Kossovo e della Vojvodina. */

-- regionID non combacianti tra tab countries e updatedCountries.
WITH CTE AS (
			 SELECT country, alpcode, regionID
			 FROM dbo.countries
				 EXCEPT
			 SELECT updatedCountry, updatedAlpcode, updatedRegionID 
			 FROM dbo.updatedCountries)
SELECT C.countryID2, C.alpcode, C.country, C.regionID, UC.updatedRegionID
FROM dbo.countries AS C
INNER JOIN CTE
	ON C.country = CTE.country
LEFT JOIN dbo.updatedCountries AS UC
	ON C.country = UC.updatedCountry
WHERE UC.updatedRegionID IS NOT NULL
ORDER BY C.alpcode; -- 7 righe

/* regionID errato nella tab countries, corretto in updatedCountries:
- 80 id - ATF - French Southern Territories - DA 2 regionID --> A: 3 regionID (Antarctic).
- 56 id - CUW - Curaçao - DA: 8 regionID --> A: 6 regionID (North America) come Aruba e Bonaire (le Antille Olandesi)
- 66 id - EGY - Egypt - DA: 4 regionID: A: 2 regionID (Africa).
- 97 id - GUY - Guyana - DA: 2 regionID --> A: 8 (South America).
- 169 id - MNP - Northern Mariana Islands - DA: 4 regionID --> A: 7 (Oceania).
- 180 id - PCN - Pitcairn - DA: 4 regionID --> A: 7 (Oceania).
- 228 id - TON - Tonga - DA: 2 regionID --> A: 7 (Oceania). */

-- CORREZIONE regionID non combacianti tra tab countries e updatedCountries.
CREATE PROCEDURE usp_regionID_UPDATE
	@new_regionID INT,
	@current_countryID INT
AS
BEGIN
	SET NOCOUNT OFF;

	UPDATE dbo.countries SET regionID = @new_regionID WHERE countryID2 = @current_countryID;

END;
GO

EXEC usp_regionID_UPDATE @new_regionID = 3, @current_countryID = 80;
EXEC usp_regionID_UPDATE @new_regionID = 6, @current_countryID = 56;
EXEC usp_regionID_UPDATE @new_regionID = 2, @current_countryID = 66;
EXEC usp_regionID_UPDATE @new_regionID = 8, @current_countryID = 97;
EXEC usp_regionID_UPDATE @new_regionID = 7, @current_countryID = 169;
EXEC usp_regionID_UPDATE @new_regionID = 7, @current_countryID = 180;
EXEC usp_regionID_UPDATE @new_regionID = 7, @current_countryID = 228;

DROP PROCEDURE usp_regionID_UPDATE;

-- Correzione in workingArea:

SELECT cname_sendID, ccodealp_send, cname_send, region_send
FROM dbo.workingArea
WHERE cname_sendID IN (80, 56, 66, 97, 169, 180, 228)
GROUP BY cname_sendID, ccodealp_send, cname_send, region_send
ORDER BY ccodealp_send;

UPDATE dbo.workingArea SET region_send = 2 WHERE cname_sendID = 66; -- 1183 righe
UPDATE dbo.workingArea SET region_send = 8 WHERE cname_sendID = 97; -- 136 righe
UPDATE dbo.workingArea SET region_send = 7 WHERE cname_sendID = 228; -- 33 righe

SELECT cname_receiveID, ccodealp_receive, cname_receive, region_receive
FROM dbo.workingArea
WHERE cname_receiveID IN (80, 56, 66, 97, 169, 180, 228)
GROUP BY cname_receiveID, ccodealp_receive, cname_receive, region_receive
ORDER BY ccodealp_receive;

CREATE PROCEDURE usp_regionReceive_UPDATE
	@new_regionReceive INT,
	@current_cnameReceiveID INT
AS
BEGIN
	SET NOCOUNT OFF;

	UPDATE dbo.workingArea SET region_receive = @new_regionReceive WHERE cname_receiveID = @current_cnameReceiveID;

END;
GO

EXEC usp_regionReceive_UPDATE @new_regionReceive = 3, @current_cnameReceiveID = 80; -- 1 riga
EXEC usp_regionReceive_UPDATE @new_regionReceive = 6, @current_cnameReceiveID = 56; -- 5 righe
EXEC usp_regionReceive_UPDATE @new_regionReceive = 2, @current_cnameReceiveID = 66; -- 1088 righe
EXEC usp_regionReceive_UPDATE @new_regionReceive = 8, @current_cnameReceiveID = 97; -- 234 righe
EXEC usp_regionReceive_UPDATE @new_regionReceive = 7, @current_cnameReceiveID = 169; -- 2 righe
EXEC usp_regionReceive_UPDATE @new_regionReceive = 7, @current_cnameReceiveID = 180; -- 2 righe
EXEC usp_regionReceive_UPDATE @new_regionReceive = 7, @current_cnameReceiveID = 228; -- 122 righe

DROP PROCEDURE usp_regionReceive_UPDATE;

-- Da verificare dopo aver fatto le modifiche in countries su regionID.
-- Paesi aggiornati non presenti in countries
SELECT updatedCountry, updatedAlpcode, updatedRegionID
FROM dbo.updatedCountries
	EXCEPT
SELECT country, alpcode, regionID
FROM dbo.countries; -- 18 paesi

-- EXTRA:
-- Versione con NOT EXISTS:
SELECT countryID2, country, alpcode, regionID
FROM dbo.countries AS C
WHERE NOT EXISTS (
					  SELECT updatedCountry, updatedAlpcode, updatedRegionID
					  FROM dbo.updatedCountries AS UC
					  WHERE (C.alpcode = UC.updatedAlpcode
					  AND C.country = UC.updatedCountry
					  AND C.regionID = UC.updatedRegionID)
				  ); -- 16 righe
-----------------------------------------------------------------------------------------------------------------------------
-- Controlli in workingArea.

WITH CTE_UNION AS (
					SELECT cname_send, ccodealp_send, region_send
					FROM dbo.workingArea
							UNION
					SELECT cname_receive, ccodealp_receive, region_receive
					FROM dbo.workingArea)
SELECT CTE.cname_send, C.country, C.countryID2
FROM dbo.countries AS C
RIGHT JOIN CTE_UNION AS CTE
	ON CTE.cname_send = C.country OR (CTE.cname_send IS NULL AND C.country IS NULL)
	AND CTE.ccodealp_send = C.alpcode OR (CTE.ccodealp_send IS NULL AND C.alpcode IS NULL)
	AND CTE.region_send = C.regionID; -- 247 righe

-----------------------------------------------------------------------------------------------------------------------------

/* Tab countries: 
Eliminazione countryID (PK) e countryID2 (copia di PK).
Aggiornamento di countryID3 come nuova PK con valori aggiornati.
Tab workingArea: aggiornamento colonne FK con nuovi valori. */

-- Eliminazione PK e copia. Crezione nuova PK.
ALTER TABLE dbo.countries DROP COLUMN countryID; -- eliminazione per far ripartire il conteggio di INDENTITY.
ALTER TABLE dbo.countries DROP COLUMN countryID2;
ALTER TABLE dbo.countries ADD countryID INT IDENTITY(1,1);

ALTER TABLE dbo.countries ADD CONSTRAINT PK_countries PRIMARY KEY (countryID); -- PK_TargetTable

-- Se faccio solo Alpcode UNIQUE mi da errore perché più valori NULL non sono possibili (Ma ChatGPT mi dice che non è così).
ALTER TABLE dbo.countries ADD CONSTRAINT UQ_countries_country_alpcode UNIQUE (country, alpcode); -- UQ_TargetTable_TargetColumn1_TargetColumn2

ALTER TABLE dbo.countries
ADD CONSTRAINT FK_countries_regions FOREIGN KEY (regionID) REFERENCES regions(regionID) -- FK_TargetTable_SourceTable
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

SELECT * FROM dbo.countries; -- 247 righe

EXEC usp_cnameSendID_UPDATE; -- 94.509 righe

DROP PROCEDURE usp_cnameSendID_UPDATE; -- DA EFFETTUARE

ALTER TABLE dbo.workingArea
ADD CONSTRAINT FK_workingArea_sending_countries -- FK_TargetTable_sending_SourceTable
FOREIGN KEY (cname_sendID)
REFERENCES countries(countryID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

-- Controllo
SELECT W.cname_send, W.ccodealp_send, W.cname_sendID, C.countryID
FROM dbo.workingArea AS W
LEFT JOIN dbo.Countries AS C
	ON W.cname_sendID = C.countryID
GROUP BY W.cname_send, W.ccodealp_send, W.cname_sendID, C.countryID; -- 211 righe

EXECUTE usp_cnameReceiveID_UPDATE; -- 94.509 righe

DROP PROCEDURE usp_cnameReceiveID_UPDATE; -- DA EFFETTUARE

ALTER TABLE dbo.workingArea
ADD CONSTRAINT FK_workingArea_receiving_countries -- FK_TargetTable_receiving_SourceTable
FOREIGN KEY (cname_receiveID)
REFERENCES countries(countryID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

-- Controllo
SELECT W.cname_receive, W.ccodealp_receive, W.cname_receiveID, C.countryID
FROM dbo.workingArea AS W
LEFT JOIN dbo.countries AS C
	ON W.cname_receiveID = C.countryID
GROUP BY W.cname_receive, W.ccodealp_receive, W.cname_receiveID, C.countryID; -- 246 righe

-----------------------------------------------------------------------------------------------------------------------------

-- tab countries: inserimento della FK in collegamento alla PK di tab updatedCountries, può essere NULL. 

UPDATE C
SET C.updatedCountryID = U.updatedCountryID
FROM dbo.updatedCountries AS U
RIGHT JOIN dbo.countries AS C
	ON EXISTS (SELECT U.updatedAlpcode, U.updatedCountry
					INTERSECT
			   SELECT C.alpcode, C.country); -- 247 righe

ALTER TABLE dbo.countries
ADD CONSTRAINT FK_countries_updatedCountries FOREIGN KEY (updatedCountryID) 
REFERENCES updatedCountries(updatedCountryID) -- FK_TargetTable_SourceTable
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

-- Controllo.
SELECT C.countryID, C.country, C.updatedCountryID, U.updatedCountryID AS updatedCountry_PK
FROM dbo.countries AS C
LEFT JOIN dbo.updatedCountries AS U
	ON C.updatedCountryID = U.updatedCountryID
ORDER BY C.countryID ASC;

SELECT countryID, country, alpcode, updatedCountryID
FROM dbo.countries AS C
WHERE NOT EXISTS (SELECT updatedCountry, updatedAlpcode
	FROM dbo.updatedCountries AS UC
	WHERE C.alpcode = UC.updatedAlpcode); -- 11 righe
-----------------------------------------------------------------------------------------------------------------------------