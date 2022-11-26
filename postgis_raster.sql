-- Database: postgis_raster

-- DROP DATABASE IF EXISTS postgis_raster;

CREATE DATABASE postgis_raster
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Polish_Poland.1250'
    LC_CTYPE = 'Polish_Poland.1250'
    TABLESPACE = pg_default 
    CONNECTION LIMIT = -1;

-- Tworzenie rastrów z istniejących rastrów i interakcja z wektorami
-- Przykład 1 - ST_Intersects (Przecięcie rastra z wektorem.)
CREATE TABLE schema_piekarska.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

-- W przypadku tworzenia tabel zawierających dane rastrowe sugeruje się wykonanie poniższych kroków:
-- 1. dodanie serial primary key:
ALTER TABLE schema_piekarska.intersects
ADD COLUMN rid SERIAL PRIMARY KEY;

--2. utworzenie indeksu przestrzennego:
CREATE INDEX idx_intersects_rast_gist ON schema_piekarska.intersects
USING gist (ST_ConvexHull(rast));

--3. dodanie raster constraints:
-- schema::name table_name::name raster_column::name
SELECT AddRasterConstraints('schema_piekarska'::name,
'intersects'::name,'rast'::name);


-- Przykład 2 - ST_Clip
-- Obcinanie rastra na podstawie wektora
CREATE TABLE schema_piekarska.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';


--Przykład 3 - ST_Union
-- Połączenie wielu kafelków w jeden raster.
CREATE TABLE schema_piekarska.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);

---------------------------------------------------------------------------------------

-- Tworzenie rastrów z wektorów (rastrowanie) - przykłady pokazują rastrowanie wektoru.
-- Przykład 1 - ST_AsRaster
-- ST_AsRaster - rastrowanie tabeli z parafiami o takiej samej charakterystyce przestrzennej tj.: wielkość piksela, zakresy itp.
CREATE TABLE schema_piekarska.porto_parishes AS WITH r AS (SELECT rast 
		   											  FROM rasters.dem
		                							  LIMIT 1 )
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--Przykład 2 - ST_Union
-- ST_UNION - łączy rekordy z poprzedniego przykładu w pojedynczy raster
DROP TABLE schema_piekarska.porto_parishes; --> drop table porto_parishes first

CREATE TABLE schema_piekarska.porto_parishes AS
WITH r AS (SELECT rast 
		   FROM rasters.dem
		   LIMIT 1)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

-- Przykład 3 - ST_Tile
-- ST_Tile - generowanie kafelek po uzyskaniu pojedynczego rastra
DROP TABLE schema_piekarska.porto_parishes; --> drop table porto_parishes first
CREATE TABLE schema_piekarska.porto_parishes AS
WITH r AS (SELECT rast 
		   FROM rasters.dem
		   LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-
32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

----------------------------------------------------------------------------------------

-- Konwertowanie rastrów na wektory (wektoryzowanie)
-- Przykład 1 - ST_Intersection 
-- ST_Intersection - zwraca zestaw par wartości geometria piksel (a przekształca raster w wektor przed rzeczywistym „klipem”.),
-- podoba do ST_Clip (zwraca raster)
CREATE TABLE schema_piekarska.intersection as
SELECT a.rid,(ST_Intersection(b.geom,a.rast)).geom, (ST_Intersection(b.geom,a.rast)).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

-- Przykład 2 - ST_DumpAsPolygons
-- ST_DumpAsPolygons - konwertuje rastry w wektory (poligony).

CREATE TABLE schema_piekarska.dumppolygons AS
SELECT a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

---------------------------------------------------------------------------------------------

-- Analiza rastrów
-- Przykład 1 - ST_Band
-- ST_Band - wyodrębnianie pasm z rastra
CREATE TABLE schema_piekarska.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

--Przykład 2 - ST_Clip
-- ST_Clip - wycięcie rastra z innego rastra. 
CREATE TABLE schema_piekarska.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

-- Przykład 3 - ST_Slope
-- ST_Slope - generowanie nachylenia przy użyciu poprzednio wygenerowanej tabeli (wzniesienie).
CREATE TABLE schema_piekarska.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM schema_piekarska.paranhos_dem AS a;

-- Przykład 4 - ST_Reclass
-- ST_Reclass - zreklasyfikowanie rastra 
CREATE TABLE schema_piekarska.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3','32BF',0)
FROM schema_piekarska.paranhos_slope AS a;

--Przykład 5 - ST_SummaryStats
-- ST_SummaryStat - generowanie statystyk dla kafelka. 
SELECT st_summarystats(a.rast) AS stats
FROM schema_piekarska.paranhos_dem AS a;

-- Przykład 6 - ST_SummaryStats oraz Union
-- UNION - wygenerowanie jednej statystyki wybranego rastra.
SELECT st_summarystats(ST_Union(a.rast))
FROM schema_piekarska.paranhos_dem AS a;

-- Przykład 7 - ST_SummaryStats z lepszą kontrolą złożonego typu danych
WITH t AS (SELECT st_summarystats(ST_Union(a.rast)) AS stats
		   FROM schema_piekarska.paranhos_dem AS a)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

-- Przykład 8 - ST_SummaryStats w połączeniu z GROUP BY
-- GROUP BY - wyświetlenie statystyki dla każdego poligonu "parish"
WITH t AS (SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast, b.geom,true))) AS stats
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
GROUP BY b.parish)
SELECT parish,(stats).min,(stats).max,(stats).mean 
FROM t;

-- Przykład 9 - ST_Value 
-- ST_Value - pozwala wyodrębnić wartość piksela z punktu lub zestawu punktów
-- (ST_Dump(b.geom)).geom - przekonwertowanie geometrii wielopunktowej na geometrię jednopunktową
SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;

-- Przykład 10 - ST_TPI
-- ST_Value pozwala na utworzenie mapy TPI z DEM wysokości
CREATE TABLE schema_piekarska.tpi30 as
SELECT ST_TPI(a.rast,1) as rast
FROM rasters.dem a;

SELECT *
FROM schema_piekarska.tpi30

-- Poniższa kwerenda utworzy indeks przestrzenny:
CREATE INDEX idx_tpi30_rast_gist 
ON schema_piekarska.tpi30
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('schema_piekarska'::name,
'tpi30'::name,'rast'::name);

-------------------------------------------------------------------------------------

-- 10.	Problem do samodzielnego rozwiązania 
-- ograniczenie obszaru zainteresowania i obliczenie mniejszego regionu.
-- zapytanie z przykładu 10 (tylko gmina Porto)
-- ILIKE - nie uwzględnia wielkości liter
CREATE TABLE schema_piekarska.tpi30_porto AS
SELECT ST_TPI(a.rast,1) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b 
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ILIKE 'porto';

-- Utworzenie indeksu przestrzennego:
CREATE INDEX idx_tpi30_porto_rast_gist 
ON schema_piekarska.tpi30_porto
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('schema_piekarska'::name, 
'tpi30_porto'::name,'rast'::name);

SELECT *
FROM schema_piekarska.tpi30_porto
DROP TABLE schema_piekarska.tpi30_porto;

--------------------------------------------------------------------

-- Algebra mapy 
-- Przykład 1 - Wyrażenie Algebry Map
CREATE TABLE schema_piekarska.porto_ndvi AS
WITH r AS (SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
		   FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
		   WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast))
SELECT
r.rid,ST_MapAlgebra(
r.rast, 1,
r.rast, 4,
'([rast2.val] - [rast1.val]) / ([rast2.val] +
[rast1.val])::float','32BF'
) AS rast
FROM r;

-- utworzenie indeksu przestrzennego
CREATE INDEX idx_porto_ndvi_rast_gist ON schema_piekarska.porto_ndvi
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('schema_piekarska'::name,
'porto_ndvi'::name,'rast'::name);


-- Przykład 2 – Funkcja zwrotna
-- funkcja, która będzie wywołana później:
CREATE OR REPLACE FUNCTION schema_piekarska.ndvi(
value double precision [] [] [],
pos integer [][],
VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debug purposes
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value
[1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;

-- W kwerendzie algebry map należy wywołać zdefiniowaną wcześniej funkcję:
CREATE TABLE schema_piekarska.porto_ndvi2 AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, ARRAY[1,4],
'schema_piekarska.ndvi(double precision[],
integer[],text[])'::regprocedure, --> This is the function!
'32BF'::text
) AS rast
FROM r;

-- Dodanie indeksu przestrzennego:
CREATE INDEX idx_porto_ndvi2_rast_gist ON schema_piekarska.porto_ndvi2
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('schema_piekarska'::name,
'porto_ndvi2'::name,'rast'::name);

-----------------------------------------------------------------------------

-- Eksport danych 
--Przykład 1 - ST_AsTiff
-- ST_AsTiff - tworzy dane wyjściowe jako binarną reprezentację pliku tiff
SELECT ST_AsTiff(ST_Union(rast))
FROM schema_piekarska.porto_ndvi;

-- Przykład 2 - ST_AsGDALRaster
-- ST_AsGDALRaster - dane wyjściowe są reprezentacją binarną dowolnego formatu GDAL.
SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
FROM schema_piekarska.porto_ndvi;

-- lista formatów obsługiwanych przez bibliotekę 
SELECT ST_GDALDrivers();

-- Przykład 3 - Zapisywanie danych na dysku za pomocą dużego obiektu (large object, lo)
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
) AS loid
FROM schema_piekarska.porto_ndvi;
----------------------------------------------
SELECT lo_export(loid, 'G:\myraster.tiff') --> Save the file in a place where the user postgres have access. In windows a flash drive usualy works fine.
FROM tmp_out;
----------------------------------------------
SELECT lo_unlink(loid)
FROM tmp_out; --> Delete the large object.





