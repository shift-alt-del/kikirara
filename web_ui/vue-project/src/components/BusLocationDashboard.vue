<script>
export default {
  data() {
    return {
      busLocations: {},
    };
  },
  methods: {
    getRealtimeLocations: function (locations) {
      const decoder = new TextDecoder();

      fetch("http://localhost:8000/ksqldb-push")
        .then((response) => response.body.getReader())
        .then((reader) => {
          function readChunk({ done, value }) {
            if (done) {
              return;
            }

            // {"veh_id": "1377", "loc": "60.278461|25.021287|1669603746"}
            var decoded = decoder.decode(value);
            var splited = decoded.split("\n");
            for (var i = 0; i < splited.length; i++) {
              try {
                var locationData = JSON.parse(splited[i]);
                // console.log(locationData);
                locations[locationData.veh_id] = locationData;
              } catch (e) {
                // something went wrong.
                console.log(e);
              }
            }
            reader.read().then(readChunk);
          }
          reader.read().then(readChunk);
        });
    },
  },
};
</script>

<template>
  <div class="greetings">
    <h3>
      <button v-on:click="getRealtimeLocations(busLocations)">
        Get Realtime Locations
      </button>
    </h3>

    <ul>
      <li v-bind:key="bl.veh_id" v-for="bl in busLocations">
        id: {{ bl.veh_id }}, location: {{ bl.loc }}
      </li>
    </ul>
  </div>
</template>
