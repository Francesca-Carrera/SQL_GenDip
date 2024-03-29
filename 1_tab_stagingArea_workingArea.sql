--------------------------------------------------------------------------------------------------------------------------------------------
-- Creazione del database GenDip
CREATE DATABASE GenDip
GO
USE GenDip

/* Importazione del file csv.
	- Conversione del file di lavoro scaricato dal formato .xlsx a CSV.
	- Tasto destro su GenDip --> Attività --> Importa file flat --> nomino la tabella "stagingArea" --> Flaggare "Consenti valori NULL".
	- Le colonne "cname_send" e "cname_receive" le imposto a NVARCHAR(100), tutte le altre le imposto a NVARCHAR(10). */

/* Creazione tab. workingArea con le colonne di mio interessa da tab. stagingArea.
	- cname_sendID e cname_receiveID fungono da collegamento momentaneo tra tab. countries (che non ho ancora creato).
	  e tab. workingArea, per apportare modifiche ai paesi di invio e di destinazione. */
SELECT IDENTITY(int, 1, 1) AS workingAreaID,
       year,
       gender,
       title,
       NULL                AS cname_sendID,
       cname_send,
       ccodealp_send,
       region_send,
       FFP_send,
       v2lgfemleg_send,
       NULL                AS cname_receiveID,
       cname_receive,
       ccodealp_receive,
       region_receive,
       FFP_receive
INTO   dbo.workingArea
FROM   dbo.stagingArea; -- 94.509 righe

-- Aggiunta del vincolo alla chiave primaria.
ALTER TABLE dbo.workingArea
  ADD CONSTRAINT pk_workingArea PRIMARY KEY (workingAreaID); -- PK_<TableName>
--------------------------------------------------------------------------------------------------------------------------------------------
-- Normalizzazione dei dati: verifica della presenza di caratteri non standard, sistemazione dei NULL e dei tipi di dato delle colonne.

-- 1) Personalizzazione della colonna "year".

-- Verifica generale dei dati presenti nella colonna.
SELECT year 
FROM dbo.workingArea 
GROUP BY year 
ORDER BY year; 
-- OUTPUT: No NULL.

/* Ricerca tramite la funzione PATINDEX() di caratteri non standard, inclusi spazi non standard, 
nello specifico né numeri, né lettere maiuscole, né lettere minuscole. */
SELECT year 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', year) > 0 
GROUP BY year;

-- Rimozione tramite la funzione TRIM di eventuali spazi vuoti (codice ASCII 32) all'inizio e alla fine della stringa.
UPDATE dbo.workingArea 
SET year = TRIM(year); -- 94.509 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN year INT;


--2) Personalizzazione della colonna "gender".

-- Verifica generale dei dati presenti nella colonna.
SELECT gender 
FROM dbo.workingArea 
GROUP BY gender 
ORDER BY gender; 
-- OUTPUT: '99' per NULL.

-- Verifica della presenza di caratteri non standard.
SELECT gender 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', gender) > 0 
GROUP BY gender;

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET gender = TRIM(gender); -- 94.509 righe

-- Sostituzione del valore '99' con NULL.
UPDATE dbo.workingArea 
SET gender = NULL 
WHERE gender = '99'; -- 5.409 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN gender BIT;


--3) Personalizzazione della colonna "title".

-- Verifica generale dei dati presenti nella colonna.
SELECT title 
FROM dbo.workingArea 
GROUP BY title 
ORDER BY title; 
-- OUTPUT: '0' e '99' per NULL.

-- Verifica della presenza di caratteri non standard.
SELECT title 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', title) > 0 
GROUP BY title;

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET title = TRIM(title); -- 94.509 righe

/* Da Codebook:
1 chargé d’affaires, 2 minister, 3 ambassador, 96 acting chargé d’affaires, 97 acting ambassador, 98 other, 99 missing 

Mia rivisitazione:
1 NULL, 2 Acting ambassador, 3 Acting chargé d’affaires, 4 Ambassador, 5 Chargé d’affaires, 6 Minister, 7 Other */
UPDATE dbo.workingArea
SET    title = CASE title
                 WHEN '1' THEN '5' -- 'Chargé d’affaires'
                 WHEN '2' THEN '6' -- 'Minister'
                 WHEN '3' THEN '4' -- 'Ambassador'
                 WHEN '96' THEN '3' -- 'Acting chargé d’affaires'
                 WHEN '97' THEN '2' -- 'Acting ambassador'
                 WHEN '98' THEN '7' -- 'Other'
                 WHEN '99' THEN '1' -- NULL
               END
WHERE  title IN ( '1', '2', '3', '96',
                  '97', '98', '99' ); -- 94.504 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN title INT; 


-- 4) Personalizzazione della colonna "cname_send".

-- Verifica generale dei dati presenti nella colonna.
SELECT cname_send 
FROM dbo.workingArea 
GROUP BY cname_send 
ORDER BY cname_send; 
-- OUTPUT: No NULL.

-- Verifica della presenza di caratteri non standard.
SELECT cname_send 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', cname_send) > 0 
GROUP BY cname_send;
-- Nel contesto specifico dei paesi, i caratteri non standard sono considerati standard, quali virgole, apostrofi, trattini e accenti.

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET cname_send = TRIM(cname_send); -- 94.509 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN cname_send NVARCHAR(55);


--5) Personalizzazione della colonna "ccodealp_send".

-- Verifica generale dei dati presenti nella colonna.
SELECT ccodealp_send 
FROM dbo.workingArea 
GROUP BY ccodealp_send 
ORDER BY ccodealp_send; 
-- OUTPUT: '9999' per NULL.

-- Verifica della presenza di caratteri non standard.
SELECT ccodealp_send 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', ccodealp_send) > 0 
GROUP BY ccodealp_send;

-- Identificazione del carattere non standard.
SELECT RIGHT(ccodealp_send, 1)		  AS LastChar, 
	   ASCII(RIGHT(ccodealp_send, 1)) AS LastCharAsciiCode 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', ccodealp_send) > 0
GROUP BY RIGHT(ccodealp_send, 1), 
		 ASCII(RIGHT(ccodealp_send, 1));
/* OUTPUT: LastChar: ' ' - LastCharAsciiCode: 160 (no-break space).
LastChar: restituisce l'ultimo carattere della colonna ccodealp_send.
LastCharAsciiCode: restituisce il codice ASCII dell'ultimo carattere della colonna ccodealp_send. */

-- Eliminazione del carattere non standard.
UPDATE dbo.workingArea 
SET ccodealp_send = REPLACE(ccodealp_send, CHAR(160),''); -- 94.509 righe

-- Sostituzione del valore '9999' con NULL.
UPDATE dbo.workingArea 
SET ccodealp_send = NULL WHERE ccodealp_send = '9999'; -- 124 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN ccodealp_send VARCHAR(10);


--6) Personalizzazione della colonna "region_send".

-- Verifica generale dei dati presenti nella colonna.
SELECT region_send 
FROM dbo.workingArea 
GROUP BY region_send 
ORDER BY region_send; 
-- OUTPUT: No NULL

-- Verifica della presenza di caratteri non standard.
SELECT region_send 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', region_send) > 0 
GROUP BY region_send;

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET region_send = TRIM(region_send); -- 94.509 righe

/* Da CodeBooK: 
0 Africa, 1 Asia, 2 Central and North America, 3 Europe, 4 Middle East, 5 Nordic countries, 6 Oceania, 7 South America, 9999 Missing 

Ho scelto di seguire il modello a sette continenti: 
1 NULL, 2 Africa, 3 Antarctica, 4 Asia, 5 Europe, 6 North America, 7 Oceania, 8 South America */
UPDATE dbo.workingArea
SET    region_send = CASE region_send
                       WHEN '0' THEN '2' -- Africa
                       WHEN '1' THEN '4' -- Asia
                       WHEN '2' THEN '6' -- DA: Central and North America A: North America
                       WHEN '3' THEN '5' -- Europe
                       WHEN '4' THEN '4' -- DA: Middle East AD: Asia
                       WHEN '5' THEN '5' -- DA: Nordic countries AD: Europe
                       WHEN '6' THEN '7' -- Oceania
                       WHEN '7' THEN '8' -- South America
                       ELSE '1' -- '9999' per NULL, ma è presente solo in region_receive
                     END
WHERE  region_send IN ( '0', '1', '2', '3',
                        '4', '5', '6', '7' ); -- 94.509 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN region_send INT;


--7) Personalizzazione della colonna "FFP_send".

-- Verifica generale dei dati presenti nella colonna.
SELECT FFP_send 
FROM dbo.workingArea 
GROUP BY FFP_send 
ORDER BY FFP_send; 
-- OUTPUT: No NULL

-- Verifica della presenza di caratteri non standard.
SELECT FFP_send 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', FFP_send) > 0 
GROUP BY FFP_send;

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET FFP_send = TRIM(FFP_send); -- 94.509 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN FFP_send BIT;


--8) Personalizzazione della colonna "v2lgfemleg_send".

-- Verifica generale dei dati presenti nella colonna.
SELECT v2lgfemleg_send 
FROM dbo.workingArea 
GROUP BY v2lgfemleg_send 
ORDER BY v2lgfemleg_send; 
-- OUTPUT: '0.00', '9999.00' per NULL.

-- Verifica della presenza di caratteri non standard.
SELECT v2lgfemleg_send 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', v2lgfemleg_send) > 0 
GROUP BY v2lgfemleg_send;

/* In questa ulteriore ricerca viene incluso momentaneamente il punto come carattere standard 
   per selezionare altri eventuali caratteri non standard. */
SELECT v2lgfemleg_send 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z .]%', v2lgfemleg_send) > 0 
GROUP BY v2lgfemleg_send;

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET v2lgfemleg_send = TRIM(v2lgfemleg_send); -- 94.509 righe

-- Sostituzione del valore '9999.00' con NULL.
UPDATE dbo.workingArea 
SET v2lgfemleg_send = NULL 
WHERE v2lgfemleg_send = '9999.00'; -- 6.047 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN v2lgfemleg_send DECIMAL(18,2);


--9) Personalizzazione della colonna "cname_receive".

-- Verifica generale dei dati presenti nella colonna.
SELECT cname_receive 
FROM dbo.workingArea 
GROUP BY cname_receive 
ORDER BY cname_receive; 
-- OUTPUT: '9999' per NULL.

-- Verifica della presenza di caratteri non standard.
SELECT cname_receive 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', cname_receive) > 0 
GROUP BY cname_receive;
-- Nel contesto specifico dei paesi, i caratteri non standard sono considerati standard, quali virgole, apostrofi, trattini e accenti.

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET cname_receive = TRIM(cname_receive); -- 94.509 righe

-- Sostituzione del valore '9999' con NULL.
UPDATE dbo.workingArea 
SET cname_receive = NULL 
WHERE cname_receive = '9999'; -- 5 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN cname_receive NVARCHAR(55);


--10) Personalizzazione della colonna "ccodealp_receive".

-- Verifica generale dei dati presenti nella colonna.
SELECT ccodealp_receive 
FROM dbo.workingArea 
GROUP BY ccodealp_receive 
ORDER BY ccodealp_receive; 
-- OUTPUT: '9999' per NULL.

-- Verifica della presenza di caratteri non standard.
SELECT ccodealp_receive 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', ccodealp_receive) > 0 
GROUP BY ccodealp_receive;

-- Identificazione del carattere non standard.
SELECT RIGHT(ccodealp_receive, 1)        AS LastChar,
       ASCII(RIGHT(ccodealp_receive, 1)) AS LastCharAsciiCode
FROM   dbo.workingarea
WHERE  PATINDEX('%[^0-9a-zA-Z ]%', ccodealp_receive) > 0
GROUP  BY RIGHT(ccodealp_receive, 1),
          ASCII(RIGHT(ccodealp_receive, 1)); 
/* OUTPUT: LastChar: ' ' - LastCharAsciiCode: 160 (no-break space).
LastChar: restituisce l'ultimo carattere della colonna ccodealp_receive.
LastCharAsciiCode: restituisce il codice ASCII dell'ultimo carattere della colonna ccodealp_receive. */

-- Eliminazione del carattere non standard.
UPDATE dbo.workingArea 
SET ccodealp_receive = REPLACE(ccodealp_receive, CHAR(160),''); -- 94.509 righe

-- Sostituzione del valore '9999' con NULL.
UPDATE dbo.workingArea 
SET ccodealp_receive = NULL WHERE ccodealp_receive = '9999'; -- 10 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN ccodealp_receive VARCHAR(10);


--11) Personalizzazione della colonna "region_receive".

-- Verifica generale dei dati presenti nella colonna.
SELECT region_receive 
FROM dbo.workingArea 
GROUP BY region_receive 
ORDER BY region_receive; 
-- OUTPUT '9999' per NULL.

-- Verifica della presenza di caratteri non standard.
SELECT region_receive 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', region_receive) > 0 
GROUP BY region_receive;

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET region_receive = TRIM(region_receive); -- 94.509 righe

/* Da CodeBooK: 
0 Africa, 1 Asia, 2 Central and North America, 3 Europe, 4 Middle East, 5 Nordic countries, 6 Oceania, 7 South America, 9999 Missing 

Ho scelto di seguire il modello a sette continenti: 
1 NULL, 2 Africa, 3 Antarctica, 4 Asia, 5 Europe, 6 North America, 7 Oceania, 8 South America */
UPDATE dbo.workingArea
SET    region_receive = CASE region_receive
                          WHEN '0' THEN '2' -- Africa
                          WHEN '1' THEN '4' -- Asia
                          WHEN '2' THEN '6' -- DA: Central and North America A: North America
                          WHEN '3' THEN '5' -- Europe
                          WHEN '4' THEN '4' -- DA: Middle East AD: Asia
                          WHEN '5' THEN '5' -- DA: Nordic countries AD: Europe
                          WHEN '6' THEN '7' -- Oceania
                          WHEN '7' THEN '8' -- South America
                          ELSE '1' -- '9999' per NULL
                        END
WHERE  region_receive IN ( '0', '1', '2', '3',
                           '4', '5', '6', '7', '9999' ); -- 94.509 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN region_receive INT;


--12) Personalizzazione della colonna "FFP_receive".

-- Verifica generale dei dati presenti nella colonna.
SELECT FFP_receive 
FROM dbo.workingArea 
GROUP BY FFP_receive 
ORDER BY FFP_receive; 
-- OUTPUT: '9999' per NULL.

-- Verifica della presenza di caratteri non standard.
SELECT FFP_receive 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', FFP_receive) > 0 
GROUP BY FFP_receive;

-- Rimozione di eventuali spazi vuoti.
UPDATE dbo.workingArea 
SET FFP_receive = TRIM(FFP_receive); -- 94.509 righe

-- Sostituzione  del valore '9999' con NULL.
UPDATE dbo.workingArea 
SET FFP_receive = NULL 
WHERE FFP_receive = '9999'; -- 5 righe

-- Aggiornamento del tipo di dato.
ALTER TABLE dbo.workingArea 
	ALTER COLUMN FFP_receive BIT;


/* Colonne prive di valori NULL: year, cname_send, region_send, FFP_send.

- Colonne con valori NULL o corrispondenti:
- gender: 99.
- title: 0, 99. (nb. nel codebook il valore 0 è assente, ho deciso di considerarlo NULL).
- ccodealp_send: 9999
- v2lgfemleg_send: 9999.00 (nb. è presente anche 0.00 che ovviamente non corrisponde a NULL).
- cnme_receive/ ccodealp_receive/ region_receive/ FFP_receive: 9999 - tutte le colonne riguardanti i paesi di destinazione. */