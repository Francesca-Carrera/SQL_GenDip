--------------------------------------------------------------------------------------------------------------------------------------------
-- Tab years: creazione e popolamento.

SELECT
	IDENTITY(INT, 1,1) AS yearID,
	year
INTO dbo.years
FROM dbo.workingArea
GROUP BY year
ORDER BY year ASC; -- 10 righe

-- Creazione vincolo di chiave primaria.
ALTER TABLE dbo.years 
	ADD CONSTRAINT PK_years PRIMARY KEY (yearID); 
				-- PK_TargetTable

-- Creazione vincolo UNIQUE.
ALTER TABLE dbo.years 
	ADD CONSTRAINT UQ_years_year UNIQUE (year); 
				-- UQ_TargetTable_TargetColumn

--------------------------------------------------------------------------------------------------------------------------------------------
-- Tab femaleLegislators: creazione e popolamento.

SELECT 
	IDENTITY(INT, 1,1) AS femaleLegislatorID,
	v2lgfemleg_send    AS femaleLegislatorPercentage
INTO dbo.femaleLegislators
FROM dbo.workingArea
GROUP BY v2lgfemleg_send
ORDER BY v2lgfemleg_send ASC; -- 778 righe

-- Creazione vincolo di chiave primaria.
ALTER TABLE dbo.femaleLegislators 
	ADD CONSTRAINT PK_femaleLegislators PRIMARY KEY (femaleLegislatorID); 
				-- PK_TargetTable

-- Creazione vincolo UNIQUE.
ALTER TABLE dbo.femaleLegislators 
	ADD CONSTRAINT UQ_femaleLegislators_femaleLegislatorPercentage UNIQUE (femaleLegislatorPercentage);
				-- UQ_TargetTable_TargetColumn

--------------------------------------------------------------------------------------------------------------------------------------------
-- Tab sendingCountries: creazione e popolamento.

SELECT
	IDENTITY(INT, 1,1) AS sendingCountryID,
	Y.yearID,
	W.cname_sendID AS countryID,
	F.femaleLegislatorID,
	W.FFP_send AS feministForeignPolicy
INTO dbo.sendingCountries
FROM dbo.years AS Y
	INNER JOIN dbo.workingArea AS W
		ON Y.year = W.year -- NO NULL
	LEFT JOIN dbo.femaleLegislators AS F
		ON EXISTS (SELECT W.v2lgfemleg_send
				   INTERSECT 
				   SELECT F.femaleLegislatorPercentage)
GROUP BY Y.yearID, 
		 W.cname_sendID, 
		 F.femaleLegislatorID, 
		 W.FFP_send
ORDER BY W.cname_sendID ASC, 
		 Y.yearID ASC; -- 1.822 righe

/* INTERSECT al posto di
ON (W.v2lgfemleg_send = F.femaleLegislatorPercentage OR 
		   (W.v2lgfemleg_send IS NULL AND F.femaleLegislatorPercentage IS NULL) */

-- Creazione vincolo di chiave primaria.
ALTER TABLE dbo.sendingCountries 
	ADD CONSTRAINT PK_sendingCountries PRIMARY KEY (sendingCountryID); 
				-- PK_TargetTable

-- Creazione vincoli di chiave esterna.
ALTER TABLE dbo.sendingCountries 
	ADD CONSTRAINT FK_sendingCountries_countries FOREIGN KEY (countryID) REFERENCES countries(countryID) 
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.sendingCountries 
	ADD CONSTRAINT FK_sendingCountries_years FOREIGN KEY (yearID) REFERENCES years(yearID) 
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.sendingCountries 
	ADD CONSTRAINT FK_sendingCountries_femaleLegislators FOREIGN KEY (femaleLegislatorID) REFERENCES femaleLegislators(femaleLegislatorID)
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

--------------------------------------------------------------------------------------------------------------------------------------------
-- Tab receivingCountries: creazione e popolamento.

SELECT
	IDENTITY(INT, 1,1) AS receivingCountryID,
	Y.yearID,
	W.cname_receiveID AS countryID,
	W.FFP_receive AS feministForeignPolicy
INTO dbo.receivingCountries
FROM dbo.years AS Y
	INNER JOIN dbo.workingArea AS W
		ON Y.year = W.year
GROUP BY Y.yearID, W.cname_receiveID, W.FFP_receive
ORDER BY W.cname_receiveID ASC, 
		 Y.yearID ASC; -- 1.857 righe

-- Creazione vincolo di chiave primaria.
ALTER TABLE dbo.receivingCountries 
	ADD CONSTRAINT PK_receivingCountries PRIMARY KEY (receivingCountryID); 
				-- PK_TargetTable

-- Creazione vincoli di chiave esterna.
ALTER TABLE dbo.receivingCountries 
	ADD CONSTRAINT FK_receivingCountries_countries FOREIGN KEY (countryID) REFERENCES countries(countryID)
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

ALTER TABLE dbo.receivingCountries 
	ADD CONSTRAINT FK_receivingCountries_years FOREIGN KEY (yearID) REFERENCES years(yearID)
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato

--------------------------------------------------------------------------------------------------------------------------------------------
-- Tab titles: creazione e popolamento.

CREATE TABLE dbo.titles (
    titleID INT IDENTITY(1,1),
	title NVARCHAR(50) NULL,
    CONSTRAINT PK_titles PRIMARY KEY (titleID), 
			-- PK_TargetTable
    CONSTRAINT UQ_titles_title UNIQUE (title) 
			-- UQ_TargetTable_TargetColumn
)
GO
INSERT INTO dbo.titles(title)
VALUES (NULL), ('Acting ambassador'), ('Acting chargé d’affaires'), 
	   ('Ambassador'), ('Chargé d’affaires'), ('Minister'), ('Other');

--------------------------------------------------------------------------------------------------------------------------------------------
-- Tab diplomats: creazione e popolamento.

SELECT
	IDENTITY(INT, 1,1) AS diplomatID,
	W.gender,
	T.titleID AS titleID
INTO dbo.diplomats
FROM dbo.workingArea AS W
	LEFT JOIN dbo.titles AS T
		ON (W.title = T.titleID 
			OR (W.title IS NULL AND T.titleID IS NULL)); -- 94.509 righe

-- Creazione vincolo di chiave primaria.
ALTER TABLE dbo.diplomats 
	ADD CONSTRAINT PK_diplomats PRIMARY KEY (diplomatID); 
				-- PK_TargetTable

-- Creazione vincoli di chiave esterna.
ALTER TABLE dbo.diplomats 
	ADD CONSTRAINT FK_diplomats_titles FOREIGN KEY (titleID) REFERENCES titles(titleID)
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato.

--------------------------------------------------------------------------------------------------------------------------------------------
-- Tab targetArea: creazione e popolamento.

/* La tabella targetArea rappresenta l'area di destinazione o l'obiettivo 
dei dati trasformati e preparati per l'elaborazione successiva.  
Contiene i dati elaborati e filtrati provenienti dalla tabella stagingArea, 
pronti per essere analizzati e impiegati per la rappresentazione dei grafici.
Ora i dati sono disponibili nella loro forma finale e il processo 
ETL può considerarsi concluso. */

SELECT 
	IDENTITY(INT, 1,1) AS targetareaID,
	Y.yearID,
	NULL AS diplomatID,
	S.sendingCountryID,
	R.receivingCountryID
INTO dbo.targetArea 
FROM dbo.workingArea AS W
	LEFT JOIN dbo.years AS Y
		ON W.year = Y.year
	LEFT JOIN dbo.femaleLegislators AS F
		ON W.v2lgfemleg_send = F.femaleLegislatorPercentage
		OR (W.v2lgfemleg_send IS NULL AND F.femaleLegislatorPercentage IS NULL)
	LEFT JOIN dbo.sendingCountries AS S
		ON EXISTS (SELECT Y.yearID, 
						  W.cname_sendID, 
						  F.femaleLegislatorID, 
						  W.FFP_send
				   INTERSECT
				   SELECT S.yearID, 
						  S.countryID, 
						  S.femaleLegislatorID, 
						  S.feministForeignPolicy)
	LEFT JOIN dbo.receivingCountries AS R
		ON EXISTS (SELECT Y.yearID,	
						  W.cname_receiveID, 
						  W.FFP_receive
				   INTERSECT
				   SELECT R.yearID, 
						  R.countryID, 
						  R.feministForeignPolicy); -- 94.509 righe

-- Collego la tabella diplomats direttamente a parte,
-- poiché non è collegata alla tabella targetArea tramite la tabella workingArea.
UPDATE T 
SET T.diplomatID = D.diplomatID 
FROM dbo.targetArea AS T
	INNER JOIN dbo.diplomats AS D
		ON T.targetareaID = D.diplomatID; -- 94.504 righe

-- Creazione vincolo di chiave primaria.
ALTER TABLE dbo.targetArea 
	ADD CONSTRAINT PK_targetArea PRIMARY KEY (targetAreaID); 
				-- PK_TargetTable

-- Creazione vincoli di chiave esterna.
ALTER TABLE dbo.targetArea 
	ADD CONSTRAINT FK_targetarea_years FOREIGN KEY (yearID) REFERENCES years(yearID)
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato.

ALTER TABLE dbo.targetArea 
	ADD CONSTRAINT FK_targetarea_diplomats FOREIGN KEY (diplomatID) REFERENCES diplomats(diplomatID)
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato.

ALTER TABLE dbo.targetArea 
	ADD CONSTRAINT FK_targetarea_sendingCountries FOREIGN KEY (sendingCountryID) REFERENCES sendingCountries(sendingCountryID)
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato.

ALTER TABLE dbo.targetArea 
	ADD CONSTRAINT FK_targetarea_receivingCountries FOREIGN KEY (receivingCountryID) REFERENCES receivingCountries(receivingCountryID)
				-- FK_TargetTable_SourceTable
	ON DELETE NO ACTION ON UPDATE NO ACTION; -- Implicito se non lo avessi dichiarato.
--------------------------------------------------------------------------------------------------------------------------------------------