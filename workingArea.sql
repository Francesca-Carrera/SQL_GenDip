

/* Perché non ho considerato Main_posting:
"sono state mantenute nel database, anche se a volte implicano combinazioni di pubblicazioni che sembrano improbabili. 
Alcuni di questi casi sono probabilmente errati" */
-------------------------------------------------------------------------------------------
CREATE DATABASE GenDip
GO
USE GenDip

-- Ho convertito il file di lavoro scaricato dal formato .xlsx a CSV.
-- Tasto destro su GenDip -> Attività -> Importa file flat -> nomino la tabella "stagingArea"
-- Flaggare "Consenti valori NULL".
-- Le colonne "cname_send" e "cname_receive" le imposto a NVARCHAR(100)
-- Tutte le altre le imposto a NVARCHAR(10)

-- Creazione tab workingArea con le colonne di mio interessa da tab stagingArea.

SELECT  
	IDENTITY(INT, 1,1) AS workingAreaID,
	-- CAST(NULL AS tipoDiDato_nonINT) AS nomeColonna,
	year,
	gender,
	title, 
	NULL AS cname_sendID, -- DA SPIEGARE
	cname_send,
	ccodealp_send,
	region_send,
	FFP_send,
	v2lgfemleg_send,
	NULL AS cname_receiveID, -- NULL per forza, altrimenti devo riempirli subito.
	cname_receive,
	ccodealp_receive,
	region_receive,
	FFP_receive 
INTO dbo.workingArea
FROM dbo.stagingArea; -- 94.509 righe

-- Aggiunta del vincolo alla chiave primaria.
ALTER TABLE dbo.workingArea ADD CONSTRAINT PK_workingArea PRIMARY KEY (workingAreaID); -- PK_<TableName>
--------------------------------------------------------------------------------------------------------------------------------------------
-- Normalizzazione dei dati: verifica della presenza di caratteri non standard, sistemazione dei NULL e dei tipi di dato delle colonne.

-- 1) Personalizzazione della colonna "year"
SELECT year FROM dbo.workingArea GROUP BY year ORDER BY year; -- No NULL

-- Con la funzione PATINDEX() cerco caratteri non standard, inclusi spazi non standard, 
-- nello specifico né numeri, né lettere maiuscole, né lettere minuscole.

/* Dentro le parentesi quadre [] all'interno di un'espressione regolare, il simbolo ^ ha un significato particolare: 
indica una negazione o una negazione logica.
Nel contesto di un'espressione regolare come [^0-9a-zA-Z .], il ^ all'interno delle parentesi quadre indica che stai 
cercando un carattere che non rientra nell'insieme specificato. 
Quindi, l'espressione corrisponderà a qualsiasi carattere diverso da numeri, lettere, spazi e il punto ".".
In breve, ^ all'interno delle parentesi quadre nega l'insieme di caratteri specificato.*/
SELECT year FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', year) > 0 GROUP BY year;

-- Con TRIM rimuovo eventuali spazi vuoti (codice ASCII 32) all'inizio e alla fine di una stringa.
UPDATE dbo.workingArea SET year = TRIM(year); -- 94.509 righe

ALTER TABLE dbo.workingArea ALTER COLUMN year INT;


--2) Personalizzazione della colonna "gender"
SELECT gender FROM dbo.workingArea GROUP BY gender ORDER BY gender; -- 0, 1, 99(NULL)

SELECT gender FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', gender) > 0 GROUP BY gender;

UPDATE dbo.workingArea SET gender = TRIM(gender); -- 94.509 righe

UPDATE dbo.workingArea SET gender = NULL WHERE gender = '99'; -- NULL - 5.409 righe

ALTER TABLE dbo.workingArea ALTER COLUMN gender BIT;


--3) Personalizzazione della colonna "title"
SELECT title FROM dbo.workingArea GROUP BY title ORDER BY title; -- 0(NULL), 1, 2, 3, 96, 97, 98, 99(NULL)

SELECT title FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', title) > 0 GROUP BY title;

UPDATE dbo.workingArea SET title = TRIM(title); -- 94.509 righe

UPDATE dbo.workingArea SET title = CASE title
											 WHEN '1' THEN '5' -- 'Chargé d’affaires'
											 WHEN '2' THEN '6' -- 'Minister'
											 WHEN '3' THEN '4' -- 'Ambassador'
											 WHEN '96' THEN '3' -- 'Acting chargé d’affaires'
											 WHEN '97' THEN '2' -- 'Acting ambassador'
											 WHEN '98' THEN '7' -- 'Other'
											 WHEN '99' THEN '1' -- NULL
									END
WHERE title IN ('1', '2', '3', '96', '97', '98', '99'); -- 94.504 righe

ALTER TABLE dbo.workingArea ALTER COLUMN title INT; 


-- 4) Personalizzazione della colonna "cname_send"

SELECT cname_send FROM dbo.workingArea GROUP BY cname_send ORDER BY cname_send; -- NO NULL in 211 valori presenti

SELECT cname_send FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', cname_send) > 0 GROUP BY cname_send;
-- Nel contesto specifico dei paesi, i caratteri non standard sono considerati standard, quali virgole, apostrofi, trattini e accenti.

UPDATE dbo.workingArea SET cname_send = TRIM(cname_send); -- 94.509 righe

ALTER TABLE dbo.workingArea ALTER COLUMN cname_send NVARCHAR(55);


--5) Personalizzazione della colonna "ccodealp_send"
SELECT ccodealp_send FROM dbo.workingArea GROUP BY ccodealp_send ORDER BY ccodealp_send; -- '9999' NULL

SELECT ccodealp_send FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', ccodealp_send) > 0 GROUP BY ccodealp_send;

SELECT RIGHT(ccodealp_send, 1) AS LastChar, 
	   ASCII(RIGHT(ccodealp_send, 1)) AS LastCharAsciiCode 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', ccodealp_send) > 0
GROUP BY RIGHT(ccodealp_send, 1), ASCII(RIGHT(ccodealp_send, 1));
/* OUTPUT: LastChar: ' ' - LastCharAsciiCode: 160 (no-break space).
LastChar: restituisce l'ultimo carattere della colonna ccodealp_send.
LastCharAsciiCode: restituisce il codice ASCII dell'ultimo carattere della colonna ccodealp_send. */

UPDATE dbo.workingArea SET ccodealp_send = REPLACE(ccodealp_send, CHAR(160),''); -- 94.509 righe

UPDATE dbo.workingArea SET ccodealp_send = NULL WHERE ccodealp_send = '9999'; -- NULL - 124 righe

ALTER TABLE dbo.workingArea ALTER COLUMN ccodealp_send VARCHAR(10);


--6) Personalizzazione della colonna "region_send"

/* Da CodeBooK: 
0 Africa, 1 Asia, 2 Central and North America, 3 Europe, 4 Middle East, 5 Nordic countries, 6 Oceania, 7 South America, 9999 Missing 

Ho scelto di seguire il modello a sette continenti: 
1 NULL, 2 Africa, 3 Antarctica, 4 Asia, 5 Europe, 6 North America, 7 Oceania, 8 South America */

SELECT region_send FROM dbo.workingArea GROUP BY region_send ORDER BY region_send; -- DA 0 a 7, no NULL

SELECT region_send FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', region_send) > 0 GROUP BY region_send;

UPDATE dbo.workingArea SET region_send = TRIM(region_send); -- 94.509 righe

UPDATE dbo.workingArea SET region_send = CASE region_send
														  WHEN '0' THEN '2' -- Africa
														  WHEN '1' THEN '4' -- Asia
														  WHEN '2' THEN '6' -- DA: Central and North America A: North America
														  WHEN '3' THEN '5' -- Europe
														  WHEN '4' THEN '4' -- DA: Middle East AD: Asia
														  WHEN '5' THEN '5' -- DA: Nordic countries AD: Europe
														  WHEN '6' THEN '7' -- Oceania
														  WHEN '7' THEN '8' -- South America
														  ELSE '1' -- '9999' che sarebbe NULL, non è presente qui, ma in region_receive
												END
WHERE region_send IN ('0', '1', '2', '3', '4', '5', '6', '7'); -- 94.509 righe

ALTER TABLE dbo.workingArea ALTER COLUMN region_send INT;


--7) Personalizzazione della colonna "FFP_send"
SELECT FFP_send FROM dbo.workingArea GROUP BY FFP_send ORDER BY FFP_send; -- 0, 1, no NULL

SELECT FFP_send FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', FFP_send) > 0 GROUP BY FFP_send;

UPDATE dbo.workingArea SET FFP_send = TRIM(FFP_send); -- 94.509 righe

ALTER TABLE dbo.workingArea ALTER COLUMN FFP_send BIT;


--8) Personalizzazione della colonna "v2lgfemleg_send"
SELECT v2lgfemleg_send FROM dbo.workingArea GROUP BY v2lgfemleg_send ORDER BY v2lgfemleg_send; -- 0.00, 9999.00(NULL)

SELECT v2lgfemleg_send FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', v2lgfemleg_send) > 0 GROUP BY v2lgfemleg_send;

/* Con questa ulteriore ricerca includo momentaneamente il punto come carattere standard 
per selezionare altri eventuali caratteri non standard. */
SELECT v2lgfemleg_send FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z .]%', v2lgfemleg_send) > 0 GROUP BY v2lgfemleg_send;

UPDATE dbo.workingArea SET v2lgfemleg_send = TRIM(v2lgfemleg_send);

UPDATE dbo.workingArea SET v2lgfemleg_send = NULL WHERE v2lgfemleg_send = '9999.00'; -- 6.047 righe

ALTER TABLE dbo.workingArea ALTER COLUMN v2lgfemleg_send DECIMAL(18,2);


--9) Personalizzazione della colonna "cname_receive"
SELECT cname_receive FROM dbo.workingArea GROUP BY cname_receive ORDER BY cname_receive; -- '9999' per NULL.

SELECT cname_receive FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', cname_receive) > 0 GROUP BY cname_receive;
-- Nel contesto specifico dei paesi, i caratteri non standard sono considerati standard, quali virgole, apostrofi, trattini e accenti.

UPDATE dbo.workingArea SET cname_receive = TRIM(cname_receive); -- 94.509 righe

UPDATE dbo.workingArea SET cname_receive = NULL WHERE cname_receive = '9999'; -- 5 righe

ALTER TABLE dbo.workingArea ALTER COLUMN cname_receive NVARCHAR(55);


--10) Personalizzazione della colonna "ccodealp_receive"
SELECT ccodealp_receive FROM dbo.workingArea GROUP BY ccodealp_receive ORDER BY ccodealp_receive; -- '9999' NULL

SELECT ccodealp_receive FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', ccodealp_receive) > 0 GROUP BY ccodealp_receive;

SELECT RIGHT(ccodealp_receive, 1) AS LastChar, 
	   ASCII(RIGHT(ccodealp_receive, 1)) AS LastCharAsciiCode 
FROM dbo.workingArea 
WHERE PATINDEX('%[^0-9a-zA-Z ]%', ccodealp_receive) > 0
GROUP BY RIGHT(ccodealp_receive, 1), ASCII(RIGHT(ccodealp_receive, 1));
/* OUTPUT: LastChar: ' ' - LastCharAsciiCode: 160 (no-break space).
LastChar: restituisce l'ultimo carattere della colonna ccodealp_receive.
LastCharAsciiCode: restituisce il codice ASCII dell'ultimo carattere della colonna ccodealp_receive. */

UPDATE dbo.workingArea SET ccodealp_receive = REPLACE(ccodealp_receive, CHAR(160),''); -- 94.509 righe

UPDATE dbo.workingArea SET ccodealp_receive = NULL WHERE ccodealp_receive = '9999'; -- 10 righe

ALTER TABLE dbo.workingArea ALTER COLUMN ccodealp_receive VARCHAR(10);


--11) Personalizzazione della colonna "region_receive"

/* Da CodeBooK: 
0 Africa, 1 Asia, 2 Central and North America, 3 Europe, 4 Middle East, 5 Nordic countries, 6 Oceania, 7 South America, 9999 Missing 

Ho scelto di seguire il modello a sette continenti: 
1 NULL, 2 Africa, 3 Antarctica, 4 Asia, 5 Europe, 6 North America, 7 Oceania, 8 South America */

SELECT region_receive FROM dbo.workingArea GROUP BY region_receive ORDER BY region_receive; -- '9999' per NULL

SELECT region_receive FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', region_receive) > 0 GROUP BY region_receive;

UPDATE dbo.workingArea SET region_receive = TRIM(region_receive); -- 94.509 righe

UPDATE dbo.workingArea SET region_receive = CASE region_receive
														  WHEN '0' THEN '2' -- Africa
														  WHEN '1' THEN '4' -- Asia
														  WHEN '2' THEN '6' -- DA: Central and North America A: North America
														  WHEN '3' THEN '5' -- Europe
														  WHEN '4' THEN '4' -- DA: Middle East AD: Asia
														  WHEN '5' THEN '5' -- DA: Nordic countries AD: Europe
														  WHEN '6' THEN '7' -- Oceania
														  WHEN '7' THEN '8' -- South America
														  ELSE '1' -- '9999' che sarebbe NULL
												END
WHERE region_receive IN ('0', '1', '2', '3', '4', '5', '6', '7', '9999'); -- 94.509 righe

ALTER TABLE dbo.workingArea ALTER COLUMN region_receive INT;


--12) Personalizzazione della colonna "FFP_receive"
SELECT FFP_receive FROM dbo.workingArea GROUP BY FFP_receive ORDER BY FFP_receive; -- '9999' per NULL

SELECT FFP_receive FROM dbo.workingArea WHERE PATINDEX('%[^0-9a-zA-Z ]%', FFP_receive) > 0 GROUP BY FFP_receive;

UPDATE dbo.workingArea SET FFP_receive = TRIM(FFP_receive); -- 94.509 righe

UPDATE dbo.workingArea SET FFP_receive = NULL WHERE FFP_receive = '9999'; -- 5 righe

ALTER TABLE dbo.workingArea ALTER COLUMN FFP_receive BIT;


/* - Colonne prive di valori NULL: year, cname_send, region_send, FFP_send.

- Colonne con valori NULL o corrispondenti:
- gender: 99.
- title: 0, 99. (nb. nel codebook il valore 0 è assente, ho deciso di considerarlo NULL).
- ccodealp_send: 9999
- v2lgfemleg_send: 9999.00 (nb. è presente anche 0.00 che ovviamente non corrisponde a NULL).
- cnme_receive/ ccodealp_receive/ region_receive/ FFP_receive: 9999 - tutte le colonne riguardanti i paesi di destinazione. */