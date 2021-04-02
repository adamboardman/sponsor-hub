package store

import (
	. "github.com/smartystreets/goconvey/convey"
	"golang.org/x/crypto/bcrypt"
	"os"
	"testing"
)

var s Store

func TestMain(m *testing.M) {
	s = Store{}
	s.StoreInit("test-db")

	code := m.Run()

	_ = s.db.Close()
	os.Exit(code)
}

func ensureTestUserExists(emailAddress string) *User {
	user, err := s.FindUser(emailAddress)
	if err != nil {
		encrypted, err := bcrypt.GenerateFromPassword([]byte("1234"), 13)
		So(err, ShouldBeNil)
		user = &User{
			Password: string(encrypted),
			PrivilegedUser: PrivilegedUser{
				Email:     emailAddress,
				Confirmed: true,
			},
		}
		_, _ = s.InsertUser(user)
	}
	return user
}

func TestStore_DoubleInsertUser(t *testing.T) {
	const emailAddress = "joe@example.com"
	Convey("Insert a user to the store", t, func() {
		s.PurgeUser(emailAddress)
		user := User{}
		user.Email = emailAddress
		user.Name = "Blogs"
		userId, _ := s.InsertUser(&user)

		Convey("User should be given an ID", func() {
			So(userId, ShouldBeGreaterThan, 0)
		})

		Convey("Insert the same email again", func() {
			user2 := User{}
			user2.Email = emailAddress
			user2.Name = "Smith"
			user2Id, err := s.InsertUser(&user2)

			Convey("Expect Error and No UserId", func() {
				So(err, ShouldNotBeNil)
				So(user2Id, ShouldEqual, 0)
			})
		})

	})
}

func TestStore_SurveyCreation(t *testing.T) {
	Convey("Create a survey", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		s.db.Unscoped().Where("user_id=?", user1.ID).Delete(Survey{})
		survey := Survey{
			UserId:         user1.ID,
			GitHubId:       "exampleid",
			Priorities:     "Simple priorities",
			Issues:         "github.com/gemian/issues/2",
			CommsFrequency: "Anything goes",
			PreRelease: 	false,
			Privacy:        "NayBother",
		}
		surveyId, _ := s.InsertSurvey(&survey)
		Convey("Survey should be created", func() {
			surveyLoaded, _ := s.LoadSurveyForUser(user1.ID)
			So(surveyLoaded.ID, ShouldEqual, surveyId)
			So(surveyLoaded.UserId, ShouldEqual, survey.UserId)
			So(surveyLoaded.GitHubId, ShouldEqual, survey.GitHubId)
			So(surveyLoaded.Priorities, ShouldEqual, survey.Priorities)
			So(surveyLoaded.Issues, ShouldEqual, survey.Issues)
			So(surveyLoaded.CommsFrequency, ShouldEqual, survey.CommsFrequency)
			So(surveyLoaded.PreRelease, ShouldEqual, survey.PreRelease)
			So(surveyLoaded.Privacy, ShouldEqual, survey.Privacy)

			Convey("Updating the survey", func() {
				survey.Priorities = "Changed priorities"
				surveyId2, _ := s.UpdateSurvey(surveyLoaded)
				Convey("Concept should keep the same ID and content", func() {
					So(surveyId2, ShouldEqual, surveyId)
					reloadedSurvey, _ := s.LoadSurvey(surveyId2)
					So(reloadedSurvey.ID, ShouldEqual, surveyLoaded.ID)
					So(reloadedSurvey.UserId, ShouldEqual, surveyLoaded.UserId)
					So(reloadedSurvey.GitHubId, ShouldEqual, surveyLoaded.GitHubId)
					So(reloadedSurvey.Priorities, ShouldEqual, surveyLoaded.Priorities)
					So(reloadedSurvey.Issues, ShouldEqual, surveyLoaded.Issues)
					So(reloadedSurvey.CommsFrequency, ShouldEqual, surveyLoaded.CommsFrequency)
					So(reloadedSurvey.PreRelease, ShouldEqual, surveyLoaded.PreRelease)
					So(reloadedSurvey.Privacy, ShouldEqual, surveyLoaded.Privacy)
				})
			})
		})
	})
}
