-- Dire quali colonne non ho considerato e perché
-- Mettere che tutte le colonne possono essere a NULL, tranne le PK ovviamente.

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

-- In un'unica query, non è possibile aggiungere vincoli (CONSTRAINTS) come parte della clausola SELECT INTO.
-- ADD CONSTRAINT PK_workingArea PRIMARY KEY (workingAreaID)
ALTER TABLE dbo.workingArea ADD CONSTRAINT PK_workingArea PRIMARY KEY (workingAreaID); -- PK_<TableName>

SELECT * FROM dbo.workingArea;

/* NOTE - Variante in MS SQL di:
CREATE TABLE tab_name
SELECT col, col2 ...
FROM old_tab */
---------------------------------------------------------------------------------------------------------------------------
-- Tab workingarea: sistemazione dei NULL e dei tipi di dato delle colonne.

SELECT year FROM dbo.workingArea GROUP BY year ORDER BY year; --1) No NULL
SELECT gender FROM dbo.workingArea GROUP BY gender ORDER BY gender; --2) 0, 1, 99(NULL)
SELECT title FROM dbo.workingArea GROUP BY title ORDER BY title; --3) 0(NULL), 1, 2, 3, 96, 97, 98, 99(NULL)
SELECT cname_send FROM dbo.workingArea GROUP BY cname_send ORDER BY cname_send; --4) No NULL
SELECT ccodealp_send FROM dbo.workingArea GROUP BY ccodealp_send ORDER BY ccodealp_send; --5) 9999(NULL)
SELECT region_send FROM dbo.workingArea GROUP BY region_send ORDER BY region_send; --6) Da 0 a 7, no NULL.
SELECT FFP_send FROM dbo.workingArea GROUP BY FFP_send ORDER BY FFP_send; --7) 0, 1
SELECT v2lgfemleg_send FROM dbo.workingArea GROUP BY v2lgfemleg_send ORDER BY v2lgfemleg_send; --8) 0.00, 9999.00(NULL)
SELECT cname_receive FROM dbo.workingArea GROUP BY cname_receive ORDER BY cname_receive; --9) 9999(NULL)
SELECT ccodealp_receive FROM dbo.workingArea GROUP BY ccodealp_receive ORDER BY ccodealp_receive; --10) 9999(NULL)
SELECT region_receive FROM dbo.workingArea GROUP BY region_receive ORDER BY region_receive; --11) Da 0 a 7, 9999(NULL)
SELECT FFP_receive FROM dbo.workingArea GROUP BY FFP_receive ORDER BY FFP_receive; --12) 0, 1, 9999(NULL)
---
-- 1) Personalizzazione della colonna "year"
SELECT year FROM dbo.workingArea GROUP BY year ORDER BY year; -- No NULL

SELECT LEN(year) AS lenYear FROM dbo.workingArea GROUP BY LEN(year); -- 4, non dovrebbero esserci spazi presenti.

ALTER TABLE dbo.workingArea ALTER COLUMN year INT;

--2) Personalizzazione della colonna "gender"
SELECT gender FROM dbo.workingArea GROUP BY gender ORDER BY gender; -- 0, 1, 99(NULL)

SELECT gender, LEN(gender) AS lenGender FROM dbo.workingArea GROUP BY gender, LEN(gender) ORDER BY gender ASC; -- 1, 1, 2

UPDATE dbo.workingArea SET gender = NULL WHERE gender = '99'; -- NULL - 5.409 righe

ALTER TABLE dbo.workingArea ALTER COLUMN gender BIT;
---
--3) Personalizzazione della colonna "title"
SELECT title FROM dbo.workingArea GROUP BY title ORDER BY title; -- 0(NULL), 1, 2, 3, 96, 97, 98, 99(NULL)

SELECT title, LEN(title) AS lenTitle FROM dbo.workingArea GROUP BY title, LEN(title) ORDER BY title ASC; -- 1, 2

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

---	

-- 4) Personalizzazione della colonna "cname_send"

SELECT cname_send FROM dbo.workingArea GROUP BY cname_send ORDER BY cname_send; -- NO NULL

-- Non funziona come stored procedure con un unico parametro ripetuto).
SELECT spaceType, FORMAT(COUNT(*), '#,0') AS count
FROM (
    SELECT 
		CASE 
			WHEN CHARINDEX(CHAR(160), cname_send) > 0 THEN 'NBSP' -- Spazio non stampabile
			WHEN CHARINDEX(CHAR(32), cname_send) > 0 THEN 'Regular space' -- Spazio regolare ' '
			WHEN CHARINDEX(CHAR(9), cname_send) > 0 THEN 'Tab space' -- Tabulazione orizzontale (tab)
			WHEN CHARINDEX(CHAR(13), cname_send) > 0 THEN 'Carriage return' --  Ritorno a capo
			WHEN CHARINDEX(CHAR(10), cname_send) > 0 THEN 'Line feed' -- Avanzamento riga
			WHEN CHARINDEX(CHAR(11), cname_send) > 0 THEN 'Vertical tab' -- Tabulazione verticale
			WHEN CHARINDEX(CHAR(12), cname_send) > 0 THEN 'Form feed' -- Avanzamento pagina
			ELSE 'No space detected'
		END AS spaceType
    FROM 
        dbo.workingArea
) AS subQuery
GROUP BY spaceType;
-- OUTPUT: Regular space 20.375 - No space detected 20.375

-- Dato che TRIM rimuove solo gli spazi vuoti (codice ASCII 32) all'inizio e alla fine di una stringa, nel dubbio aggiorno ripulendo le stringhe:
UPDATE dbo.workingArea SET cname_send = TRIM(cname_send); -- 94.509 righe
---

--5) Personalizzazione della colonna "ccodealp_send"
SELECT ccodealp_send FROM dbo.workingArea GROUP BY ccodealp_send ORDER BY ccodealp_send; -- 9999(NULL)

SELECT LEN(ccodealp_send) AS len_ccodealp_send FROM dbo.workingArea GROUP BY LEN(ccodealp_send); -- 3, 4, 5, NULL

SELECT ccodealp_send, LEN(ccodealp_send) AS len_ccodealp_send FROM dbo.workingArea WHERE LEN(ccodealp_send) > 3 
	GROUP BY ccodealp_send, LEN(ccodealp_send) ORDER BY len_ccodealp_send DESC, ccodealp_send ASC;

-- Non avendo ottenuto i risultati sperati con TRIM deduco che non si tratti di uno spazio regolare.
SELECT LEN(TRIM(ccodealp_send)) AS len_ccodealp_send FROM dbo.workingArea GROUP BY LEN(TRIM(ccodealp_send)); -- 3, 4, 5, NULL

/* TRIM di solito rimuove solo gli spazi vuoti (codice ASCII 32) all'inizio e alla fine di una stringa.

Per rimuovere anche altri tipi di spazi puoi utilizzare la funzione REPLACE per sostituire tutti gli spazi 
non desiderati con uno spazio vuoto, e quindi applicare TRIM. 

TRIM(REPLACE(testo, CHAR(160), ' ')) */

SELECT LEN(ccodealp_send) AS len_ccodealp_send,
	   RIGHT(ccodealp_send, 1) AS LastChar, 
	   ASCII(RIGHT(ccodealp_send, 1)) AS LastCharAsciiCode 
FROM dbo.workingArea 
WHERE LEN(ccodealp_send) >= 4
	AND ccodealp_send != '9999'
GROUP BY LEN(ccodealp_send),
		 RIGHT(ccodealp_send, 1), 
		 ASCII(RIGHT(ccodealp_send, 1));
-- OUTPUT: LastChar: ' ' - LastCharAsciiCode: 160 (no-break space).

/* LastChar: Questa colonna restituisce l'ultimo carattere della colonna alpCode.
LastCharAsciiCode: Questa colonna restituisce il codice ASCII dell'ultimo carattere della colonna alpCode.
La clausola WHERE limita i risultati alle righe in cui la lunghezza della colonna alpCode è >= 4.  */

SELECT LEN(REPLACE(ccodealp_send, CHAR(160),'')) AS len_ccodealp_send FROM dbo.workingArea 
	WHERE ccodealp_send != '9999' GROUP BY LEN(REPLACE(ccodealp_send, CHAR(160),''));  -- 3

UPDATE dbo.workingArea 
SET ccodealp_send= REPLACE(ccodealp_send, CHAR(160),''); -- 94.509 righe

UPDATE dbo.workingArea SET ccodealp_send = NULL WHERE ccodealp_send = '9999'; -- NULL - 124 righe

---
--6) Personalizzazione della colonna "region_send"

-- 1 NULL - 2 Africa - 3 Asia, - 4 Europa, - 5  North America, - 6 Oceania, -7  South America.
SELECT region_send FROM dbo.workingArea GROUP BY region_send ORDER BY region_send; -- DA 0 a 7, no NULL

SELECT LEN(region_send) AS len_region_send FROM dbo.workingArea GROUP BY LEN(region_send); -- 1

UPDATE dbo.workingArea SET region_send = CASE region_send
														  WHEN '0' THEN '2' -- Africa
														  WHEN '1' THEN '4' -- Asia
														  WHEN '2' THEN '6' -- DA: Central and North America A: North America
														  WHEN '3' THEN '5' -- Europe
														  WHEN '4' THEN '4' -- DA: Middle East AD: Asia
														  WHEN '5' THEN '5' -- DA: Nordic countries AD: Europe
														  WHEN '6' THEN '7' -- Oceania
														  WHEN '7' THEN '8' -- South America
														  ELSE '1' -- Es. '9999' che sarebbe NULL, ma non è presente qui, ma in region_receive
												END
WHERE region_send IN ('0', '1', '2', '3', '4', '5', '6', '7'); -- 94.509 righe

ALTER TABLE dbo.workingArea ALTER COLUMN region_send INT;

---
--7) Personalizzazione della colonna "FFP_send"
SELECT FFP_send FROM dbo.workingArea GROUP BY FFP_send ORDER BY FFP_send; -- 0, 1, no NULL

SELECT LEN(FFP_send) AS len_FFP_send FROM dbo.workingArea GROUP BY LEN(FFP_send); -- 1

ALTER TABLE dbo.workingArea ALTER COLUMN FFP_send BIT;
---
--8) Personalizzazione della colonna "v2lgfemleg_send"
SELECT v2lgfemleg_send FROM dbo.workingArea GROUP BY v2lgfemleg_send ORDER BY v2lgfemleg_send; -- 0.00, 9999.00(NULL)

SELECT LEN(v2lgfemleg_send) AS len_v2lgfemleg_send FROM dbo.workingArea GROUP BY LEN(v2lgfemleg_send); -- 4. 5, 7

SELECT v2lgfemleg_send, LEN(v2lgfemleg_send) AS len_v2lgfemleg_send FROM dbo.workingArea WHERE LEN(v2lgfemleg_send) > 3 
	GROUP BY v2lgfemleg_send ORDER BY len_v2lgfemleg_send DESC;

UPDATE dbo.workingArea SET v2lgfemleg_send = NULL WHERE v2lgfemleg_send = '9999.00'; -- NULL - -6.047 righe

ALTER TABLE dbo.workingArea ALTER COLUMN v2lgfemleg_send DECIMAL(18,2);

---
--9) Personalizzazione della colonna "cname_receive"
SELECT cname_receive FROM dbo.workingArea GROUP BY cname_receive ORDER BY cname_receive; -- 9999(NULL)

SELECT spaceType, FORMAT(COUNT(*), '#,0') AS count
FROM (
    SELECT 
		CASE 
			WHEN CHARINDEX(CHAR(160), cname_receive) > 0 THEN 'NBSP' -- Spazio non stampabile
			WHEN CHARINDEX(CHAR(32), cname_receive) > 0 THEN 'Regular space' -- Spazio regolare ' '
			WHEN CHARINDEX(CHAR(9), cname_receive) > 0 THEN 'Tab space' -- Tabulazione orizzontale (tab)
			WHEN CHARINDEX(CHAR(13), cname_receive) > 0 THEN 'Carriage return' --  Ritorno a capo
			WHEN CHARINDEX(CHAR(10), cname_receive) > 0 THEN 'Line feed' -- Avanzamento riga
			WHEN CHARINDEX(CHAR(11), cname_receive) > 0 THEN 'Vertical tab' -- Tabulazione verticale
			WHEN CHARINDEX(CHAR(12), cname_receive) > 0 THEN 'Form feed' -- Avanzamento pagina
			ELSE 'No space detected'
		END AS spaceType
    FROM 
        dbo.workingArea
) AS subQuery
GROUP BY spaceType;
-- OUTPUT: Regular space 20.148 - No space detected 74.361

-- Dato che TRIM rimuove solo gli spazi vuoti (codice ASCII 32) all'inizio e alla fine di una stringa, nel dubbio aggiorno ripulendo le stringhe:
UPDATE dbo.workingArea SET cname_receive = TRIM(cname_receive); -- 94.509 righe

UPDATE dbo.workingArea SET cname_receive = NULL WHERE cname_receive = '9999'; -- NULL - 5 righe
---
--10) Personalizzazione della colonna "ccodealp_receive"
SELECT ccodealp_receive FROM dbo.workingArea GROUP BY ccodealp_receive ORDER BY ccodealp_receive; -- 9999(NULL)

SELECT LEN(ccodealp_receive) AS len_ccodealp_receive FROM dbo.workingArea GROUP BY LEN(ccodealp_receive); -- 3, 4 (NULL)

SELECT ccodealp_receive, LEN(ccodealp_receive) AS len_ccodealp_receive FROM dbo.workingArea WHERE LEN(ccodealp_receive) > 3 
	GROUP BY ccodealp_receive, LEN(ccodealp_receive) ORDER BY len_ccodealp_receive DESC, ccodealp_receive ASC;

-- Non avendo ottenuto i risultati sperati con TRIM deduco che non si tratti di uno spazio regolare.
SELECT LEN(TRIM(ccodealp_receive)) AS len_ccodealp_receive FROM dbo.workingArea GROUP BY LEN(TRIM(ccodealp_receive)); -- 3, 4

/* TRIM di solito rimuove solo gli spazi vuoti (codice ASCII 32) all'inizio e alla fine di una stringa.

Per rimuovere anche altri tipi di spazi puoi utilizzare la funzione REPLACE per sostituire tutti gli spazi 
non desiderati con uno spazio vuoto, e quindi applicare TRIM. 

TRIM(REPLACE(testo, CHAR(160), ' ')) */

SELECT LEN(ccodealp_receive) AS len_ccodealp_send,
	   RIGHT(ccodealp_receive, 1) AS LastChar, 
	   ASCII(RIGHT(ccodealp_receive, 1)) AS LastCharAsciiCode 
FROM dbo.workingArea 
WHERE LEN(ccodealp_receive) > 3
	  AND ccodealp_receive != '9999'
GROUP BY LEN(ccodealp_receive),
		 RIGHT(ccodealp_receive, 1), 
		 ASCII(RIGHT(ccodealp_receive, 1));
-- OUTPUT: LastChar: ' ' - LastCharAsciiCode: 160 (no-break space).

/* LastChar: Questa colonna restituisce l'ultimo carattere della colonna alpCode.
LastCharAsciiCode: Questa colonna restituisce il codice ASCII dell'ultimo carattere della colonna alpCode.
La clausola WHERE limita i risultati alle righe in cui la lunghezza della colonna alpCode è >= 4.  */

SELECT LEN(REPLACE(ccodealp_receive, CHAR(160),'')) AS len_ccodealp_receive FROM dbo.workingArea 
	WHERE ccodealp_receive != '9999' GROUP BY LEN(REPLACE(ccodealp_receive, CHAR(160),'')); -- 3

UPDATE dbo.workingArea 
SET ccodealp_receive = REPLACE(ccodealp_receive, CHAR(160),''); -- 94.509 righe

UPDATE dbo.workingArea SET ccodealp_receive = NULL WHERE ccodealp_receive = '9999'; -- NULL - 10 righe

---
--11) Personalizzazione della colonna "region_receive"
SELECT region_receive FROM dbo.workingArea GROUP BY region_receive ORDER BY region_receive; -- DA 0 a 7 + 9999(NULL)

SELECT LEN(region_receive) AS len_region_receive FROM dbo.workingArea GROUP BY LEN(region_receive); -- 1

SELECT region_receive, LEN(region_receive) AS len_region_receive FROM dbo.workingArea WHERE LEN(region_receive) > 3 
	GROUP BY region_receive, LEN(region_receive); -- '9999' 4 len

UPDATE dbo.workingArea SET region_receive = CASE region_receive
														  WHEN '0' THEN '2' -- Africa
														  WHEN '1' THEN '4' -- Asia
														  WHEN '2' THEN '6' -- DA: Central and North America A: North America
														  WHEN '3' THEN '5' -- Europe
														  WHEN '4' THEN '4' -- DA: Middle East AD: Asia
														  WHEN '5' THEN '5' -- DA: Nordic countries AD: Europe
														  WHEN '6' THEN '7' -- Oceania
														  WHEN '7' THEN '8' -- South America
														  ELSE '1' -- Es. '9999' che sarebbe NULL.
												END
WHERE region_receive IN ('0', '1', '2', '3', '4', '5', '6', '7', '9999'); -- 94.509 righe

ALTER TABLE dbo.workingArea ALTER COLUMN region_receive INT;

---
--12) Personalizzazione della colonna "FFP_receive"
SELECT FFP_receive FROM dbo.workingArea GROUP BY FFP_receive ORDER BY FFP_receive; -- 0, 1, 9999(NULL)

SELECT LEN(FFP_receive) AS len_FFP_receive FROM dbo.workingArea GROUP BY LEN(FFP_receive); 

SELECT FFP_receive, LEN(FFP_receive) AS len_FFP_receive FROM dbo.workingArea 
	WHERE LEN(FFP_receive) > 1 GROUP BY FFP_receive, LEN(FFP_receive); -- '9999' 4 len

UPDATE dbo.workingArea SET FFP_receive = NULL WHERE FFP_receive = '9999'; -- NULL - 5 righe

ALTER TABLE dbo.workingArea ALTER COLUMN FFP_receive BIT;
---