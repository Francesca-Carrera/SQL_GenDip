--------------------------------------------------------------------------------------------------------------------------------------------
-- Creazione del database GenDip
CREATE DATABASE GenDip
GO
USE GenDip

/* Importazione del file csv
	- Conversione del file di lavoro scaricato dal formato .xlsx a CSV.
	- Tasto destro su GenDip --> Attività --> Importa file flat --> nomino la tabella "stagingArea" --> Flaggare "Consenti valori NULL".
	- Le colonne "cname_send" e "cname_receive" le imposto a NVARCHAR(100), tutte le altre le imposto a NVARCHAR(10). */

/* Creazione tab workingArea con le colonne di mio interessa da tab stagingArea.
	- cname_sendID e cname_receiveID fungono da collegamento momentaneo, tra tab. countries (che non ho ancora creato)
	e tab. workingArea, per apportare modifiche ai paesi di invio e di destinazione. */
SELECT  
	IDENTITY(INT, 1,1) AS workingAreaID,
	year,
	gender,
	title, 
	NULL AS cname_sendID,
	cname_send,
	ccodealp_send,
	region_send,
	FFP_send,
	v2lgfemleg_send,
	NULL AS cname_receiveID,
	cname_receive,
	ccodealp_receive,
	region_receive,
	FFP_receive 
INTO dbo.workingArea
FROM dbo.stagingArea; -- 94.509 righe

-- Aggiunta del vincolo alla chiave primaria.
ALTER TABLE dbo.workingArea
  ADD CONSTRAINT pk_workingArea PRIMARY KEY (workingAreaID); -- PK_<TableName>