ruleset manage_fleet {
  meta {
    name "Manage Fleet"
    author "Megan Moreno"
    logging on
    use module Subscriptions
	shares vehicles
  }
  
  global {
    vehicles = function(obj) {
      ent:vehicles
    }

    all_trips = function(obj) {
		Subscriptions:getSubscriptions().filter(function(v){
                v{"attributes"}{"subscriber_role"} == "vehicle"
            }).map(function(s){
                query = http:get("http://localhost:8080/sky/cloud/" + s{"attributes"}{"subscriber_eci"} + "/trip_store/trips");
                query{"content"}.decode()
            })

    }
  }
  
rule create_vehicle {
    select when car new_vehicle
    pre {
	vehicle_id = event:attr("vehicle_id")
 	exists = ent:vehicles >< vehicle_id
  	eci = meta:eci
    }
    if exists then
	send_directive("vehicle_ready", {"vehicle_id":vehicle_id})
    fired {
    }else {
    	raise pico event "new_child_request"
      		attributes { "dname": "vehicle_" + vehicle_id, "color": "#FF69B4", "vehicle_id":vehicle_id }
    }
    }

    rule pico_child_initialized {
	select when pico child_initialized
	pre {
		vehicle = event:attr("new_child")
		vehicle_id = event:attr("rs_attrs"){"vehicle_id"}
		eci = meta:eci
	}
event:send({ "eci": vehicle.eci, "eid": "install-ruleset",
                "domain": "pico", "type": "new_ruleset",
                "attrs": { "rid": "track_tips", "vehicle_id": vehicle_id } } )
        

	fired {
    raise wrangler event "subscription" attributes
       { "name" : ent:vehicles{vehicle_id},
         "name_space" : "car",
         "my_role" : "fleet",
         "subscriber_role" :"vehicle",
         "channel_type" : "subscription",
         "subscriber_eci" : vehicle.eci
       };
		ent:vehicles := ent:vehicles.defaultsTo({});
        	ent:vehicles{vehicle_id} := vehicle
	}

          }
  


rule delete_car {
  select when car unneeded_vehicle
  pre {
    vehicle_id = event:attr("vehicle_id")
    exists = ent:vehicles >< vehicle_id
    eci = meta:eci
    child_to_delete = ent:vehicles{vehicle_id}
  }
  if exists then
    send_directive("car_deleted", {"vehicle_id":vehicle_id});
  fired {
    raise wrangler event "subscription_cancellation"
  	attributes {"subscription_name":"fleet:Vehicle" + vehicle_id + "Subscription"};
    raise pico event "delete_child_request"
      attributes child_to_delete;
    ent:vehicles{[vehicle_id]} := null
  }
}



}

