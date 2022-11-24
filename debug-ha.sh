i=1
while [ "$i" -ne 0 ]
do
    echo "=== " ${i}
    echo "ksql1:" $(curl -sX GET "http://localhost:8000/ksqldb?server=ksqldb-server&veh_id=998")
    echo "ksql2:" $(curl -sX GET "http://localhost:8000/ksqldb?server=ksqldb-server2&veh_id=998")
    echo "redis:" $(curl -sX GET "http://localhost:8000/redis?veh_id=998")
    echo "pg   :" $(curl -sX GET "http://localhost:8000/pg?veh_id=998")
    i=$(($i+1))
    sleep 3
done
