i=1
while [ "$i" -ne 0 ]
do
    echo "=== " ${i}
    echo "ksql1:" $(curl -sX GET "http://localhost:8000/ksqldb?server=ksqldb-server&veh_id=1365")
    echo "ksql2:" $(curl -sX GET "http://localhost:8000/ksqldb?server=ksqldb-server2&veh_id=1365")
    echo "redis:" $(curl -sX GET "http://localhost:8000/redis?veh_id=1365")
    i=$(($i+1))
    sleep 3
done
