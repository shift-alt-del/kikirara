import json

import redis
import uvicorn
from fastapi import FastAPI
import requests

app = FastAPI()


@app.get("/curr")
async def curr():
    """
    An API demo how to query latest position from redis.
    :return:
    """
    # https://docs.redis.com/latest/rs/references/client_references/client_python/
    r = redis.Redis(
        host='localhost',
        port='6379',
        password='xxxxxxxx',
        db=1)

    keys = r.keys('*')
    values = r.mget(keys)

    positions = []
    for i in range(len(keys)):

        key = keys[i].decode()
        value = values[i].decode()

        # todo: why we got topic names here?
        if not key.isnumeric():
            continue

        lat, long, ts = value.replace('\"', '').split(',')
        positions.append({
            'veh_id': key,
            'lat': float(lat),
            'long': float(long),
            'ts': int(ts),
        })

    positions.sort(key=lambda x: x['ts'], reverse=True)
    return {
        'size': len(positions),
        'data': positions
    }


@app.get("/curr2")
async def curr2():
    """
    An API demo how to query latest position from ksqlDB directly.
    :return:
    """

    # send request to ksqldb using rest api
    # https://docs.ksqldb.io/en/latest/developer-guide/ksqldb-rest-api/query-endpoint/
    headers = {"Accept": "application/vnd.ksql.v1+json"}
    resp = requests.post(
        'http://ksqldb-server:8088/query',
        headers=headers,
        data=json.dumps({
            'ksql': 'select * from bus_current;',
            'streamsProperties': {}
        })).json()

    positions = []
    # the first row is header.
    for data in resp[1:]:
        veh_id, pos_lat_long, ts = data['row']['columns']
        lat, long = pos_lat_long.replace('\"', '').split(',')
        positions.append({
            'veh_id': veh_id,
            'lat': float(lat),
            'long': float(long),
            'ts': int(ts),
        })

    positions.sort(key=lambda x: x['ts'], reverse=True)
    return {
        'size': len(positions),
        'data': positions
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
