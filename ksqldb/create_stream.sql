-- create a kafka stream to load data from topic as source
CREATE STREAM BUS_RAW_ALL(
  key STRING KEY,
  VP STRING)
WITH (KAFKA_TOPIC='bus_raw_all', FORMAT='KAFKA');

-- todo: why need this convert? from the raw data?
create stream bus_raw_demo with (kafka_topic='bus_raw_demo', KEY_FORMAT='KAFKA', VALUE_FORMAT='AVRO')
as select key, substring(vp, 6) as vp 
from bus_raw_all
where substring(key, len(key),1)='1' or substring(key, len(key),1)='2'
emit changes;

-- extract data from raw data
CREATE STREAM BUS_EXTRACTED WITH (KAFKA_TOPIC='bus_extracted', key_format='KAFKA', VALUE_FORMAT='AVRO', TIMESTAMP='TIME_INT') 
AS SELECT 
  SPLIT(AS_VALUE(KEY), '/')[12] AS HEADSIGN, 
  EXTRACTJSONFIELD(VP, '$.VP.desi') AS ROUTE_NUM, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.dir') AS INT) AS DIRECTION_ID, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.oper') AS INT) AS OPERATOR_ID, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.veh') AS INT) AS VEH_ID, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.tsi') AS BIGINT) AS TIME_INT, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.spd') AS DOUBLE) AS SPEED, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.hdg') AS INT) AS HEADING, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.lat') AS DOUBLE) AS LAT, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.long') AS DOUBLE) AS LONG, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.acc') AS DOUBLE) AS ACCEL, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.dl') AS INT) AS DEVIATION, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.odo') AS INT) AS ODOMETER, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.drst') AS INT) AS DOOR_STATUS, 
  EXTRACTJSONFIELD(VP, '$.VP.start') AS START_TIME, 
  EXTRACTJSONFIELD(VP, '$.VP.stop') AS STOP, 
  EXTRACTJSONFIELD(VP, '$.VP.loc') AS LOC_SRC, 
  CAST(EXTRACTJSONFIELD(VP, '$.VP.occu') AS INT) AS OCCUPANCY 
FROM bus_raw_demo 
PARTITION BY CAST(EXTRACTJSONFIELD(VP, '$.VP.veh') AS INT) 
EMIT CHANGES;