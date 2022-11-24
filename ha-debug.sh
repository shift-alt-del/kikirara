i=1
while [ "$i" -ne 0 ]
do
    echo "=== " ${i}

    for id in {1..1000};
    do
        echo "+++"
        echo "ksql1:" $(curl -sX GET "http://localhost:8000/ksqldb?server=ksqldb-server&veh_id=${id}")
        echo "ksql2:" $(curl -sX GET "http://localhost:8000/ksqldb?server=ksqldb-server2&veh_id=${id}")
        echo "redis:" $(curl -sX GET "http://localhost:8000/redis?veh_id=${id}")
        echo "pg   :" $(curl -sX GET "http://localhost:8000/pg?veh_id=${id}")
    done

    i=$(($i+1))
    sleep 3
done
