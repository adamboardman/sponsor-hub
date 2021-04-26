package server

import (
	"errors"
	"fmt"
	"github.com/adamboardman/sponsor-hub/store"
	jwt "github.com/appleboy/gin-jwt"
	"github.com/gin-gonic/contrib/static"
	"github.com/gin-gonic/gin"
	"net/http"
	"os"
	"strconv"
)

type WebApp struct {
	Router        *gin.Engine
	Store         *store.Store
	JwtMiddleware *jwt.GinJWTMiddleware
}

var App *WebApp

func (a *WebApp) Init(dbName string) {
	App = a
	a.Store = &store.Store{}
	a.Store.StoreInit("test-db")

	// Set the router as the default one shipped with Gin
	router := gin.Default()
	a.Router = router

	addWebAppStaticFiles(router)
	addApiRoutes(a, router)
	addDefaultRouteToWebApp(router)
}

func addApiRoutes(a *WebApp, router *gin.Engine) {
	api := router.Group("/api")
	addApiRoutesToApi(a, api)
	sponsorHubApi := router.Group("/sponsor-hub/api")
	addApiRoutesToApi(a, sponsorHubApi)
}

func addApiRoutesToApi(a *WebApp, api *gin.RouterGroup) {
	api.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "root of the API does nothing, next?"})
	})

	a.JwtMiddleware = a.InitAuth(api)
	api.GET("/users/:userID", a.JwtMiddleware.MiddlewareFunc(), LoadUser)
	api.PUT("/users/:userID", a.JwtMiddleware.MiddlewareFunc(), UpdateUser)
	api.GET("/surveys", a.JwtMiddleware.MiddlewareFunc(), UserPermissionsRequired(), SurveysList)
	api.GET("/surveys/:surveyID", a.JwtMiddleware.MiddlewareFunc(), LoadSurvey)
	api.POST("/surveys", a.JwtMiddleware.MiddlewareFunc(), AddSurvey)
	api.PUT("/surveys/:surveyID", a.JwtMiddleware.MiddlewareFunc(), UpdateSurvey)
	api.GET("/surveys/:surveyID/sponsors", a.JwtMiddleware.MiddlewareFunc(), LoadSurveySponsors)
	api.POST("/surveys/:surveyID/sponsors", a.JwtMiddleware.MiddlewareFunc(), AddSurveySponsor)
	api.DELETE("/surveys/:surveyID/sponsors/:userID", a.JwtMiddleware.MiddlewareFunc(), DeleteSurveySponsor)
	api.GET("/sponsorable", a.JwtMiddleware.MiddlewareFunc(), SponsorableUsersList)
	api.GET("/prereleaseusers", a.JwtMiddleware.MiddlewareFunc(), AdminPermissionsRequired(), PreReleaseUsersList)
}

func UserPermissionsRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		UserPermissionsRequiredImpl(c)
	}
}

func UserPermissionsRequiredImpl(c *gin.Context) {
	claims := jwt.ExtractClaims(c)
	userId := uint(claims[identityId].(float64))
	user, err := App.Store.LoadPrivilegedUserAsSelf(userId, userId)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "User not found"})
		return
	}
	if !(user.Permissions >= store.UserPermissionsUser) {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText": "User is not an user or admin"})
		return
	}
	c.Next()
}

func AdminPermissionsRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		AdminPermissionsRequiredImpl(c)
	}
}

func AdminPermissionsRequiredImpl(c *gin.Context) {
	claims := jwt.ExtractClaims(c)
	userId := uint(claims[identityId].(float64))
	user, err := App.Store.LoadPrivilegedUserAsSelf(userId, userId)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "User not found"})
		return
	}
	if !(user.Permissions >= store.UserPermissionsAdmin) {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText": "User is not an admin"})
		return
	}
	c.Next()
}

func Exists(name string) bool {
	_, err := os.Stat(name)
	return !os.IsNotExist(err)
}

func addDefaultRouteToWebApp(router *gin.Engine) {
	router.NoRoute(func(c *gin.Context) {
		if Exists("./public/index.html") {
			c.File("./public/index.html")
		} else {
			c.File("../public/index.html")
		}
	})
}

func (a *WebApp) Run(addr string) {
	_ = a.Router.Run(addr)
}

func addWebAppStaticFiles(router *gin.Engine) {
	router.Static("/public", "./public")
	router.Static("/sponsor-hub/public", "./public")
	router.Use(static.Serve("/dist", static.LocalFile("./dist", true)))
}

func LoadUser(c *gin.Context) {
	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	c.Header("Content-Type", "application/json")
	userId, err := strconv.Atoi(c.Param("userID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid UserID"})
		return
	}
	if userId == 0 || uint(userId) == loggedInUserId {
		user, err := App.Store.LoadPrivilegedUserAsSelf(loggedInUserId, loggedInUserId)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "User not found"})
			return
		}
		c.JSON(http.StatusOK, user)
	} else {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText": "Trying to load someone else's details?"})
	}
}

func UpdateUser(c *gin.Context) {
	userId, err := strconv.Atoi(c.Param("userID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("UserID - err: %s", err.Error())})
		return
	}

	user, err := readJSONIntoUser(uint(userId), c)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("User details failed validation - err: %s", err.Error())})
		return
	}

	_, err = App.Store.UpdateUser(user)
	if err == nil {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "User updated successfully", "resourceId": userId,
		})
	}
}

func readJSONIntoUser(id uint, c *gin.Context) (*store.User, error) {
	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	if id != loggedInUserId {
		err := errors.New("Only the logged in user can update their profile")
		return nil, err
	}
	user, err := App.Store.LoadUserAsSelf(uint(id), loggedInUserId)
	if err != nil {
		return nil, err
	}
	userJson := UserJSON{}
	err = c.BindJSON(&userJson)
	if err != nil {
		return nil, err
	}

	user.Name = userJson.Name
	user.Email = userJson.Email

	return user, err
}

type UserJSON struct {
	Name  string
	Email string
}

func SurveysList(c *gin.Context) {
	c.Header("Content-Type", "application/json")

	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	surveys, err := App.Store.ListSurveysForUserId(loggedInUserId)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": fmt.Sprintf("Surveys not found")})
	} else {
		c.JSON(http.StatusOK, surveys)
	}
}

func SponsorableUsersList(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	sponsorableUsers, err := App.Store.ListSponsorableUsers()
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": fmt.Sprintf("No sponsorable users found")})
	} else {
		c.JSON(http.StatusOK, sponsorableUsers)
	}
}

func PreReleaseUsersList(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	preReleaseUsers, err := App.Store.ListPreReleaseUsers()
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": fmt.Sprintf("No users have selected pre-release notifications found")})
	} else {
		c.JSON(http.StatusOK, preReleaseUsers)
	}
}

func AddSurveySponsor(c *gin.Context) {
	surveySponsor := store.SurveySponsor{}

	err := readJSONIntoSurveySponsor(&surveySponsor, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("SurveySponsor failed validation - err: %s", err.Error())})
		return
	}
	if surveySponsor.SurveyId == 0 && surveySponsor.UserId != 0 {
		claims := jwt.ExtractClaims(c)
		loggedInUserId := uint(claims["id"].(float64))

		savedSurvey, err := App.Store.LoadSurveyForUser(loggedInUserId)
		if err == nil {
			surveySponsor.SurveyId = savedSurvey.ID
		} else {
			savedSurvey.UserId = loggedInUserId
			surveyId, err := App.Store.InsertSurvey(savedSurvey)
			if err == nil {
				surveySponsor.SurveyId = surveyId
			}
		}
	}

	surveySponsorId, err := App.Store.InsertSurveySponsor(&surveySponsor)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Insert SurveySponsor failed"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "Added Survey Sponsor successfully", "resourceId": surveySponsorId,
	})
}

func LoadSurvey(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	surveyId, err := strconv.Atoi(c.Param("surveyID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid SurveyID"})
		return
	}
	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	survey := &store.Survey{}
	if surveyId == 0 {
		survey, err = App.Store.LoadSurveyForUser(loggedInUserId)
	} else {
		survey, err = App.Store.LoadSurvey(uint(surveyId))
	}
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Survey not found"})
		return
	}

	if survey.UserId != loggedInUserId {
		var currentUser, err = App.Store.LoadUserAsSelf(loggedInUserId, loggedInUserId)
		if err != nil || (currentUser.Permissions != store.UserPermissionsAdmin && currentUser.Permissions != store.UserPermissionsUser) {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Attempt to load someone elses survey")})
			return
		}
	}

	json := SurveyJSON{}
	json.ID = survey.ID
	json.Name = survey.Name
	json.GitHubId = survey.GitHubId
	json.Priorities = survey.Priorities
	json.Issues = survey.Issues
	json.CommsFrequency = survey.CommsFrequency
	json.PreRelease = survey.PreRelease
	json.Privacy = survey.Privacy
	c.JSON(http.StatusOK, json)
}

func LoadSurveySponsors(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	surveyId, err := strconv.Atoi(c.Param("surveyID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid SurveyID"})
		return
	}
	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	survey, err := App.Store.LoadSurvey(uint(surveyId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Survey not found"})
		return
	}
	if survey.UserId != loggedInUserId {
		var currentUser, err = App.Store.LoadUserAsSelf(loggedInUserId, loggedInUserId)
		if err != nil || (currentUser.Permissions != store.UserPermissionsAdmin && currentUser.Permissions != store.UserPermissionsUser) {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Attempt to load someone elses survey")})
			return
		}
	}

	sponsors, err := App.Store.SponsorsForSurveyId(uint(surveyId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "SurveySponsors not found"})
		return
	}

	c.JSON(http.StatusOK, sponsors)
}

func AddSurvey(c *gin.Context) {
	survey := store.Survey{}

	err := readJSONIntoSurvey(&survey, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Survey failed validation - err: %s", err.Error())})
		return
	}

	claims := jwt.ExtractClaims(c)
	survey.UserId = uint(claims["id"].(float64))

	if survey.ID != 0 {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Survey failed validation - ID not zero")})
		return
	}

	savedSurvey, err := App.Store.LoadSurveyForUser(survey.UserId)
	surveyId := savedSurvey.ID
	if err == nil {
		survey.ID = surveyId
		_, err = App.Store.UpdateSurvey(&survey)
	} else {
		surveyId, err = App.Store.InsertSurvey(&survey)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Insert Survey failed"})
			return
		}
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "Survey created successfully", "resourceId": surveyId,
	})
}

func UpdateSurvey(c *gin.Context) {
	surveyId, err := strconv.Atoi(c.Param("surveyID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("SurveyID invalid - err: %s", err.Error())})
		return
	}

	survey, err := App.Store.LoadSurvey(uint(surveyId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Survey not found"})
		return
	}

	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))
	if survey.UserId != loggedInUserId {
		var currentUser, err = App.Store.LoadUserAsSelf(loggedInUserId, loggedInUserId)
		if err != nil || (currentUser.Permissions != store.UserPermissionsAdmin) {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Attempt to update someone elses survey")})
			return
		}
	}

	err = readJSONIntoSurvey(survey, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Survey details failed validation - err: %s", err.Error())})
		return
	}

	_, err = App.Store.UpdateSurvey(survey)
	if err == nil {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "Concept updated successfully", "resourceId": surveyId,
		})
	}
}

func readJSONIntoSurvey(survey *store.Survey, c *gin.Context, forceUpdate bool) error {
	surveyJSON := SurveyJSON{}
	err := c.BindJSON(&surveyJSON)
	if err != nil {
		return err
	}

	if forceUpdate || surveyJSON.ID == 0 {
		survey.Name = surveyJSON.Name
		survey.GitHubId = surveyJSON.GitHubId
		survey.Priorities = surveyJSON.Priorities
		survey.Issues = surveyJSON.Issues
		survey.CommsFrequency = surveyJSON.CommsFrequency
		survey.PreRelease = surveyJSON.PreRelease
		survey.Privacy = surveyJSON.Privacy
	}

	return nil
}

type SurveyJSON struct {
	ID             uint
	Name           string
	GitHubId       string
	Priorities     string
	Issues         string
	CommsFrequency string
	PreRelease     bool
	Privacy        string
}

func readJSONIntoSurveySponsor(surveySponsor *store.SurveySponsor, c *gin.Context, forceUpdate bool) error {
	surveyJSON := SurveySponsorJSON{}
	err := c.BindJSON(&surveyJSON)
	if err != nil {
		return err
	}

	if forceUpdate || surveyJSON.ID == 0 {
		surveySponsor.UserId = surveyJSON.UserId
		surveyId, err := strconv.Atoi(c.Param("surveyID"))
		if err == nil {
			surveySponsor.SurveyId = uint(surveyId)
		}
	}

	return nil
}

type SurveySponsorJSON struct {
	ID       uint
	SurveyId uint
	UserId   uint
}

func DeleteSurveySponsor(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	surveyId, err := strconv.Atoi(c.Param("surveyID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Invalid SurveyID - err: %s", err.Error())})
		return
	}
	userId, err := strconv.Atoi(c.Param("userID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Invalid UserID - err: %s", err.Error())})
		return
	}
	if surveyId == 0 {
		claims := jwt.ExtractClaims(c)
		loggedInUserId := uint(claims["id"].(float64))
		savedSurvey, err := App.Store.LoadSurveyForUser(loggedInUserId)
		if err == nil {
			surveyId = int(savedSurvey.ID)
		}
	}
	err = App.Store.DeleteSurveySponsor(uint(surveyId), uint(userId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Delete SurveySponsor Failed - err: %s", err.Error())})
	} else {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "SurveySponsor deleted",
		})
	}
}
