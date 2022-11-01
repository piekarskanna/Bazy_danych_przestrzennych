-- Database: cw3

-- DROP DATABASE IF EXISTS cw3;

CREATE DATABASE cw3
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Polish_Poland.1250'
    LC_CTYPE = 'Polish_Poland.1250'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;
	
CREATE EXTENSION postgis; 

-- 1. Znajdź budynki, które zostały wybudowane lub wyremontowane na przestrzeni roku (zmiana
--    pomiędzy 2018 a 2019).
--    ST_Equals(geom1,geom2) = T/F		- zwraca T, jeśli geometrie są „przestrzennie równe”.

SELECT *
FROM T2018_KAR_POI_TABLE;

SELECT *
FROM T2019_KAR_BUILDINGS;

CREATE TABLE Buildings AS (
SELECT T2019.*
FROM T2019_KAR_BUILDINGS AS T2019, 
	 T2018_KAR_BUILDINGS AS T2018
WHERE ST_Equals(T2019.geom, T2018.geom) = FALSE AND 
	  T2019.polygon_id = T2018.polygon_id);

SELECT *
FROM Buildings;

-- 2. Znajdź ile nowych POI pojawiło się w promieniu 500 m od wyremontowanych lub
--    wybudowanych budynków, które znalezione zostały w zadaniu 1. Policz je wg ich kategorii.
-- ST_DWithin - Zwraca prawdę, jeśli geometrie znajdują się w określonej odległości

SELECT COUNT(*), T2019_P.type
FROM T2018_KAR_POI_TABLE AS T2018_P,
	 T2019_KAR_POI_TABLE AS T2019_P
WHERE ST_Contains((SELECT T2019_P.geom
				   FROM T2018_KAR_POI_TABLE AS T2018_P,
	 					T2019_KAR_POI_TABLE AS T2019_P
				   WHERE ST_Equals(T2019_P.geom, T2019_P.geom) = FALSE AND T2018_P.poi_id = T2019_P.poi_id), ST_Buffer((SELECT T2019_B.geom
				   																	   									FROM T2019_KAR_BUILDINGS AS T2019_B, 
	 	   																							 						 T2018_KAR_BUILDINGS AS T2018_B
	 																													WHERE ST_Equals(T2019_B.geom, T2018_B.geom) = FALSE AND T2019_B.polygon_id = T2018_B.polygon_id), 500))
GROUP BY T2019_P.type;
	 
-- 3. Utwórz nową tabelę o nazwie ‘streets_reprojected’, która zawierać będzie dane z tabeli
--    T2019_KAR_STREETS przetransformowane do układu współrzędnych DHDN.Berlin/Cassini.

CREATE TABLE streets_reprojected AS (
SELECT gid, link_id, st_name, ref_in_id, nref_in_id, func_class, speed_cat, fr_speed_l, to_speed_l, dir_travel, 
	   ST_Transform(geom, 3068) as geom
FROM T2019_KAR_STREETS);

SELECT * 
FROM streets_reprojected;

DROP TABLE streets_reprojected;

-- 4.  Stwórz tabelę o nazwie ‘input_points’ i dodaj do niej dwa rekordy o geometrii punktowej.
--     Użyj następujących współrzędnych:
--     X       Y
--     8.36093 49.03174
--     8.39876 49.00644
--     Przyjmij układ współrzędnych GPS.

CREATE TABLE input_points (id INT PRIMARY KEY,
						   geom GEOMETRY); 

INSERT INTO input_points
VALUES (1, ST_GeomFromText('POINT(8.36093 49.03174)', 4326)),
	   (2, ST_GeomFromText('POINT(8.39876 49.00644)', 4326));
	
SELECT *, ST_AsText(geom) 
FROM input_points;

DROP TABLE input_points;

-- 5. Zaktualizuj dane w tabeli ‘input_points’ tak, aby punkty te były w układzie współrzędnych
--    DHDN.Berlin/Cassini. Wyświetl współrzędne za pomocą funkcji ST_AsText()

UPDATE input_points
SET geom = ST_Transform(input_points.geom,3068);

SELECT *, ST_AsText(geom) AS geom_point 
FROM input_points;

-- 6.  Znajdź wszystkie skrzyżowania, które znajdują się w odległości 200 m od linii zbudowanej
--     z punktów w tabeli ‘input_points’. Wykorzystaj tabelę T2019_STREET_NODE. Dokonaj
--     reprojekcji geometrii, aby była zgodna z resztą tabel.

-- ST_Contains() - Zwraca TRUE, jeśli geometria B jest całkowicie wewnątrz geometrii A
-- ST_Within()

SELECT * 
FROM t2019_kar_street_node
WHERE ST_Within(ST_Transform(t2019_kar_street_node.geom, 3068), 
                ST_Buffer(ST_ShortestLine((SELECT geom 
										   FROM input_points 
										   WHERE id = 1),
                                          (SELECT geom 
										   FROM input_points 
										   WHERE id = 2)), 200));

-- 7. Policz jak wiele sklepów sportowych (‘Sporting Goods Store’ - tabela POIs) znajduje się
--    w odległości 300 m od parków (LAND_USE_A).

SELECT COUNT( DISTINCT(T2019_POI.geom))
FROM t2019_kar_poi_table as T2019_POI, 
	 t2019_kar_land_use_a as T2019_LAND
WHERE T2019_POI.type = 'Sporting Goods Store' AND
	  ST_DWithin(T2019_POI.geom, T2019_LAND.geom, 300) AND
	  T2019_LAND.type = 'Park (City/County)';

-- 8. Znajdź punkty przecięcia torów kolejowych (RAILWAYS) z ciekami (WATER_LINES). Zapisz
--    znalezioną geometrię do osobnej tabeli o nazwie ‘T2019_KAR_BRIDGES’
-- SELECT DISTINCT - usuwa zduplikowane wiersze (jeden zostawia, a ten ktory sie powtarza jest usuwany)
-- ST_Intersection(geom1, geom2) - zwraca geometrie reprezentującą punkt przecięcia dwóch geometrii.

CREATE TABLE T2019_KAR_BRIDGES AS (
SELECT DISTINCT(ST_Intersection(railways.geom, water_lines.geom))
FROM T2019_KAR_RAILWAYS AS railways,
	 T2019_KAR_WATER_LINES AS water_lines);

SELECT * 
FROM T2019_KAR_BRIDGES;
		       					 
DROP TABLE T2019_KAR_BRIDGES;

