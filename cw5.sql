-- Database: cw5

    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Polish_Poland.1250'
    LC_CTYPE = 'Polish_Poland.1250'
    TABLESPACE = pg_default
-- DROP DATABASE IF EXISTS cw5;

CREATE DATABASE cw5
    WITH 
    CONNECTION LIMIT = -1;
	
CREATE EXTENSION postgis;

-- 1. Utwórz tabelę obiekty. W tabeli umieść nazwy i geometrie obiektów przedstawionych poniżej. Układ odniesienia
-- ustal jako niezdefiniowany. Definicja geometrii powinna odbyć się za pomocą typów złożonych, właściwych dla EWKT.

CREATE TABLE obiekty (id INT PRIMARY KEY, nazwa VARCHAR(50), geom GEOMETRY);

DROP TABLE obiekty;

--  St_GeomFromEWKT(text EWKT) - tworzy obiekt ST_Geometry PostGIS z reprezentacji OGC Extended Well-Known Text (EWKT).

-- obiekt1 
-- CompoundCurve - pojedyncza krzywa ciągłą, która może zawierać odcinki łuku kołowego i odcinki liniowe.
INSERT INTO obiekty 
VALUES (1, 'obiekt1', St_GeomFromEWKT('COMPOUNDCURVE(LINESTRING(0 1, 1 1), CIRCULARSTRING(1 1, 2 0, 3 1), 
				       CIRCULARSTRING(3 1, 4 2, 5 1), LINESTRING(5 1, 6 1))'));
									  
-- obiekt2 
-- CurvePolygon - przypomina wielokąt z pierścieniem zewnętrznym i zerem lub większą liczbą pierścieni wewnętrznych
INSERT INTO obiekty 
VALUES (2, 'obiekt2', ST_GeomFromEWKT('CURVEPOLYGON(COMPOUNDCURVE(LINESTRING(10 6, 14 6), CIRCULARSTRING(14 6, 16 4, 14 2), 
				       CIRCULARSTRING(14 2, 12 0, 10 2), LINESTRING(10 2, 10 6)), CIRCULARSTRING(11 2, 13 2, 11 2))'));

-- obiekt3 //CompoundCurve 
INSERT INTO obiekty 
VALUES (3, 'obiekt3', ST_GeomFromEWKT('COMPOUNDCURVE((10 17, 12 13), (12 13, 7 15), (7 15, 10 17))'));

-- obiekt4 //CompoundCurve
INSERT INTO obiekty 
VALUES (4, 'obiekt4',								
ST_GeomFromEWKT('COMPOUNDCURVE((20 20, 25 25), (25 25, 27 24), (27 24, 25 22), (25 22, 26 21), (26 21, 22 19), (22 19, 20.5 19.5))'));

-- obiekt5 //obiekt 3d
INSERT INTO obiekty 
VALUES (5, 'obiekt5',  ST_GeomFromEWKT('MULTIPOINT(30 30 59, 38 32 234)'));

-- obiekt6 // GEOMETRYCOLLECTION
INSERT INTO obiekty 
VALUES (6, 'obiekt6', ST_GeomFromEWKT('GEOMETRYCOLLECTION(LINESTRING(1 1, 3 2), POINT(4 2))'));

select *
from obiekty;

-- 1. Wyznacz pole powierzchni bufora o wielkości 5 jednostek, który został utworzony wokół najkrótszej linii łączącej
-- obiekt 3 i 4
SELECT ST_Area(ST_Buffer(ST_ShortestLine((SELECT geom 
					  FROM obiekty 
					  WHERE nazwa = 'obiekt3'), (SELECT geom 
								     FROM obiekty 
								     WHERE nazwa = 'obiekt4')), 5));

-- 2. Zamień obiekt4 na poligon. Jaki warunek musi być spełniony, aby można było wykonać to zadanie? Zapewnij te
-- warunki.
-- Obiekt musi być zamknięty (ostatni punkt = pierwszy punkt)
-- ST_MakePolygon() -Geometrie wejściowe muszą być zamkniętymi ciągami lini
-- ST_LineMerge() -wraca LineString lub MultiLineString utworzony przez połączenie elementów linii
-- ST_CollectionHomogenize(geometry collection) - Podana kolekcja geometrii zwraca "najprostszą" reprezentację jej zawartości (Homogeniczne - jednolite)
-- ST_Collect(geom1, geom2) - Zbiera geometrie do kolekcji geometrii

UPDATE obiekty 
SET geom = ST_MakePolygon(ST_LineMerge(ST_CollectionHomogenize(ST_Collect(geom, 'LINESTRING(20.5 19.5, 20 20)'))))
WHERE nazwa = 'obiekt4';

-- 3. W tabeli obiekty, jako obiekt7 zapisz obiekt złożony z obiektu 3 i obiektu 4.
INSERT INTO obiekty VALUES (7, 'obiekt7', ST_Collect((SELECT geom 
						      FROM obiekty 
						      WHERE nazwa = 'obiekt3'), (SELECT geom 
										 FROM obiekty 
										 WHERE nazwa = 'obiekt4')));
SELECT *
FROM obiekty;

-- 4. Wyznacz pole powierzchni wszystkich buforów o wielkości 5 jednostek, które zostały utworzone wokół obiektów nie
-- zawierających łuków.
SELECT SUM(ST_Area(ST_Buffer(geom, 5))) 
FROM obiekty 
WHERE ST_HasArc(geom) = FALSE;
