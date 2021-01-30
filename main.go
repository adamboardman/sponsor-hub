package main

import (
	"flag"
	"github.com/adamboardman/sponsor-hub/server"
	"github.com/gin-gonic/gin"
)

func main() {
	isDebugging := false
	flag.BoolVar(&isDebugging, "debugging", false, "if true, we start in debug mode")
	flag.Parse()

	if !isDebugging {
		gin.SetMode(gin.ReleaseMode)
	}
	a := server.WebApp{}
	a.Init("aye-social")

	a.Run(":3020")
}
