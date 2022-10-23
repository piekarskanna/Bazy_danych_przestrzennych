-- Database: cw2

-- DROP DATABASE IF EXISTS cw2;

CREATE DATABASE cw2
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Polish_Poland.1250'
    LC_CTYPE = 'Polish_Poland.1250'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;
	
-- SHAPEFILE - geoprzestrzenny format danych wektorowych dla oprogramowania GIS

CREATE EXTENSION postgis; 

-- 4) Wyznacz liczbę budynków (tabela: popp, atrybut: f_codedesc, reprezentowane, jako punkty) 
--    położonych w odległości mniejszej niż 1000 m od głównych rzek. Budynki spełniające 
--    to kryterium zapisz do osobnej tabeli tableB.

-- CREATE TABLE name AS  SELECT ... - tworzenie tabeli przy uzyciu istniejacej tabeli
								   -- nowa tabela zostaje wypelniona wartosciami ze starej tabeli
									
CREATE TABLE tableB AS SELECT popp.* 
		       FROM popp, majrivers 
		       WHERE popp.f_codedesc = 'Building' AND  ST_Distance(majrivers.geom, popp.geom) < 1000;
SELECT COUNT(*) 
FROM tableB;

SELECT * FROM tableB;

-- 5) Utwórz tabelę o nazwie airportsNew. Z tabeli airports zaimportuj nazwy lotnisk, 
--	  ich geometrię, a także atrybut elev, reprezentujący wysokość n.p.m.  

-- kopiowanie kolumn do nowej tabeli
SELECT name, geom, elev
INTO airportsNew 
FROM airports;

SELECT *
FROM airportsNew
-- WHERE name = 'airportB';

-- 5a) Znajdź lotnisko, które położone jest najbardziej na zachód i najbardziej na wschód.  

SELECT name as zachod 
FROM airportsNew
ORDER BY ST_X(geom) DESC
LIMIT 1;

SELECT name as wschod
FROM airportsNew
ORDER BY ST_X(geom) 
LIMIT 1;

-- 5b) Do tabeli airportsNew dodaj nowy obiekt - lotnisko, które położone
--     jest w punkcie środkowym drogi pomiędzy lotniskami znalezionymi w punkcie a. 
--     Lotnisko nazwij airportB. Wysokość n.p.m. przyjmij dowolną.

INSERT INTO airportsNew 
VALUES ('airportB',(SELECT ST_Centroid(ST_ShortestLine((SELECT geom 
							FROM airportsNew 
							WHERE name = 'ANNETTE ISLAND'), (SELECT geom 
											 FROM airportsNew 
											 WHERE name = 'ATKA')))), 200);

	
-- 6) Wyznacz pole powierzchni obszaru, który oddalony jest mniej niż 1000 jednostek
--    od najkrótszej linii łączącej jezioro o nazwie ‘Iliamna Lake’ i lotnisko o nazwie „AMBLER”

SELECT ST_Area(ST_Buffer(ST_ShortestLine(lakes.geom, airportsNew.geom), 1000)) AS area
FROM lakes, airportsNew
WHERE lakes.names = 'Iliamna Lake' AND airportsNew.name = 'AMBLER';
	
-- 7) Napisz zapytanie, które zwróci sumaryczne pole powierzchni poligonów reprezentujących 
--	  poszczególne typy drzew znajdujących się na obszarze tundry i bagien (swamps).  

-- ST_Within(geom.a, geom.b) - zwraca T jeśli geom.a znajduje sie calkowicie wewnatrz geom.b
-- ST_Within jest odwrotnością ST_Contains . Więc ST_Within(A,B) = ST_Contains(B,A).
							
SELECT SUM(ST_Area(trees.geom)) AS pole , trees.vegdesc AS rodzaj
FROM trees, tundra, swamp
WHERE ST_Within(trees.geom, tundra.geom) OR ST_Within(trees.geom, swamp.geom)
GROUP BY trees.vegdesc;

SELECT SUM(ST_Area(trees.geom)) AS pole , trees.vegdesc AS rodzaj
FROM trees, tundra, swamp
WHERE ST_Contains(tundra.geom, trees.geom) OR ST_Contains(swamp.geom, trees.geom)
GROUP BY trees.vegdesc;
