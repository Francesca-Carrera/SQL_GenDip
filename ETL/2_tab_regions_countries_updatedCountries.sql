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
	  OR regionID IS NULL; -- 7 righe

/* Paesi con alpcode a NULL:
(1)15 id Azores, (2)118 id Korea, (3)121 id Kosovo, (4)212 id South Ossetia, (5)249 id Virgin Islands, (6)252 id Yemen. */

---------------------------------------
-- Stored Procedure per selezionare i dettagli dei due paesi corrispondenti ai parametri nella tab countries.
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

-- 1) Azores.

-- Azores fa parte del Portogallo.
EXEC usp_country_SELECT2 
	 'Azores', 
	 'Portugal';
-- DA: 15 id - Azores - NULL alpcode - 6 regionID
	--> A: 182 id - Portugal - PRT alpcode - 5 regionID.

-- Eliminazione del record con country Azores da tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 15;

-- Stored Procedure per selezionare i dettagli dei due paesi di destinazione corrispondenti ai parametri nella tab workingArea.
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
      FROM   dbo.workingArea
      WHERE  cname_receive IN ( @cname_receive1, @cname_receive2 )
      GROUP  BY cname_receiveID,
                cname_receive,
                ccodealp_receive,
                region_receive;
  END;
GO
EXEC usp_cnameReceive_SELECT2 
	 'Azores', 
	 'Portugal';

-- Aggiornamento del record contenente Azores nei paesi di destinazione.
UPDATE dbo.workingArea
SET cname_receiveID = 182, 
	cname_receive = 'Portugal', 
	ccodealp_receive = 'PRT', 
	region_receive = 5
WHERE cname_receiveID = 15; -- 1 riga.

-- Stored Procedure per selezionare i dettagli dei due paesi d'invio corrispondenti ai parametri nella tab workingArea.
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
EXEC usp_cnameSend_SELECT2 
	 'Azores', 
	 'Portugal';
-- Aggiornamento non necessario.

---------------------------------------

-- Stored Procedure per selezionare i dettagli del paese, corrispondente al parametro, nella tab countries tramite operatore LIKE.
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

-- 2) Korea.
EXEC usp_country_SELECTwithLIKE 
	 'Korea';
-- Korea ha l'alpcode a NULL perché non è meglio specificato se sia Nord o Sud.

---------------------------------------
-- 3) Kosovo.

EXEC usp_country_SELECTwithLIKE 
	 'Kosovo';
/* Vi sono 2 record con country Kosovo, uno con alpcode a NULL e l'altro con XKO.
Kosovo non ha un alpcode riconosciuto in maniera ufficiale, quindi il record con id 122 e alpcode XKO non è corretto.
DA: 122 id - Kosovo - XKO alpcode - 5 regionID 
	--> A: 121 id - Kosovo - NULL alpcode - 5 regionID. */

-- Eliminazione del record con country Kosovo e alpcode XKO da tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 122;

-- Stored Procedure per selezionare i dettagli del paese di destinazione, 
-- corrispondente al parametro, nella tab countries tramite operatore LIKE.
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
EXEC usp_cnameReceive_SELECTwithLIKE 
	 'Kosovo';

-- Aggiornamento del record contenente Kosovo con alpcode XKO nei paesi di destinazione.
UPDATE dbo.workingArea
SET cname_receiveID = 121, 
	ccodealp_receive = NULL
WHERE cname_receiveID = 122; -- 138 righe

-- Stored Procedure per selezionare i dettagli del paese d'invio, 
-- corrispondente al parametro, nella tab countries tramite operatore LIKE.
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
EXEC usp_cnameSend_SELECTwithLIKE 
	 'Kosovo';
-- Aggiornamento non necessario.

---------------------------------------
-- 4) South Ossetia.

-- South Ossetia fa ufficialmente parte della Georgia.
EXEC usp_country_SELECT2 
	 'South Ossetia', 
	 'Georgia';
-- DA: 212 id - South Ossetia - NULL alpcode - 4 regionID
	--> A: 83 id - Georgia - GEO alpcode - 4 regionID.

-- Eliminazione del record con South Ossetia da tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 212;

-- workingArea: controllo nei paesi di destinazione.
EXEC usp_cnameReceive_SELECT2 
	 'South Ossetia', 
	 'Georgia';

-- Aggiornamento del record contenente South Ossetia nei paesi di destinazione.
UPDATE dbo.workingArea
SET cname_receiveID = 83, 
	cname_receive = 'Georgia', 
	ccodealp_receive = 'GEO'
WHERE cname_receiveID = 212; -- 1 riga

-- workingArea: controllo nei paesi d'invio.
EXEC usp_cnameSend_SELECT2 
	 'South Ossetia', 
	 'Georgia';
-- Aggiornamento non necessario.

---------------------------------------
-- 5) Virgin Islands.

EXEC usp_country_SELECTwithLIKE 
	 'Virgin Islands';
-- Virgin Islands ha l'alpcode a NULL perché non è meglio specificato se sia British o Usa.
---------------------------------------
-- 6) Yemen.

EXEC usp_country_SELECTwithLIKE 
	 'Yemen';
/* Vi sono 5 record con country Yemen, uno di questi ha alpcode NULL.
DA: 252 id - NULL alpcode --> 
	A: 253 id - Yemen - YEM alpocode - 4 regionID.

255 id con alpcode scorretto.
DA: 255 id - YME 
	--> A: 254 id - YEM - Yemen, Arab Republic of.

256 id - YMD - Yemen, People's Democratic Republic of - record corretto. */

-- Eliminazione dei record errati con Yemen da tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 IN (252, 255);

-- workingArea: controllo nei paesi di destinazione.
EXEC usp_cnameReceive_SELECTwithLIKE 
	 'Yemen';
-- Aggiornamento non necessario.

-- workingArea: controllo nei paesi d'invio.
EXEC usp_cnameSend_SELECTwithLIKE 
	 'Yemen';

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

/* Nella CTE duplicateAlpcode seleziono i codici presenti più di una volta.
Nella SELECT unisco la tabella countries con la CTE duplicateAlpcode, 
visualizzando così i dettagli dei paesi con codici alpha duplicati. */
WITH duplicateAlpcode_CTE
	 AS (SELECT alpcode, 
				COUNT(alpcode) AS alpcodeCount
		 FROM dbo.countries
		 GROUP BY alpcode
		 HAVING COUNT(alpcode) > 1)
SELECT C.countryID2, C.country, DA.alpcode
FROM duplicateAlpcode_CTE AS DA
	 LEFT JOIN dbo.countries AS C
		ON DA.alpcode = C.alpcode;
---

-- 1) Correzione del codice alpha del Turkmenistan.

EXEC usp_country_SELECT2 
	 'Turkmenistan', 
	 'Azerbaijan';
-- DA: 232 id - Turkmenistan - AZE 
	--> A: 233 id - TKM.

-- Eliminazione del record errato in tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 232;

-- workingArea: controllo nei paesi di destinazione.
EXEC usp_cnameReceive_SELECT2 
	 'Turkmenistan', 
	 'Azerbaijan';

-- Aggiornamento del record nei paesi di destinazione.
UPDATE dbo.workingArea 
SET cname_receiveID = 233, 
	ccodealp_receive = 'TKM' 
WHERE cname_receiveID = 232; -- 1 riga

-- workingArea: controllo nei paesi d'origine.
EXEC usp_cnameSend_SELECT2 
	 'Turkmenistan', 
	 'Azerbaijan';
-- Aggiornamento non necessario.

---
-- 2) Correzione del codice alpha dell'Honduras.

EXEC usp_country_SELECT2 
	 'Belize', 
	 'Honduras';
-- DA: 100 id - Honduras - BLZ 
	--> A: 101 id - HND.

-- Eliminazione del record errato in tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 100;

-- workingArea: controllo nei paesi di destinazione.
EXEC usp_cnameReceive_SELECT2 
	 'Belize', 
	 'Honduras';

-- Aggiornamento del record nei paesi di destinazione.
UPDATE dbo.workingArea 
SET cname_receiveID = 101, 
	ccodealp_receive = 'HND' 
WHERE cname_receiveID = 100; -- 1 riga

-- workingArea: controllo nei paesi d'origine.
EXEC usp_cnameSend_SELECT2 
	 'Belize', 
	 'Honduras';
-- Aggiornamento non necessario.

---
-- 3) Correzione del codice alpha di Cyprus.

EXEC usp_cnameReceive_SELECT2 
	 'Cyprus', 
	 'Czechia';
-- DA: 58 id - Czechia - CYP 
	--> A: 59 id - CZE.

-- Eliminazione del record errato in tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 58;

-- workingArea: controllo nei paesi di destinazione.
EXEC usp_cnameReceive_SELECT2 
	 'Cyprus', 
	 'Czechia';

-- Aggiornamento del record nei paesi di destinazione.
UPDATE dbo.workingArea 
SET cname_receiveID = 59, 
	ccodealp_receive = 'CZE' 
WHERE cname_receiveID = 58; -- 1 riga

-- workingArea: controllo nei paesi d'origine.
EXEC usp_cnameSend_SELECT2 
	 'Cyprus', 
	 'Czechia';
-- Aggiornamento non necessario.

---
-- 4) Correzione del codice alpha di Cyprus.

SELECT countryID2, 
	   country, 
	   alpcode, 
	   regionID 
FROM dbo.countries
WHERE country = 'Niue' 
	  OR country LIKE '%Korea%'
-- DA: 166 id - Niue - PRK 
	--> A: 165 id - NIU.

-- Eliminazione del record errato in tab countries.
DELETE FROM dbo.countries 
WHERE countryID2 = 166;

-- workingArea: controllo nei paesi di destinazione.
SELECT cname_receiveID, 
	   cname_receive, 
	   ccodealp_receive, 
	   region_receive
FROM dbo.workingArea
WHERE cname_receive = 'Niue' 
	  OR cname_receive LIKE '%Korea%'
GROUP BY cname_receiveID, 
		 cname_receive, 
		 ccodealp_receive, 
		 region_receive;

-- Aggiornamento del record nei paesi di destinazione.
UPDATE dbo.workingArea 
SET cname_receiveID = 165, 
	ccodealp_receive = 'NIU' 
WHERE cname_receiveID = 166; -- 12 righe

-- workingArea: controllo nei paesi d'origine.
SELECT cname_sendID, 
	   cname_send, 
	   ccodealp_send, 
	   region_send
FROM dbo.workingArea
WHERE cname_send = 'Niue' 
	  OR cname_send LIKE '%Korea%'
GROUP BY cname_sendID, 
		 cname_send, 
		 ccodealp_send, 
		 region_send;
-- Aggiornamento non necessario.
--------------------------------------------------------------------------------------------------------------------------------------------
-- Creazione e popolamento di tab updatedCountries per paragonarla a tab countries.

/* Ho scaricato da Wikipedia un file con dati aggiornati sui paesi attuali con 
nome completo, codici alpha a tre caratteri e regione geografica.

Per snellire il processo ho verificato i dati sul file Excel,
apportando le modifiche dove necessario, in modo da rendere i nomi dei paesi
grammaticalmente identici a quelli presenti nella tabella countries.

Importazione del file CVS updatedCountry.
	- Tasto destro su GenDip -> Attività --> Importa file flat 
		--> nomino la tabella "updatedCountries" --> Flaggare "Consenti valori NULL".
	-- Ho impostato manualmente column1 come VARCHAR(10) e l'ho rinominato 'updatedAlpcode'.
	-- Ho impostato manualmente column2 come NVARCHAR(55) e l'ho rinominato 'updatedCountry'. 
	-- Ho impostato manualmente column3 come INT e l'ho rinominato 'updatedRegionID'.*/

SELECT updatedAlpcode, 
	   updatedCountry,
	   updatedRegionID
FROM dbo.updatedCountries; -- 249 righe

-- Aggiungo la colonna updatedCountryID  e la definisco come chiave primaria della tabella.
ALTER TABLE dbo.updatedCountries 
	ADD updatedCountryID INT IDENTITY(1,1);

ALTER TABLE dbo.updatedCountries 
	ADD CONSTRAINT PK_updatedCountries PRIMARY KEY (updatedCountryID); 
				-- PK_TargetTable

-- Verifica della presenza di valori NULL.
SELECT updatedCountryID, 
	   updatedAlpcode, 
	   updatedCountry, 
	   updatedRegionID 
FROM dbo.updatedCountries
WHERE updatedAlpcode IS NULL
	  OR updatedCountry IS NULL
	  OR updatedRegionID IS NULL;

-- Aggiunta alle colonne del vincolo NOT NULL.
ALTER TABLE dbo.updatedCountries 
	ALTER COLUMN updatedAlpcode VARCHAR(10) NOT NULL;

ALTER TABLE dbo.updatedCountries 
	ALTER COLUMN updatedCountry NVARCHAR(55) NOT NULL;

ALTER TABLE dbo.updatedCountries 
	ALTER COLUMN updatedRegionID INT NOT NULL;

-- Aggiunta del vincolo di unicità composto dalla combinazione di due colonne.
ALTER TABLE dbo.updatedCountries 
	ADD CONSTRAINT UQ_updatedCountries_alpcode_country UNIQUE (updatedAlpcode, updatedCountry); 
				-- UQ_TargetTable_TargetColumn1_TargetColumn2
--------------------------------------------------------------------------------------------------------------------------------------------
-- Regioni geografiche non combacianti tra tab countries e updatedCountries.

/* Nella CTE unupdatedCountries seleziono, tramite EXCEPT, i paesi 
presenti nella tab countries, ma non in updatedCountries. 

Nella SELECT visualizzo i dati ottenuti dalla CTE accompagnandoli, inoltre, 
alla regione geografica aggiornata, presente nella tab updatedCountries. */

WITH unupdatedCountries_CTE 
	 AS (SELECT country, 
				alpcode, 
				regionID
		 FROM dbo.countries
		 EXCEPT
		 SELECT updatedCountry, 
				updatedAlpcode, 
				updatedRegionID 
		 FROM dbo.updatedCountries)
SELECT C.countryID2, 
	   C.alpcode, 
	   C.country, 
	   C.regionID		  AS 'wrong regionID',
	   UC.updatedRegionID AS 'correct regionID'
FROM dbo.countries AS C
	 INNER JOIN unupdatedCountries_CTE AS CTE
			ON C.country = CTE.country 
	 LEFT JOIN dbo.updatedCountries AS UC
			ON C.country = UC.updatedCountry
WHERE UC.updatedRegionID IS NOT NULL
ORDER BY C.alpcode; -- 7 righe

/* regionID errato nella tab countries, corretto in updatedCountries:
- 80 id - ATF - French Southern Territories - 
	DA 2 regionID --> A: 3 regionID (Antarctic).
- 56 id - CUW - Curaçao - 
	DA: 8 regionID --> A: 6 regionID (North America) (NB. come Aruba e Bonaire (le Antille Olandesi)).
- 66 id - EGY - Egypt - 
	DA: 4 regionID: A: 2 regionID (Africa).
- 97 id - GUY - Guyana - 
	DA: 2 regionID --> A: 8 (South America).
- 169 id - MNP - Northern Mariana Islands - 
	DA: 4 regionID --> A: 7 (Oceania).
- 180 id - PCN - Pitcairn - 
	DA: 4 regionID --> A: 7 (Oceania).
- 228 id - TON - Tonga - 
	DA: 2 regionID --> A: 7 (Oceania). */


-- Correzione di regionID non combacianti tra tab countries e updatedCountries tramite Stored Procedure.
CREATE PROCEDURE usp_regionID_UPDATE
				 @new_regionID INT,
				 @current_countryID INT
AS
	BEGIN
		SET NOCOUNT OFF;
		-- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
		UPDATE dbo.countries 
		SET regionID = @new_regionID 
		WHERE countryID2 = @current_countryID;
	END;
GO
EXEC usp_regionID_UPDATE 
	 @new_regionID = 3, 
	 @current_countryID = 80;

EXEC usp_regionID_UPDATE 
	 @new_regionID = 6, 
	 @current_countryID = 56;

EXEC usp_regionID_UPDATE 
	 @new_regionID = 2, 
	 @current_countryID = 66;

EXEC usp_regionID_UPDATE 
	 @new_regionID = 8, 
	 @current_countryID = 97;

EXEC usp_regionID_UPDATE 
	 @new_regionID = 7, 
	 @current_countryID = 169;

EXEC usp_regionID_UPDATE 
	 @new_regionID = 7, 
	 @current_countryID = 180;

EXEC usp_regionID_UPDATE 
	 @new_regionID = 7, 
	 @current_countryID = 228;

DROP PROCEDURE usp_regionID_UPDATE;


-- Correzione in tab workingArea dei valori geografici errati per i paesi d'invio e di destinazione.

-- Paesi d'invio.
SELECT cname_sendID, 
	   ccodealp_send, 
	   cname_send, 
	   region_send
FROM dbo.workingArea
WHERE cname_sendID IN (80, 56, 66, 97, 
					   169, 180, 228)
GROUP BY cname_sendID, 
		 ccodealp_send, 
		 cname_send, 
		 region_send
ORDER BY ccodealp_send;

UPDATE dbo.workingArea 
SET region_send = 2 
WHERE cname_sendID = 66; 
		   -- 1183 righe

UPDATE dbo.workingArea 
SET region_send = 8 
WHERE cname_sendID = 97; 
			-- 136 righe

UPDATE dbo.workingArea 
SET region_send = 7 
WHERE cname_sendID = 228; 
			  -- 33 righe

-- Paesi di destinazione.
SELECT cname_receiveID, 
	   ccodealp_receive, 
	   cname_receive, 
	   region_receive
FROM dbo.workingArea
WHERE cname_receiveID IN (80, 56, 66, 97, 
						  169, 180, 228)
GROUP BY cname_receiveID, 
		 ccodealp_receive, 
		 cname_receive, 
		 region_receive
ORDER BY ccodealp_receive;

CREATE PROCEDURE usp_regionReceive_UPDATE
				 @new_regionReceive INT,
				 @current_cnameReceiveID INT
AS
	BEGIN
		SET NOCOUNT OFF;
		-- implicito ma lo scrivo: desidero vedere il conteggio delle righe.
		UPDATE dbo.workingArea 
		SET region_receive = @new_regionReceive 
		WHERE cname_receiveID = @current_cnameReceiveID;
	END;
GO
EXEC usp_regionReceive_UPDATE 
	 @new_regionReceive = 3, 
	 @current_cnameReceiveID = 80; -- 1 riga

EXEC usp_regionReceive_UPDATE 
	 @new_regionReceive = 6, 
	 @current_cnameReceiveID = 56; -- 5 righe

EXEC usp_regionReceive_UPDATE 
	 @new_regionReceive = 2, 
	 @current_cnameReceiveID = 66; -- 1.088 righe

EXEC usp_regionReceive_UPDATE 
	 @new_regionReceive = 8, 
	 @current_cnameReceiveID = 97; -- 234 righe

EXEC usp_regionReceive_UPDATE 
	 @new_regionReceive = 7, 
	 @current_cnameReceiveID = 169; -- 2 righe

EXEC usp_regionReceive_UPDATE 
	 @new_regionReceive = 7, 
	 @current_cnameReceiveID = 180; -- 2 righe

EXEC usp_regionReceive_UPDATE 
	 @new_regionReceive = 7, 
	 @current_cnameReceiveID = 228; -- 122 righe

DROP PROCEDURE usp_regionReceive_UPDATE;


-- Paesi non più esistenti.
SELECT country AS 'unupdatedCountry',
	   alpcode, 
	   regionID
FROM dbo.countries
WHERE country IS NOT NULL
	  AND alpcode IS NOT NULL
EXCEPT
SELECT updatedCountry, 
	   updatedAlpcode, 
	   updatedRegionID
FROM dbo.updatedCountries; -- 16 paesi

/* 1) Paesi con alpcode a NULL:
115 id Korea - 118 id Kosovo - 239 id Virgin Islands 
	--> per imprecisazione geografica o alpcode non ufficialmente riconosciuto.

2) Paesi non più esistenti:
- 41 id CAF Central African Empire CAF --> dal 1976 al 1979 - OGGI: Central African Republic
- 58 id CSK Czechoslovakia CSK --> dal 1918 al 1992 - OGGI: Czechia, Slovakia.
- 82 id DDR German Democratic Republic --> dal 1968 al 1990 - OGGI: Germany.
- 84 id DEU Germany, Federal Republic of --> dal 1968 al 1990 - OGGI: Germany.
- 111 id KHM Kampuchea --> dal 1976 al 1979 - OGGI: Cambodia.
- 194 id SCG Serbia and Montenegro --> dal 2003 al 2006 - OGGI: Serbia, Montenegro.
- 232 id SUN USSR --> dal 1922 al 1991 - OGGI: Russian Federation.
- 237 id VDR Viet Nam, Democratic Republic of --> dal 1955 al 1975 (North Viet Nam) - OGGI: Viet Nam.
- 238 VNM Viet Nam, Republic of --> dal 1955 al 1975 (South Viet Nam) - OGGI: Viet Nam.
- 243 id YEM Yemen, Arab Republic of --> dal 1962 al 1990 - OGGI: Yemen.
- 244 id YMD Yemen, People's Democratic Republic of --> dal 1967 al 1990 - OGGI: Yemen.
- 245 id YUG - Yugoslavia YUG - dal 1918 al 1991/1992. 
	- OGGI: Serbia, Croazia, Macedonia, Montenegro, Slovenia, Bosnia-Erzegovina 
	e le due province autonome serbe del Kossovo e della Vojvodina. */
--------------------------------------------------------------------------------------------------------------------------------------------
/* Tab countries: eliminazione countryID (simil PK) e countryID2 (vice PK),
				  creazione colonna PK definitiva,
				  creazione vincolo UNIQUE,
				  creazione regionID come FK,
				  creazione updatedCountryID come FK*/

-- Eliminazione potenziale PK e vice PK. 
-- Creazione nuovo vincolo di chiave primaria.
ALTER TABLE dbo.countries 
	DROP COLUMN countryID; 

ALTER TABLE dbo.countries 
	DROP COLUMN countryID2;

ALTER TABLE dbo.countries 
	ADD countryID INT IDENTITY(1,1);

ALTER TABLE dbo.countries 
	ADD CONSTRAINT PK_countries PRIMARY KEY (countryID); 
				-- PK_TargetTable

-- Aggiunta del vincolo di unicità composto dalla combinazione di due colonne.
ALTER TABLE dbo.countries 
	ADD CONSTRAINT UQ_countries_country_alpcode UNIQUE (country, alpcode); 
				-- UQ_TargetTable_TargetColumn1_TargetColumn2

ALTER TABLE dbo.countries
	ADD CONSTRAINT FK_countries_regions FOREIGN KEY (regionID) REFERENCES regions(regionID) 
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.countries
	ADD CONSTRAINT FK_countries_updatedCountries FOREIGN KEY (updatedCountryID) REFERENCES updatedCountries(updatedCountryID) 
				-- FK_TargetTable_SourceTable-
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato


/* Tab workingArea: aggiornamento potenziali colonne FK,
					creazione vincoli FK definitivi. */

EXEC usp_cnameSendID_UPDATE; -- 94.509 righe

DROP PROCEDURE usp_cnameSendID_UPDATE;

ALTER TABLE dbo.workingArea
	ADD CONSTRAINT FK_workingArea_sending_countries FOREIGN KEY (cname_sendID) REFERENCES countries(countryID)
				-- FK_TargetTable_sending_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato


EXECUTE usp_cnameReceiveID_UPDATE; -- 94.509 righe

DROP PROCEDURE usp_cnameReceiveID_UPDATE;

ALTER TABLE dbo.workingArea
	ADD CONSTRAINT FK_workingArea_receiving_countries FOREIGN KEY (cname_receiveID) REFERENCES countries(countryID)
				-- FK_TargetTable_receiving_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato
--------------------------------------------------------------------------------------------------------------------------------------------