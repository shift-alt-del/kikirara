-- latest position for each veh_id
-- redis sink connector only supports bytes and string, let's use string here to make things simple. 
create table bus_current with (kafka_topic='bus_current', key_format='delimited', value_format='delimited')
as select 
veh_id, 
latest_by_offset(
    concat(cast(lat as string), '|', cast(long as string), '|', cast(time_int as string))) as location
from bus_extracted
where lat is not null 
    and long is not null 
    and time_int is not null
group by veh_id
emit changes;


-- latest position for each veh_id
-- redis sink connector only supports bytes and string, let's use string here to make things simple. 
create table bus_current_sr with (kafka_topic='bus_current_sr', key_format='delimited', value_format='avro')
as select 
veh_id, 
latest_by_offset(
    concat(cast(lat as string), '|', cast(long as string), '|', cast(time_int as string))) as location
from bus_extracted
where lat is not null 
    and long is not null 
    and time_int is not null
group by veh_id
emit changes;