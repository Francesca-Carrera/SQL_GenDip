--------------------------------------------------------------------------------------------------------------------------------------------
-- Creazione e popolamento di tab regions.

CREATE TABLE dbo.regions (
    regionID INT IDENTITY(1,1),
    region VARCHAR(15) NULL,
    CONSTRAINT PK_regions PRIMARY KEY (regionID), 
			-- PK_TargetTable
    CONSTRAINT UQ_regions_region UNIQUE (region) 
			-- UQ_TargetTable_TargetColumn
)
GO
INSERT INTO dbo.regions (region)
VALUES (NULL), ('Africa'), ('Antarctica'), ('Asia'), 
	   ('Europe'), ('North America'), ('Oceania'), ('South America'); -- 8 righe
--------------------------------------------------------------------------------------------------------------------------------------------
-- Creazione e popolameto di tab countries. 

/* Impiego la CTE per estrarre valori univoci dei paesi di invio
e di destinazione con i loro rispettivi dati, indicanti la
regione geografica di appartenenza e il codice alpha a tre caratteri.
Utilizzerò poi questa lista per popolare parte della tabella countries,
a cui ho aggiunto la colonna countryID, che fungerà da futura PK, e una sua copia.
Ho aggiunto, inoltre, la colonna updatedCountryID, il cui ruolo sarà di chiave esterna 
in riferimento alla PK della tab updatedCountries, non ancora creata. 

Funzione della colonna countryID2.
Sarà la copia di countryID, in versione non IDENTITY in modo che sia modificabile.
Come cname_sendID e cname_receiveID fungono da collegamento momentaneo di tab workingArea, 
countryID2 svolge il medesimo ruolo di tab countries, per apportare modifiche ai paesi di invio 
e di destinazione in entrambe le tabelle menzionate.*/

WITH cnameUNION_CTE
     AS (SELECT cname_send,
                ccodealp_send,
                region_send
         FROM   dbo.workingArea
         UNION
         SELECT cname_receive,
                ccodealp_receive,
                region_receive
         FROM   dbo.workingArea)
SELECT IDENTITY(int, 1, 1) AS countryID,
       NULL                AS countryID2, 
       cname_send          AS country,
       ccodealp_send       AS alpcode,
       region_send         AS regionID,
       NULL                AS updatedCountryID
INTO   dbo.countries
FROM   cnameUNION_CTE
ORDER BY cname_send; -- 259 righe

-- Popolamento di countryID2, copia di countryID.
UPDATE dbo.countries 
SET countryID2 = countryID; -- 259 righe
--------------------------------------------------------------------------------------------------------------------------------------------
-- Popolamento di cname_sendID e cname_receiveID (collegamento momentaneo di tab workingArea).

/* Ho creato una Stored Procedure per popolare cname_sendID e cname_receiveID 
con il valore di countryID, poichè impiegherò nuovamente l'istruzione.
Utilizzo l'operatore INTERSECT in questo contesto come forma più concisa di 
verificare la corrispondenza tra le colonne delle due tabelle, senza dover 
scrivere esplicitamente tutte le condizioni di corrispondenza per ogni colonna,
gestendo automaticamente i valori NULL. */

-- Popolamento di cname_sendID.
CREATE PROCEDURE usp_cnameSendID_UPDATE
	      -- userStoredProcedure_column_action
AS
  BEGIN
      SET NOCOUNT OFF;
      -- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
      UPDATE W
      SET    W.cname_sendID = C.countryID
      FROM   dbo.workingArea AS W
             LEFT JOIN dbo.countries AS C
                    ON EXISTS (SELECT W.cname_send,
                                      W.ccodealp_send,
                                      W.region_send
                               INTERSECT
                               SELECT C.country,
                                      C.alpcode,
                                      C.regionid)
  END;
GO
EXEC usp_cnameSendID_UPDATE;  -- 94.509 righe

-- NB. versione con forma non concisa.
UPDATE W
SET    W.cname_sendID = C.countryID
FROM   dbo.workingArea AS W
       INNER JOIN dbo.countries AS C
               ON ( W.cname_send = C.country
                     OR ( W.cname_send IS NULL
                          AND C.country IS NULL ) )
                  AND ( W.ccodealp_send = C.alpcode
                         OR ( W.ccodealp_send IS NULL
                              AND C.alpcode IS NULL ) )
                  AND ( W.region_send = C.regionID );

-- Popolamento di cname_receiveID.
CREATE PROCEDURE usp_cnameReceiveID_UPDATE
	      -- userStoredProcedure_column_action
AS
  BEGIN
      SET NOCOUNT OFF;
      -- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
      UPDATE W
      SET    W.cname_receiveID = C.countryID
      FROM   dbo.workingArea AS W
             LEFT JOIN dbo.countries AS C
                    ON EXISTS (SELECT W.cname_receive,
                                      W.ccodealp_receive,
                                      W.region_receive
                               INTERSECT
                               SELECT C.country,
                                      C.alpcode,
                                      C.regionid)
  END;
GO
EXECUTE usp_cnameReceiveID_UPDATE; -- 94.509 righe
--------------------------------------------------------------------------------------------------------------------------------------------
-- Tab countries: verifica dei valori NULL nelle colonne.

SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID 
FROM dbo.countries 
WHERE country IS NULL 
	  OR alpcode IS NULL 
	  OR regionID IS NULL;-- 7 righe

/* Paesi con alpcode a NULL:
(1)15 id Azores, (2)118 id Korea, (3)121 id Kosovo, (4)212 id South Ossetia, (5)249 id Virgin Islands, (6)252 id Yemen. */

---------------------------------------
-- 1) Azores.

-- Azores fa parte del Portogallo.
SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID  
FROM dbo.countries 
WHERE country IN ('Azores', 'Portugal');
-- DA: 15 id - Azores - NULL alpcode - 6 regionID --> A: 182 id - Portugal - PRT alpcode - 5 regionID.

-- Eliminazione del record con country Azores da tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 15;

-- workingArea: controllo nei paesi di destinazione.
SELECT cname_receiveID, 
	   cname_receive, 
	   ccodealp_receive, 
	   region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('Azores', 'Portugal')
GROUP BY cname_receiveID, 
		 cname_receive, 
		 ccodealp_receive, 
		 region_receive;

-- Aggiornamento del record contenente Azores nei paesi di destinazione.
UPDATE dbo.workingArea
SET cname_receiveID = 182, 
	cname_receive = 'Portugal', 
	ccodealp_receive = 'PRT', 
	region_receive = 5
WHERE cname_receiveID = 15; -- 1 riga.

-- workingArea: controllo nei paesi d'invio.
SELECT cname_sendID, 
	   cname_send, 
	   ccodealp_send, 
	   region_send
FROM dbo.workingArea
WHERE cname_send IN ('Azores', 'Portugal')
GROUP BY cname_sendID, 
		 cname_send, 
		 ccodealp_send, 
		 region_send;
---------------------------------------
-- 2) Korea.

SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID 
FROM dbo.countries 
WHERE country LIKE '%Korea%';
-- Korea ha l'alpcode a NULL perché non è meglio specificato se sia Nord o Sud.
---------------------------------------
-- 3) Kosovo.

SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID 
FROM dbo.countries 
WHERE country = 'Kosovo';
/* Vi sono 2 record con country Kosovo, uno con alpcode a NULL e l'altro con XKO.
Kosovo non ha un alpcode riconosciuto in maniera ufficiale, quindi il record con id 122 e alpcode XKO non è corretto.
DA: 122 id - Kosovo - XKO alpcode - 5 regionID --> A: 121 id - Kosovo - NULL alpcode - 5 regionID. */

-- Eliminazione del record con country Kosovo e alpcode XKO da tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 122;

-- workingArea: controllo nei paesi di destinazione.
SELECT cname_receiveID, 
	   cname_receive, 
	   ccodealp_receive, 
	   region_receive
FROM dbo.workingArea
WHERE cname_receive = 'Kosovo'
GROUP BY cname_receiveID, 
		 cname_receive, 
		 ccodealp_receive, 
		 region_receive;

-- Aggiornamento del record contenente Kosovo con alpcode XKO nei paesi di destinazione.
UPDATE dbo.workingArea
SET cname_receiveID = 121, 
	ccodealp_receive = NULL
WHERE cname_receiveID = 122; -- 138 righe

-- workingArea: controllo nei paesi d'invio.
SELECT cname_sendID, 
	   cname_send, 
	   ccodealp_send, 
	   region_send
FROM dbo.workingArea
WHERE cname_send = 'Kosovo'
GROUP BY cname_sendID, 
		 cname_send, 
		 ccodealp_send, 
		 region_send;
---------------------------------------
-- 4) South Ossetia.

-- South Ossetia fa ufficialmente parte della Georgia.
SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID 
FROM dbo.countries 
WHERE country IN ('South Ossetia', 'Georgia');
-- DA: 212 id - South Ossetia - NULL alpcode - 4 regionID --> A: 83 id - Georgia - GEO alpcode - 4 regionID.

-- Eliminazione del record con South Ossetia da tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 212;

-- workingArea: controllo nei paesi di destinazione.
SELECT cname_receiveID, 
	   cname_receive, 
	   ccodealp_receive, 
	   region_receive
FROM dbo.workingArea
WHERE cname_receive IN ('South Ossetia', 'Georgia')
GROUP BY cname_receiveID, 
		 cname_receive, 
		 ccodealp_receive, 
		 region_receive;

-- Aggiornamento del record contenente South Ossetia nei paesi di destinazione.
UPDATE dbo.workingArea
SET cname_receiveID = 83, 
	cname_receive = 'Georgia', 
	ccodealp_receive = 'GEO'
WHERE cname_receiveID = 212; -- 1 riga

-- workingArea: controllo nei paesi d'invio.
SELECT cname_sendID, 
	   cname_send, 
	   ccodealp_send, 
	   region_send
FROM dbo.workingArea
WHERE cname_send IN ('South Ossetia', 'Georgia')
GROUP BY cname_sendID, 
		 cname_send, 
		 ccodealp_send, 
		 region_send;
---------------------------------------
-- 5) Virgin Islands.

SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID 
FROM dbo.countries 
WHERE country LIKE '%Virgin Islands%';
-- Virgin Islands ha l'alpcode a NULL perché non è meglio specificato se sia British o Usa.
---------------------------------------
-- 6) Yemen.

SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID 
FROM dbo.countries 
WHERE country LIKE '%Yemen%';
/* Vi sono 5 record con country Yemen, uno di questi ha alpcode NULL.
DA: 252 id - NULL alpcode --> A: 253 id - Yemen - YEM alpocode - 4 regionID.

255 id con alpcode scorretto.
DA: 255 id - YME --> A: 254 id - YEM - Yemen, Arab Republic of.

256 id - YMD - Yemen, People's Democratic Republic of - record corretto. */

-- Eliminazione dei record errati con Yemen da tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 IN (252, 255);

-- workingArea: controllo nei paesi di destinazione.
SELECT cname_receiveID, 
	   cname_receive, 
	   ccodealp_receive, 
	   region_receive
FROM dbo.workingArea
WHERE cname_receive LIKE '%Yemen%'
GROUP BY cname_receiveID, 
		 cname_receive, 
		 ccodealp_receive, 
		 region_receive;

-- workingArea: controllo nei paesi d'invio.
SELECT cname_sendID, 
	   cname_send, 
	   ccodealp_send, 
	   region_send
FROM dbo.workingArea
WHERE cname_send LIKE '%Yemen%'
GROUP BY cname_sendID, 
		 cname_send, 
		 ccodealp_send, 
		 region_send;

-- Aggiornamento dei record contenenti Yemen nei paesi di invio.
UPDATE dbo.workingArea 
SET cname_sendID = 253, 
	ccodealp_send = 'YEM' 
WHERE cname_sendID = 252; -- 1 riga.

UPDATE dbo.workingArea 
SET cname_sendID = 254, 
	ccodealp_send = 'YEM' 
WHERE cname_sendID = 255; -- 67 righe.
--------------------------------------------------------------------------------------------------------------------------------------------
-- Correzione delle regioni geografiche discordanti nei paesi con valori duplicati.

/* Nella CTE duplicateCountries seleziono i paesi duplicati, utilizzando una sottoquery nella clausola WHERE.
Nella CTE denseRank_regions utilizzo la funzione finestra DENSE_RANK() per assegnare un rango ai paesi duplicati identificati nella CTE
precedente, basato sulla ripetizioni (o non) delle regioni geografiche.
Nella SELECT finale unisco la tabella countries con la CTE denseRank_regions, filtrando dalla stessa i paesi con i valori
delle regioni geografiche non ripetute, che risulteranno essere quindi discordanti. */
WITH duplicateCountries_CTE
     AS (SELECT countryID2,
                country,
                alpcode,
                regionID
         FROM   dbo.countries
         WHERE  country IN (SELECT country
                            FROM   dbo.countries
                            GROUP  BY country
                            HAVING COUNT(*) > 1)),
     denseRankRegions_CTE
     AS (SELECT countryID2,
                country,
                alpcode,
                regionID,
                DENSE_RANK()
                  OVER (
                    PARTITION BY country
                    ORDER BY regionID) AS denseRank_regionID
         FROM   duplicateCountries_CTE)
SELECT C.countryID2,
       C.country,
       C.alpcode,
	   C.regionID,
       R.region
FROM   dbo.countries AS C
       LEFT JOIN denseRankRegions_CTE AS DC
              ON C.country = DC.country
	   LEFT JOIN dbo.regions AS R
			  ON C.regionID = R.regionID
WHERE  DC.denseRank_regionid > 1; 

/*  Valori regionID da correggere:
DA 137 id - Maldives - MDV alpcode - 2 regionID --> A: 138 id - 4 regionID
DA: 168 id - North Macedonia - MKD alpcode - 7 regionID --> A: 167 id - 5 regionID.
DA: 208 id - Solomon Islands - SLB alpcode - 4 regionID --> A: 209 id - 7 regionID. */

-- Eliminazione dei record errati in tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 IN (137, 168, 208);

-- workingArea: controllo nei paesi di destinazione.
SELECT cname_receiveID, 
	   cname_receive, 
	   ccodealp_receive, 
	   region_receive
FROM dbo.workingArea
WHERE cname_receiveID IN ( 137, 168, 208, 
						   138, 167, 209 )
GROUP BY cname_receiveID, 
		 cname_receive, 
		 ccodealp_receive, 
		 region_receive;

-- Aggiornamento dei record nei paesi di destinazione.
UPDATE dbo.workingArea 
SET cname_receiveID = 138, 
region_receive = 4 
WHERE cname_receive = 'Maldives'; -- 170 righe.

UPDATE dbo.workingArea 
SET cname_receiveID = 209, 
region_receive = 7 
WHERE cname_receive = 'Solomon Islands'; -- 131 righe.

-- workingArea: controllo nei paesi d'invio.
SELECT cname_sendID, 
	   cname_send, 
	   ccodealp_send, 
	   region_send
FROM dbo.workingArea
WHERE cname_sendID IN ( 137, 168, 208, 
						138, 167, 209 )
GROUP BY cname_sendID, 
		 cname_send, 
		 ccodealp_send, 
		 region_send;

-- Aggiornamento dei record nei paesi d'invio.
UPDATE dbo.workingArea 
SET cname_sendID = 167, 
	region_send = 5 
WHERE cname_sendID = 168; -- 1 riga
--------------------------------------------------------------------------------------------------------------------------------------------
-- Correzione dei codici alpha (a tre caratteri) duplicati.

WITH duplicateAlpcode
	AS (
			SELECT alpcode, COUNT(alpcode) AS alpcodeCount
			FROM dbo.countries
			GROUP BY alpcode
			HAVING COUNT(alpcode) > 1)
SELECT C.countryID2, C.country, DA.alpcode
FROM duplicateAlpcode AS DA
LEFT JOIN dbo.countries AS C
	ON DA.alpcode = C.alpcode

----
-- Procedure in country
CREATE PROCEDURE usp_country_SELECT2
			  -- userStoredProcedure_column_action
				@country1 NVARCHAR(55),
				@country2 NVARCHAR(55)
AS
	BEGIN
		SET NOCOUNT OFF;
		-- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
		SELECT countryID2, 
			   country, 
			   alpcode, 
			   regionID  
		FROM dbo.countries 
		WHERE country IN (@country1, @country2)
	END;
GO
EXEC usp_country_SELECT2 'Azores', 'Portugal';

CREATE PROCEDURE usp_country_SELECTwithLIKE
						  -- userStoredProcedure_column_action
    @country NVARCHAR(55)
AS
BEGIN
    SET NOCOUNT OFF;
	-- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
    SELECT countryID2,
           country,
           alpcode,
           regionID
    FROM dbo.countries
    WHERE country LIKE '%' + @country + '%';
END;
GO
EXEC usp_country_SELECTwithLIKE 'Korea';

------------
-- cname_receive

CREATE PROCEDURE usp_cnameReceive_SELECT2
			  -- userStoredProcedure_column_action
				@cname_receive1 NVARCHAR(55),
				@cname_receive2 NVARCHAR(55)
AS
BEGIN
	SET NOCOUNT OFF;
	-- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
	SELECT cname_receiveID, 
		   cname_receive, 
		   ccodealp_receive, 
		   region_receive
	FROM dbo.workingArea
	WHERE cname_receive IN (@cname_receive1, @cname_receive2)
	GROUP BY cname_receiveID, 
			 cname_receive, 
			 ccodealp_receive, 
			 region_receive;
END;
GO
EXEC usp_cnameReceive_SELECT2 'Turkmenistan', 'Azerbaijan';

CREATE PROCEDURE usp_cnameReceive_SELECTwithLIKE
			  -- userStoredProcedure_column_action
				 @cname_receive NVARCHAR(55)
AS
BEGIN
	SET NOCOUNT OFF;
	-- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
	SELECT cname_receiveID, 
		   cname_receive, 
		   ccodealp_receive, 
		   region_receive
	FROM dbo.workingArea
	WHERE cname_receive LIKE '%' + @cname_receive + '%'
	GROUP BY cname_receiveID, 
			 cname_receive, 
			 ccodealp_receive, 
			 region_receive;
END;
GO
EXEC usp_cnameReceive_SELECTwithLIKE 'German';

-- cname_send

CREATE PROCEDURE usp_cnameSend_SELECT2
			  -- userStoredProcedure_column_action
				@cname_send1 NVARCHAR(55),
				@cname_send2 NVARCHAR(55)
AS
BEGIN
	SET NOCOUNT OFF;
	-- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
	SELECT cname_sendID, 
		   cname_send, 
		   ccodealp_send, 
		   region_send
	FROM dbo.workingArea
	WHERE cname_send IN (@cname_send1, @cname_send2)
	GROUP BY cname_sendID, 
			 cname_send, 
			 ccodealp_send, 
			 region_send;
END;
GO
EXEC usp_cnameSend_SELECT2 'Turkmenistan', 'Azerbaijan';

CREATE PROCEDURE usp_cnameSend_SELECTwithLIKE
			  -- userStoredProcedure_column_action
				 @cname_send NVARCHAR(55)
AS
BEGIN
	SET NOCOUNT OFF;
	-- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
	SELECT cname_sendID, 
		   cname_send, 
		   ccodealp_send, 
		   region_send
	FROM dbo.workingArea
	WHERE cname_send LIKE '%' + @cname_send + '%'
	GROUP BY cname_sendID, 
			 cname_send, 
			 ccodealp_send, 
			 region_send;
END;
GO
EXEC usp_cnameSend_SELECTwithLIKE 'German';
-- Fine procedure
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
--------------------------------------------------------------------------------------------------------------------------------------------