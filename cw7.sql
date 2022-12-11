CREATE EXTENSION postgis;
CREATE EXTENSION postgis_raster;

-- 1. Pobierz dane o nazwie 1:250 000 Scale Colour Raster™ Free OS OpenData ze strony: 
-- https://osdatahub.os.uk/downloads/open

-- 2. Załaduj te dane do tabeli o nazwie uk_250k
SELECT * 
FROM uk_250k;

-- a. Dodanie serial primary key
ALTER TABLE uk_250k
ADD COLUMN rid SERIAL PRIMARY KEY;

-- b. Utworzenie indeksu przestrzennego
CREATE INDEX idx_uk_250k ON uk_250k
USING gist (ST_ConvexHull(rast));

-- c. Dodanie raster constraints
SELECT AddRasterConstraints('uk_250k'::name,'rast'::name);

-- 3. Połącz te dane (wszystkie kafle) w mozaikę, a następnie wyeksportuj jako GeoTIFF. 
CREATE TABLE uk_250k_mosaic AS
SELECT ST_Union(r.rast)
FROM uk_250k AS r

-- wyeksportuj jako GeoTIFF
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
       ST_AsGDALRaster(ST_Union(rast), 'GTiff',  ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
        ) AS loid
FROM uk_250k_mosaic;

-- Zapisanie pliku
SELECT lo_export(loid, 'C:/Users/Anna/Desktop/Studia/s5/BDP/cw/cw7/uk_250k_mosaic.tif')
FROM tmp_out;

-- Usuwanie obiektu
SELECT lo_unlink(loid)
FROM tmp_out;

DROP TABLE tmp_out;

-- 5. Załaduj do bazy danych tabelę reprezentującą granice parków narodowych. 
SELECT * 
FROM national_parks;

-- 6. Utwórz nową tabelę o nazwie uk_lake_district, do której zaimportujesz mapy rastrowe z punktu 1., 
-- które zostaną przycięte do granic parku narodowego Lake District. 
CREATE TABLE lake_district AS
SELECT r.rid, ST_Clip(r.rast, u.geom, true) AS rast, u.id
FROM uk_250k AS r, national_parks AS u
WHERE ST_Intersects(r.rast, u.geom) AND u.id = 1;

SELECT UpdateRasterSRID('lake_district','rast',27700);

DROP TABLE lake_district;

-- 7. Wyeksportuj wyniki do pliku GeoTIFF.

CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
       ST_AsGDALRaster(ST_Union(rast), 'GTiff',  ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
        ) AS loid
FROM lake_district;

-- Zapisywanie pliku
SELECT lo_export(loid, 'C:/Users/Anna/Desktop/Studia/s5/BDP/cw/cw7/lake_district.tif')
FROM tmp_out;

-- Usuwanie obiektu
SELECT lo_unlink(loid)
FROM tmp_out;

DROP TABLE tmp_out;

-- 8. Pobierz dane z satelity Sentinel-2 wykorzystując portal: https://scihub.copernicus.eu. 
-- Wybierz dowolne zobrazowanie, które pokryje teren parku Lake District oraz gdzie parametr cloud coverage będzie poniżej 20%. 
-- 9. Załaduj dane z Sentinela-2 do bazy danych. (raster2pgsql)
SELECT *
FROM uk_sentinel;

DROP TABLE uk_sentinel;

-- przygotowanie danych 
-- a. Dodanie serial primary key
ALTER TABLE uk_sentinel
ADD COLUMN rid SERIAL PRIMARY KEY;

-- b. Utworzenie indeksu przestrzennego
CREATE INDEX idx_uk_sentinel ON uk_sentinel
USING gist (ST_ConvexHull(rast));

-- c. Dodanie raster constraints

SELECT AddRasterConstraints('uk_sentinel'::name,'rast'::name);

-- połączenie w mozaikę

CREATE TABLE uk_sentinel_mosaic AS
SELECT ST_Union(r.rast)
FROM uk_sentinel AS r;

-- Obcinanie rastra na podstawie wektora.
CREATE TABLE uk_sentinel_clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM  uk_sentinel_mosaic AS a, uk_lake_districts AS b;

-- 10. Policz indeks NDWI oraz przytnij wyniki do granic Lake District.
SELECT * 
FROM NDWI;

CREATE TABLE NDWI AS
WITH r AS (
	SELECT r.rid, r.rast AS rast
	FROM uk_sentinel_clip AS r
)
SELECT
	r.rid, ST_MapAlgebra(
		r.rast, 1,
		r.rast, 4,
		'([rast2.val] - [rast1.val]) / ([rast2.val] + [rast1.val])::float','32BF'
	) AS rast
FROM r;

DROP TABLE NDWI;

-- 11. Wyeksportuj obliczony i przycięty wskaźnik NDWI do GeoTIFF
CREATE TABLE tmp_out2 AS
SELECT lo_from_bytea(0,
       ST_AsGDALRaster(ST_Union(rast), 'GTiff',  ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
        ) AS loid
FROM NDWI;

-- Zapisywanie pliku na dysku 

SELECT lo_export(loid, 'C:/Users/Anna/Desktop/Studia/s5/BDP/cw/cw7/NDWI.tif')
FROM tmp_out2;


