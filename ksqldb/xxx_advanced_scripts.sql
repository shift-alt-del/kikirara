
-- last stop
create table bus_last_stop with (kafka_topic='bus_last_stop', key_format='KAFKA', value_format='DELIMITED')
as select 
veh_id, 
latest_by_offset(stop) as stop_id
from BUS_EXTRACTED 
where stop <> 'null'
group by veh_id emit changes;


-- join last stop
-- stopA -> stopB, we know bus has left stopA aheading stopB, therefore the stopA->stopB is one segment,
-- if we know the avg speed so far and the remain geo distance, we know the estimation for arrival.
create table bus_segment_avg_speed with (kafka_topic='bus_segment_avg_speed', key_format='AVRO', value_format='AVRO')
as select
last_stop.stop_id as segment_id,
ext.veh_id as veh_id,
earliest_by_offset(time_int) as segment_start_time,
latest_by_offset(time_int) as segment_end_time,
latest_by_offset(time_int) - earliest_by_offset(time_int) as segment_time_spend,
avg(ext.speed) as avg_speed,
count(*) as data_count
from BUS_EXTRACTED ext 
left join bus_last_stop last_stop on ext.veh_id = last_stop.veh_id
window session (5 minutes, grace period 1 minutes)
where ext.speed is not null 
    and ext.speed <> 0.0
    and last_stop.stop_id is not null
group by last_stop.stop_id, ext.veh_id
emit final;


-- current segment speed
select 
segment_id, 
veh_id, 
collect_list(avg_speed),
collect_list(segment_end_time)
from BUS_SEGMENT_AVG_SPEED 
group by segment_id, veh_id 
emit changes;

-- avg speed per route
select 
windowstart,
windowend,
ROUTE_NUM, 
avg(speed),
count(*),
count_distinct(veh_id)
from BUS_EXTRACTED ext WINDOW TUMBLING (size 5 minutes, grace period 1 minutes)
group by route_num emit changes;