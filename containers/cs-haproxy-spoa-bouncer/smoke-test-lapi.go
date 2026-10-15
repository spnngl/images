// A fake CrowdSec Local API, for the server test of the Containerfile:
// the decisions stream bans 192.0.2.1 at the bouncer's first pull
// (startup=true), and has nothing new after.
package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("GET /v1/decisions/stream", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		decisions := `{"new":[],"deleted":[]}`
		if r.URL.Query().Get("startup") == "true" {
			decisions = `{"new":[{"duration":"1h","origin":"cscli","scenario":"smoke-test","scope":"Ip","type":"ban","value":"192.0.2.1"}],"deleted":[]}`
		}
		if _, err := w.Write([]byte(decisions)); err != nil {
			log.Print(err)
		}
	})
	log.Fatal(http.ListenAndServe("127.0.0.1:8080", nil))
}
