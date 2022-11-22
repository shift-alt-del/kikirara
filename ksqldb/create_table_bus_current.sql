-- latest position for each veh_id
-- todo: unknown bytes from redis, try to use another value format??? 
create table bus_current with (kafka_topic='bus_current', key_format='DELIMITED', value_format='DELIMITED')
as select 
veh_id, 
latest_by_offset(concat(cast(lat as string), ',', cast(long as string))) as position,
latest_by_offset(TIME_INT) as ts
from BUS_EXTRACTED
group by veh_id
emit changes;