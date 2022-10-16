-- Database: cw1

-- DROP DATABASE IF EXISTS cw1;

CREATE DATABASE cw1
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Polish_Poland.1250'
    LC_CTYPE = 'Polish_Poland.1250'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;
	
CREATE EXTENSION postgis; -- wyposażenie bazy w funkcje i rozwszezenia postgisa

-- WKT - sposób definicji danych w formie tekstowej 
-- ST_AsText(nazwa) - konwertuje WKB na WKT

-- WKB - sposób definicji danych w formie binarnej
-- POLIGONY ST_GeomFromText('POLYGON((x1 y1, y2 y2, ... , xn yn, x1 y1)',0')) -- 0 jest ukladem niezdefiniowanym
-- LINIE ST_GeomFromText('LINESTRING(x1 y2, x2 y2)', 0))
-- PUNKTY ST_GeomFromText('POINT(X Y)',0)

CREATE TABLE buildings (id INT PRIMARY KEY NOT NULL, name VARCHAR(50), height INTEGER, geom GEOMETRY );

INSERT INTO buildings VALUES (1, 'BuildingA', 10, ST_GeomFromText('POLYGON((8 1.5, 10.5 1.5, 10.5 4, 8 4, 8 1.5))',0));
INSERT INTO buildings VALUES (2, 'BuildingB', 10, ST_GeomFromText('POLYGON((4 5,6 5, 6 7, 4 7, 4 5))',0));
INSERT INTO buildings VALUES (3, 'BuildingC', 10, ST_GeomFromText('POLYGON((3 6, 5 6, 5 8, 3 8, 3 6))',0));
INSERT INTO buildings VALUES (4, 'BuildingD', 10, ST_GeomFromText('POLYGON((9 8, 10 8, 10 9, 9 9, 9 8))',0));
INSERT INTO buildings VALUES (5, 'BuildingF', 10, ST_GeomFromText('POLYGON((1 1, 2 1, 2 2, 1 2, 1 1))',0));

SELECT *, ST_AsText(geom) AS WKT
FROM buildings;

CREATE TABLE roads (id INT PRIMARY KEY NOT NULL, name VARCHAR(50), geom GEOMETRY);

INSERT INTO roads VALUES (1, 'RoadX', ST_GeomFromText('LINESTRING(0 4.5, 12 4.5)', 0));
INSERT INTO roads VALUES (2, 'RoadY', ST_GeomFromText('LINESTRING(7.5 0, 7.5 10.5)', 0));

SELECT *, ST_AsText(geom) AS WKT
FROM roads;

CREATE TABLE points (id INT PRIMARY KEY NOT NULL, name VARCHAR(50), number INTEGER, geom GEOMETRY);

INSERT INTO points VALUES (1, 'G', 10, ST_GeomFromText('POINT(1 3.5)',0));
INSERT INTO points VALUES (2, 'H', 10, ST_GeomFromText('POINT(5.5 1.5)',0));
INSERT INTO points VALUES (3, 'I', 10, ST_GeomFromText('POINT(9.5 6)',0));
INSERT INTO points VALUES (4, 'J', 10, ST_GeomFromText('POINT(6.5 6)',0));
INSERT INTO points VALUES (5, 'K', 10, ST_GeomFromText('POINT(6 9.5)',0));

SELECT *, ST_AsText(geom) AS WKT
FROM points;

-- 1. Wyznacz całkowitą długość dróg w analizowanym mieście. 
	--ST_LENGTH(geom)) - funkcja zwraca dlugość linii, argumentem jest geometria
	
SELECT SUM(ST_LENGTH(geom)) AS total_length
FROM roads;

-- 2. Wypisz geometrię (WKT), pole powierzchni oraz obwód poligonu reprezentującego BuildingA. 
SELECT name, ST_AsText(geom) AS WKT, ST_AREA(geom) AS area, ST_PERIMETER(geom) AS perimeter
FROM buildings
WHERE name LIKE '%A';

-- 3. Wypisz nazwy i pola powierzchni wszystkich poligonów w warstwie budynki. Wyniki posortuj alfabetycznie. 
SELECT name, ST_AREA(geom) AS area
FROM buildings
ORDER BY name;

-- 4. Wypisz nazwy i obwody 2 budynków o największej powierzchni. 
SELECT name, ST_PERIMETER(geom) AS perimeter
FROM buildings
ORDER BY ST_AREA(geom) DESC
LIMIT 2;

-- 5. Wyznacz najkrótszą odległość między budynkiem BuildingC a punktem G. 
SELECT ST_Distance(buildings.geom, points.geom) AS shortest_distance -- ST_Length(ST_ShortestLine(buildings.geom, points.geom)) AS shortest_distance
FROM buildings, points 
WHERE buildings.name='BuildingC' AND points.name='G';

-- 6. Wypisz pole powierzchni tej części budynku BuildingC, która znajduje się w odległości większej niż 0.5 od budynku BuildingB.
	-- ST_Difference(geom_a, geom_b) - zwraca geomeometrie części geom_a, która nie przecina geom_b

SELECT ST_Area(ST_Difference((SELECT geom
							  FROM buildings 
							  WHERE name = 'BuildingC'), ST_Buffer((SELECT geom
																	FROM buildings 
																	WHERE name = 'BuildingB'), 0.5))) AS area;
		

-- 7. Wybierz te budynki, których centroid (ST_Centroid) znajduje się powyżej drogi RoadX.
	-- ST_Centroid(geom) - zwraca obiekt ST_Point() będący geometrycznym środkiem masy geometrii
	-- ST_Y(geom) - zwraca współrzędną Y punktu lub wartość NULL, jeśli jest niedostępna. Dane wejściowe muszą być punktem.;
	
SELECT buildings.name
FROM buildings, roads
WHERE roads.name = 'RoadX' AND ST_Y(ST_Centroid(buildings.geom)) > ST_Y(ST_Centroid(roads.geom));


-- 8. Oblicz pole powierzchni tych części budynku BuildingC i poligonu o współrzędnych (4 7, 6 7, 6 8, 4 8, 4 7), które nie są wspólne dla tych dwóch obiektów.
	-- ST_SymDifference(geom a, geom b) - zwraca geometrię reprezentującą części sieci geograficznych A i B, które się nie przecinają -różnicą symetryczną,

SELECT ST_Area(ST_SymDifference(geom, ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))')))
	FROM buildings
	WHERE name = 'BuildingC';

-- ST_Contains(geom1, geom2) --> TRUE/FALSE - funkcja testuje czy geom1 zawiera geom2 

