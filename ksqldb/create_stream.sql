-- create a kafka stream to load data from topic as source.
create stream bus_raw_bytes(
  key string key,
  payload bytes)
with (kafka_topic='bus_raw', key_format='kafka', value_format='avro', wrap_single_value='false');

-- let's draw 10% data for demo use, convert raw bytes to string.
create stream bus_converted with (kafka_topic='bus_converted')
as select 
key, 
from_bytes(payload, 'ascii') as payload 
from bus_raw_bytes
where random() >= 0.9
emit changes;

-- extract data from string.
create stream bus_extracted with (kafka_topic='bus_extracted') 
as select 
  split(as_value(key), '/')[12] as headsign, 
  extractjsonfield(payload, '$.VP.desi') as route_num, 
  cast(extractjsonfield(payload, '$.VP.dir') as int) as direction_id, 
  cast(extractjsonfield(payload, '$.VP.oper') as int) as operator_id, 
  cast(extractjsonfield(payload, '$.VP.veh') as string) as veh_id, 
  cast(extractjsonfield(payload, '$.VP.tsi') as bigint) as time_int, 
  cast(extractjsonfield(payload, '$.VP.spd') as double) as speed, 
  cast(extractjsonfield(payload, '$.VP.hdg') as int) as heading, 
  cast(extractjsonfield(payload, '$.VP.lat') as double) as lat, 
  cast(extractjsonfield(payload, '$.VP.long') as double) as long, 
  cast(extractjsonfield(payload, '$.VP.acc') as double) as accel, 
  cast(extractjsonfield(payload, '$.VP.dl') as int) as deviation, 
  cast(extractjsonfield(payload, '$.VP.odo') as int) as odometer, 
  cast(extractjsonfield(payload, '$.VP.drst') as int) as door_status, 
  extractjsonfield(payload, '$.VP.start') as start_time, 
  extractjsonfield(payload, '$.VP.stop') as stop, 
  extractjsonfield(payload, '$.VP.loc') as loc_src, 
  cast(extractjsonfield(payload, '$.VP.occu') as int) as occupancy 
from bus_converted 
partition by cast(extractjsonfield(payload, '$.VP.veh') as string) 
emit changes;