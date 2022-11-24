import json

import redis
import uvicorn
from fastapi import FastAPI
import requests
from starlette.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware

from psycopg2 import pool

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/pg")
async def location_pg(veh_id='*'):
    """
    An API demo how to query latest position from postgres.
    :return:
    """
    cnxpool = pool.SimpleConnectionPool(
        1, 20, user="postgres-user",
        password="postgres-pw",
        host="postgres",
        port="5432",
        database="example-db")

    locations = []
    cnx = cnxpool.getconn()
    cursor = cnx.cursor()
    cursor.execute(
        f'select "VEH_ID", "LOCATION" from bus_current_sr;' if veh_id == '*' else
        f'select "VEH_ID", "LOCATION" from bus_current_sr where "VEH_ID"=\'{veh_id}\'')
    for (vid, loc) in cursor.fetchall():
        locations.append({
            'veh_id': vid,
            'loc': loc
        })
    cursor.close()
    cnxpool.putconn(cnx)

    return {
        'size': len(locations),
        'data': locations
    }


@app.get("/redis")
async def location_redis(veh_id='*'):
    """
    An API demo how to query latest position from redis.
    :return:
    """
    # https://docs.redis.com/latest/rs/references/client_references/client_python/
    r = redis.Redis(
        host='redis',
        port='6379',
        password='xxxxxxxx',
        db=1)

    # get data from redis
    keys = r.keys(veh_id)
    values = r.mget(keys)

    # current location data
    locations = [
        {
            'veh_id': keys[i].decode(),
            'loc': values[i].decode(),
        } for i in range(len(keys))]
    locations.sort(key=lambda x: x['veh_id'])

    return {
        'size': len(locations),
        'data': locations
    }


@app.get("/ksqldb")
async def location_ksqldb(server='ksqldb-server', veh_id='*'):
    """
    An API demo how to query latest position from ksqlDB directly.
    :return:
    """

    # send request to ksqldb using rest api
    # https://docs.ksqldb.io/en/latest/developer-guide/ksqldb-rest-api/query-endpoint/
    resp = requests.post(
        f'http://{server}:8088/query',
        headers={"Accept": "application/vnd.ksql.v1+json"},
        data=json.dumps(
            {
                'ksql':
                    f'select * from bus_current;' if veh_id == '*' else
                    f'select * from bus_current where veh_id=\'{veh_id}\';',
                'streamsProperties': {
                    # https://docs.ksqldb.io/en/latest/operate-and-deploy/high-availability-pull-queries/
                    # 'ksql.query.pull.max.allowed.offset.lag': '100'
                }
            })).json()

    locations = [
        {
            'veh_id': str(data['row']['columns'][0]),
            'loc': data['row']['columns'][1]
        } for data in resp[1:]]  # resp[1:] to skip headers
    locations.sort(key=lambda x: x['veh_id'])

    return {
        'size': len(locations),
        'data': locations
    }


@app.get("/ksqldb-push")
async def location_ksqldb_push(server='ksqldb-server', veh_id='*'):
    """
    An API demo how to push query position changes from ksqlDB directly.

    How to run push query against ksqldb server:
    https://docs.ksqldb.io/en/latest/developer-guide/ksqldb-rest-api/streaming-endpoint/

    curl -X "POST" "http://ksqldb-server:8088/query-stream" \
        -d $'{
      "sql": "SELECT * FROM bus_current EMIT CHANGES;",
      "streamsProperties": {}
    }'
    :return:
    """

    def get_streaming_data():
        nonlocal server, veh_id

        with requests.post(
                f'http://{server}:8088/query-stream',
                stream=True,
                data=json.dumps(
                    {
                        'sql':
                            f'select * from bus_current emit changes;' if veh_id == '*' else
                            f'select * from bus_current where veh_id = \'{veh_id}\' emit changes;',
                        'streamsProperties': {}
                    })) as r:
            for chunk in r.iter_content(chunk_size=1024 * 8):
                chunk = chunk.decode()
                if chunk.startswith('{'):
                    # header
                    # {"queryId":"xxxx",
                    # "columnNames":["VEH_ID","POSITION","TS"],
                    # "columnTypes":["INTEGER","STRING","BIGINT"]}
                    continue

                veh_id, loc = json.loads(chunk)
                yield f"{json.dumps({'veh_id': str(veh_id), 'loc': loc})}\n"

    return StreamingResponse(content=get_streaming_data())


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
