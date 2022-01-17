cat database.json | jq '[ .sites[].revisions[].timestamp | split("T") ] | group_by(.[0]) | [ .[] | {(.[0][0]): ([ .[
][1] ] | max) } ] | add'
