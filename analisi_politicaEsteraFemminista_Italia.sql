
/* 1 FFP_send / FeministForeignPolicy_S:
2014: Sweden
2019: Canada, France, Mexico, Sweden
2021: Canada, France, Libya, Luxembourg, Mexico, Spain, Sweden.

 1 FFP_receive / FeministForeignPolicy_S:
2014: Sweden
2019: Canada, France, Mexico, Sweden
2021: Canada, France, Libya, Luxembourg, Mexico, Spain, Sweden. */

-- prova generica da workingArea.
SELECT year, cname_send, FFP_send
FROM dbo.workingArea
WHERE FFP_send = 1
GROUP BY year, cname_send, FFP_send; -- 12 righe dal 2014

SELECT year, cname_receive, FFP_receive
FROM dbo.workingArea
WHERE FFP_receive = 1
GROUP BY year, cname_receive, FFP_receive; -- 12 righe dal 2014

-- Paesi d'origine aderenti ad una politica estera femminista.
SELECT Y.year, VW.country_GROUP_BY, SC.feministForeignPolicy
FROM dbo.targetArea AS TA
LEFT JOIN dbo.sendingCountries AS SC ON TA.sendingCountryID = SC.sendingCountryID
LEFT JOIN vw_country_GROUP_BY AS VW ON SC.countryID = VW.countryID
LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
WHERE SC.feministForeignPolicy = 1
GROUP BY Y.year, VW.country_GROUP_BY, SC.feministForeignPolicy;

-- Paesi di destinazione aderenti ad una politica estera femminista.
SELECT Y.year, VW.country_GROUP_BY, RC.feministForeignPolicy
FROM dbo.targetArea AS TA
LEFT JOIN dbo.receivingCountries AS RC ON TA.receivingCountryID = RC.receivingCountryID
LEFT JOIN vw_country_GROUP_BY AS VW ON RC.countryID = VW.countryID
LEFT JOIN dbo.years AS Y ON TA.yearID = Y.yearID
WHERE RC.feministForeignPolicy = 1
GROUP BY Y.year, VW.country_GROUP_BY, RC.feministForeignPolicy;

---

-- Italia
-- paesi che non ci sono più 

