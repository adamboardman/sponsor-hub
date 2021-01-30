package store

import (
	"database/sql/driver"
	"errors"
	"github.com/adamboardman/gorm"
	_ "github.com/adamboardman/gorm/dialects/postgres"
	"io/ioutil"
	"log"
	"strconv"
	"time"
)

type Store struct {
	db *gorm.DB
}

type PublicUser struct {
	gorm.Model
	Name string
}

func (PublicUser) TableName() string {
	return "users"
}

type UserPermissions int

const (
	UserPermissionsUser UserPermissions = iota + 1
	UserPermissionsEditor
	UserPermissionsAdmin
)

type User struct {
	PrivilegedUser
	Salt               string `json:"-"`
	Password           string `json:"-"`
	ConfirmVerifier    string `json:"-"`
	RecoverVerifier    string `json:"-"`
	RecoverTokenExpiry string `json:"-"`
}

type PrivilegedUser struct {
	PublicUser
	Email        string `gorm:"unique_index"`
	Confirmed    bool
	AttemptCount int    `json:"-"`
	LastAttempt  string `json:"-"`
	Locked       string `json:"-"`
	Permissions  UserPermissions
}

type Survey struct {
	gorm.Model
	UserId         uint
	Name           string
	GitHubId       string
	Priorities     string
	CommsFrequency string
	Privacy        string
}

type PosixDateTime time.Time

func (d PosixDateTime) MarshalJSON() ([]byte, error) {
	if time.Time(d).IsZero() {
		return []byte("0"), nil
	}
	return []byte(strconv.FormatInt(time.Time(d).Unix(), 10)), nil
}

func (d *PosixDateTime) UnmarshalJSON(b []byte) (err error) {
	p, err := strconv.ParseInt(string(b), 10, 64)
	if err != nil {
		return
	}
	t := time.Unix(p, 0)
	*d = PosixDateTime(t)
	return
}

func (d PosixDateTime) Value() (driver.Value, error) {
	return time.Time(d), nil
}

func (d *PosixDateTime) Scan(src interface{}) error {
	if val, ok := src.(time.Time); ok {
		*d = PosixDateTime(val)
	}
	return nil
}

func readPostgresArgs() string {
	const postgresArgsFileName = "postgres_args.txt"
	postgresArgs, err := ioutil.ReadFile(postgresArgsFileName)
	if err != nil {
		postgresArgs, err = ioutil.ReadFile("../" + postgresArgsFileName)
		if err != nil {
			postgresArgs = []byte("host=myhost port=myport sslmode=disable user=thinkglobally dbname=concepts password=mypassword")
			err = ioutil.WriteFile(postgresArgsFileName, postgresArgs, 0666)
			if err != nil {
				log.Fatal(err)
			}
		}
	}
	return string(postgresArgs)
}

func (s *Store) StoreInit(dbName string) {
	db, err := gorm.Open("postgres", readPostgresArgs())

	if err != nil {
		log.Fatal(err)
	}
	s.db = db

	_, _ = db.DB().Exec("CREATE EXTENSION postgis;")

	err = db.AutoMigrate(&User{}, &Survey{}).Error
	if err != nil {
		log.Fatal(err)
	}

	//DEBUG - add/remove to investigate SQL queries being executed
	//db.LogMode(true)
}

func (s *Store) InsertUser(user *User) (uint, error) {
	err := s.db.Create(user).Error
	return user.ID, err
}

func (s *Store) UpdateUser(user *User) (uint, error) {
	err := s.db.Save(user).Error
	return user.ID, err
}

func (s *Store) FindUser(email string) (*User, error) {
	user := User{}
	err := s.db.Where("email=?", email).Find(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, err
}

func (s *Store) PurgeUser(email string) {
	s.db.Unscoped().Where("email=?", email).Delete(User{})
}

func (s *Store) LoadPublicUser(id uint) (*PublicUser, error) {
	user := User{}
	err := s.db.Where("id=?", id).Find(&user).Error
	if err != nil {
		return nil, err
	}
	publicUser := PublicUser{}
	publicUser.ID = user.ID
	publicUser.Name = user.Name
	return &publicUser, err
}

func (s *Store) LoadPrivilegedUserAsSelf(userId uint, loggedInUserId uint) (*PrivilegedUser, error) {
	if userId != loggedInUserId {
		return nil, errors.New("cannot load others users")
	}
	user := PrivilegedUser{}
	err := s.db.Where("id=?", userId).Find(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, err
}

func (s *Store) LoadUserAsSelf(userId uint, loggedInUserId uint) (*User, error) {
	if userId != loggedInUserId {
		return nil, errors.New("cannot load others users")
	}
	user := User{}
	err := s.db.Where("id=?", userId).Find(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, err
}

func (s *Store) InsertSurvey(survey *Survey) (uint, error) {
	err := s.db.Create(survey).Error
	return survey.ID, err
}

func (s *Store) UpdateSurvey(survey *Survey) (uint, error) {
	err := s.db.Save(survey).Error
	return survey.ID, err
}

func (s *Store) LoadSurvey(id uint) (*Survey, error) {
	survey := Survey{}
	err := s.db.Where("id=?", id).Find(&survey).Error
	return &survey, err
}

func (s *Store) LoadSurveyForUser(id uint) (*Survey, error) {
	survey := Survey{}
	err := s.db.Where("user_id=?", id).Find(&survey).Error
	return &survey, err
}

func (s *Store) ListSurveys() ([]Survey, error) {
	var surveys []Survey
	err := s.db.Limit(200).Order("name").Find(&surveys).Error
	if err != nil {
		return nil, err
	}
	return surveys, err
}
