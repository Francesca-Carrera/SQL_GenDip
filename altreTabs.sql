-------------------------------------------------------------------------------------------------------------------------
-- Tab years: creazione e popolamento.

SELECT
	IDENTITY(INT, 1,1) AS yearID,
	year
INTO dbo.years
FROM dbo.workingArea
GROUP BY year
ORDER BY year ASC; -- NO NULL, 10 righe

ALTER TABLE dbo.years ADD CONSTRAINT PK_years PRIMARY KEY (yearID); -- PK_TargetTable
ALTER TABLE dbo.years ADD CONSTRAINT UQ_years_year UNIQUE (year); -- UQ_TargetTable_TargetColumn

SELECT * FROM dbo.years; -- NO NULL
----------------------------------------------------------------------------
-- Tab femaleLegislators: creazione e popolamento.

SELECT 
	IDENTITY(INT, 1,1) AS femaleLegislatorID,
	v2lgfemleg_send AS femaleLegislatorPercentage
INTO dbo.femaleLegislators
FROM dbo.workingArea
GROUP BY v2lgfemleg_send
ORDER BY v2lgfemleg_send ASC; -- 778 righe

ALTER TABLE dbo.femaleLegislators ADD CONSTRAINT PK_femaleLegislators PRIMARY KEY (femaleLegislatorID); -- PK_TargetTable

ALTER TABLE dbo.femaleLegislators ADD CONSTRAINT UQ_femaleLegislators_femaleLegislatorPercentage 
	UNIQUE (femaleLegislatorPercentage); -- UQ_TargetTable_TargetColumn

SELECT * FROM femaleLegislators;
----------------------------------------------------------------------------
-- Tab sendingCountries: creazione e popolamento.

SELECT
	IDENTITY(INT, 1,1) AS sendingCountryID,
	Y.yearID,
	W.cname_sendID AS countryID,
	F.femaleLegislatorID,
	W.FFP_send AS feministForeignPolicy -- no valori NULL
INTO dbo.sendingCountries
FROM dbo.years AS Y
INNER JOIN dbo.workingArea AS W
	ON Y.year = W.year -- NO NULL
LEFT JOIN dbo.femaleLegislators AS F
	ON (W.v2lgfemleg_send = F.femaleLegislatorPercentage OR 
		(W.v2lgfemleg_send IS NULL AND F.femaleLegislatorPercentage IS NULL)) -- ( prima: 94.509)
GROUP BY Y.yearID, W.cname_sendID, F.femaleLegislatorID, W.FFP_send
ORDER BY W.cname_sendID ASC, Y.yearID ASC; -- 1.822 righe

-- Controllo che il numero di righe combacino: 1.822
SELECT year, cname_sendID, v2lgfemleg_send, FFP_send FROM dbo.workingArea GROUP BY year, cname_sendID, v2lgfemleg_send, FFP_send;
SELECT year, cname_send, v2lgfemleg_send, FFP_send FROM dbo.workingArea GROUP BY year, cname_send, v2lgfemleg_send, FFP_send;

ALTER TABLE dbo.sendingCountries ADD CONSTRAINT PK_sendingCountries PRIMARY KEY (sendingCountryID); -- PK_TargetTable

ALTER TABLE dbo.sendingCountries ADD CONSTRAINT FK_sendingCountries_countries -- FK_TargetTable_SourceTable
FOREIGN KEY (countryID) REFERENCES countries(countryID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.sendingCountries ADD CONSTRAINT FK_sendingCountries_years -- FK_TargetTable_SourceTable
FOREIGN KEY (yearID) REFERENCES years(yearID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.sendingCountries ADD CONSTRAINT FK_sendingCountries_femaleLegislators -- FK_TargetTable_SourceTable
FOREIGN KEY (femaleLegislatorID) REFERENCES femaleLegislators(femaleLegislatorID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

SELECT * FROM dbo.sendingCountries; -- 1.822 righe
--------------------------------------------------------------------------------------------------------------------
-- Tab receivingCountries: creazione e popolamento.

SELECT
	IDENTITY(INT, 1,1) as receivingCountryID,
	Y.yearID,
	W.cname_receiveID AS countryID,
	W.FFP_receive AS feministForeignPolicy -- un valore NULL id 1
INTO dbo.receivingCountries
FROM dbo.years AS Y
INNER JOIN dbo.workingArea AS W
	ON Y.year = W.year -- NO NULL  (prima: 94.509)
GROUP BY Y.yearID, W.cname_receiveID, W.FFP_receive
ORDER BY W.cname_receiveID ASC, Y.yearID ASC; -- 1.857 righe

ALTER TABLE dbo.receivingCountries ADD CONSTRAINT PK_receivingCountries PRIMARY KEY (receivingCountryID); -- PK_TargetTable

ALTER TABLE dbo.receivingCountries ADD CONSTRAINT FK_receivingCountries_countries -- FK_TargetTable_SourceTable
FOREIGN KEY (countryID) REFERENCES countries(countryID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.receivingCountries ADD CONSTRAINT FK_receivingCountries_years -- FK_TargetTable_SourceTable
FOREIGN KEY (yearID) REFERENCES years(yearID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

SELECT * FROM dbo.receivingCountries; -- 1.857 righe
-------------------------------------------------------------------------------------------------------------------------
-- Da non mostrare, controllo mio:
-- Tab workingArea: verifica dei valori positivi nelle colonne FFP_send e FFP_receive.

SELECT year, cname_send, FFP_send
FROM dbo.workingArea
WHERE FFP_send = '1'
GROUP BY year, cname_send, FFP_send
ORDER BY year ASC, cname_send ASC;

/* 1 FFP_send / FeministForeignPolicy_S:
2014: Sweden
2019: Canada, France, Mexico, Sweden
2021: Canada, France, Libya, Luxembourg, Mexico, Spain, Sweden. */

SELECT year, cname_receive, FFP_receive
FROM dbo.workingArea
WHERE FFP_receive = '1'
GROUP BY year, cname_receive, FFP_receive
ORDER BY year ASC, cname_receive ASC;

/* 1 FFP_receive / FeministForeignPolicy_S:
2014: Sweden
2019: Canada, France, Mexico, Sweden
2021: Canada, France, Libya, Luxembourg, Mexico, Spain, Sweden. */
--------------------------------------------------------------------------------------------------------------------
-- Tab titles: creazione e popolamento.

CREATE TABLE dbo.titles (
    titleID INT IDENTITY(1,1),
	title NVARCHAR(50) NULL,
    CONSTRAINT PK_titles PRIMARY KEY (titleID), -- PK_TargetTable
    CONSTRAINT UQ_titles_title UNIQUE (title) -- UQ_TargetTable_TargetColumn
)
GO

INSERT INTO dbo.titles(title)
VALUES (NULL), ('Acting ambassador'), ('Acting chargé d’affaires'), 
	   ('Ambassador'), ('Chargé d’affaires'), ('Minister'), ('Other');

SELECT * FROM dbo.titles;
--------------------------------------------------------------------------------------------------------------------
-- Tab diplomats: creazione e popolamento.

SELECT
	IDENTITY(INT, 1,1) AS diplomatID,
	W.gender, -- è presente NULL
	W.title As titleID
INTO dbo.diplomats
FROM dbo.workingArea AS W
LEFT JOIN dbo.titles AS T
	ON (W.title = T.titleID 
		OR (W.title IS NULL AND T.titleID IS NULL)); -- 94.509 righe

ALTER TABLE dbo.diplomats ADD CONSTRAINT PK_diplomats PRIMARY KEY (diplomatID); -- PK_TargetTable

ALTER TABLE dbo.diplomats ADD CONSTRAINT FK_diplomats_titles -- FK_TargetTable_SourceTable
FOREIGN KEY (titleID) REFERENCES titles(titleID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato -- ERRORE:
-- L'istruzione ALTER TABLE è in conflitto con il vincolo FOREIGN KEY "FK_diplomats_titles". Il conflitto si è verificato nella tabella "dbo.titles", column 'titleID' del database "GenDip2".

SELECT * FROM dbo.diplomats; -- 94.509 righe
--------------------------------------------------------------------------------------------------------------------
-- Tab targetArea: creazione e popolamento.

SELECT 
	IDENTITY(INT, 1,1) AS targetareaID,
	Y.yearID,
	NULL AS diplomatID,
	S.sendingCountryID,
	R.receivingCountryID
INTO dbo.targetArea 
FROM dbo.workingArea AS W
LEFT JOIN dbo.years AS Y
	ON W.year = Y.year -- NO NULL
LEFT JOIN dbo.femaleLegislators AS F
	ON W.v2lgfemleg_send = F.femaleLegislatorPercentage
	OR (W.v2lgfemleg_send IS NULL AND F.femaleLegislatorPercentage IS NULL)
LEFT JOIN dbo.sendingCountries AS S
	ON EXISTS (SELECT Y.yearID, W.cname_sendID, F.femaleLegislatorID, W.FFP_send
					INTERSECT
			   SELECT S.yearID, S.countryID, S.femaleLegislatorID, S.feministForeignPolicy) -- NO NULL
LEFT JOIN dbo.receivingCountries AS R
	ON EXISTS (SELECT Y.yearID, W.cname_receiveID, W.FFP_receive
					INTERSECT
			   SELECT R.yearID, R.countryID, R.feministForeignPolicy); -- 94.509 righe

/* Vecchio metodo:
SELECT 
	IDENTITY(INT, 1,1) AS targetareaID,
	Y.yearID,
	NULL AS diplomatID,
	S.sendingCountryID,
	R.receivingCountryID
INTO dbo.targetArea 
FROM dbo.workingArea AS W
LEFT JOIN dbo.years AS Y
	ON W.year = Y.year -- NO NULL
LEFT JOIN dbo.femaleLegislators AS F
	ON W.v2lgfemleg_send = F.femaleLegislatorPercentage
	OR (W.v2lgfemleg_send IS NULL AND F.femaleLegislatorPercentage IS NULL)
LEFT JOIN dbo.sendingCountries AS S
	ON Y.yearID = S.yearID
	AND W.cname_sendID = S.countryID
	AND F.femaleLegislatorID = S.femaleLegislatorID
	AND W.FFP_send = S.feministForeignPolicy -- NO NULL
LEFT JOIN dbo.receivingCountries AS R
	ON Y.yearID = R.yearID
	AND W.cname_receiveID = R.countryID
	AND (W.FFP_receive = R.feministForeignPolicy 
	OR (W.FFP_receive IS NULL AND R.feministForeignPolicy IS NULL)); -- 94509

Se non metto le parentesi continua a caricare.
AND W.FFP_receive = R.feministForeignPolicy 
	OR (W.FFP_receive IS NULL AND R.feministForeignPolicy IS NULL); 
-> ERRORE */

-- Farlo a parte perché la tab diplomats non si collega a targetArea tramite workingArea
UPDATE T SET T.diplomatID = D.diplomatID FROM dbo.targetArea AS T
INNER JOIN dbo.diplomats AS D
ON T.targetareaID = D.diplomatID; -- 94.504 righe

ALTER TABLE dbo.targetArea ADD CONSTRAINT PK_targetArea PRIMARY KEY (targetAreaID); -- PK_TargetTable

ALTER TABLE dbo.targetArea ADD CONSTRAINT FK_targetarea_years -- FK_TargetTable_SourceTable
FOREIGN KEY (yearID) REFERENCES years(yearID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.targetArea ADD CONSTRAINT FK_targetarea_diplomats -- FK_TargetTable_SourceTable
FOREIGN KEY (diplomatID) REFERENCES diplomats(diplomatID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.targetArea ADD CONSTRAINT FK_targetarea_sendingCountries -- FK_TargetTable_SourceTable
FOREIGN KEY (sendingCountryID) REFERENCES sendingCountries(sendingCountryID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.targetArea ADD CONSTRAINT FK_targetarea_receivingCountries -- FK_TargetTable_SourceTable
FOREIGN KEY (receivingCountryID) REFERENCES receivingCountries(receivingCountryID)
ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato
---------------------------------------------------------------------------------------------------------------------