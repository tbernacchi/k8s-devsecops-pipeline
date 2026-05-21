package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
	"github.com/gorilla/mux"
)

func newTestRouter() *mux.Router {
	r := mux.NewRouter()
	r.HandleFunc("/healthz", healthzHandler).Methods("GET")
	r.HandleFunc("/users", getUsers).Methods("GET")
	r.HandleFunc("/users/{id:[0-9]+}", getUser).Methods("GET")
	r.HandleFunc("/users", createUser).Methods("POST")
	r.HandleFunc("/users/{id:[0-9]+}", updateUser).Methods("PUT")
	r.HandleFunc("/users/{id:[0-9]+}", deleteUser).Methods("DELETE")
	return r
}

func TestHealthz_OK(t *testing.T) {
	db, _, _ := sqlmock.New()
	defer db.Close()
	dbWrite = db

	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if rr.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rr.Code)
	}
}

func TestHealthz_DBDown(t *testing.T) {
	db, _, _ := sqlmock.New()
	dbWrite = db
	db.Close() // closed connection makes Ping() return error

	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("want 503, got %d", rr.Code)
	}
}

func TestGetUsers_Empty(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbRead = db
	mock.ExpectQuery("SELECT id, name FROM users").
		WillReturnRows(sqlmock.NewRows([]string{"id", "name"}))

	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/users", nil))

	if rr.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rr.Code)
	}
	var got []User
	json.NewDecoder(rr.Body).Decode(&got)
	if len(got) != 0 {
		t.Fatalf("want empty slice, got %v", got)
	}
}

func TestGetUsers_WithData(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbRead = db
	mock.ExpectQuery("SELECT id, name FROM users").
		WillReturnRows(sqlmock.NewRows([]string{"id", "name"}).
			AddRow(1, "Alice").
			AddRow(2, "Bob"))

	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/users", nil))

	if rr.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rr.Code)
	}
	var got []User
	json.NewDecoder(rr.Body).Decode(&got)
	if len(got) != 2 {
		t.Fatalf("want 2 users, got %d", len(got))
	}
}

func TestGetUser_Found(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbRead = db
	mock.ExpectQuery("SELECT id, name FROM users WHERE id").
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"id", "name"}).AddRow(1, "Alice"))

	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/users/1", nil))

	if rr.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rr.Code)
	}
	var u User
	json.NewDecoder(rr.Body).Decode(&u)
	if u.ID != 1 || u.Name != "Alice" {
		t.Fatalf("unexpected user: %+v", u)
	}
}

func TestGetUser_NotFound(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbRead = db
	mock.ExpectQuery("SELECT id, name FROM users WHERE id").
		WithArgs(99).
		WillReturnError(sql.ErrNoRows)

	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/users/99", nil))

	if rr.Code != http.StatusNotFound {
		t.Fatalf("want 404, got %d", rr.Code)
	}
}

func TestCreateUser_OK(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbWrite = db
	mock.ExpectExec("INSERT INTO users").
		WithArgs(1, "Alice").
		WillReturnResult(sqlmock.NewResult(1, 1))

	body, _ := json.Marshal(User{ID: 1, Name: "Alice"})
	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodPost, "/users", bytes.NewReader(body)))

	if rr.Code != http.StatusCreated {
		t.Fatalf("want 201, got %d", rr.Code)
	}
}

func TestCreateUser_BadJSON(t *testing.T) {
	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodPost, "/users", bytes.NewBufferString("not-json")))

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", rr.Code)
	}
}

func TestUpdateUser_OK(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbWrite = db
	mock.ExpectExec("UPDATE users SET name").
		WithArgs("Bob", 1).
		WillReturnResult(sqlmock.NewResult(0, 1))

	body, _ := json.Marshal(User{Name: "Bob"})
	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodPut, "/users/1", bytes.NewReader(body)))

	if rr.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rr.Code)
	}
}

func TestUpdateUser_NotFound(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbWrite = db
	mock.ExpectExec("UPDATE users SET name").
		WithArgs("Bob", 99).
		WillReturnResult(sqlmock.NewResult(0, 0))

	body, _ := json.Marshal(User{Name: "Bob"})
	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodPut, "/users/99", bytes.NewReader(body)))

	if rr.Code != http.StatusNotFound {
		t.Fatalf("want 404, got %d", rr.Code)
	}
}

func TestDeleteUser_OK(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbWrite = db
	mock.ExpectExec("DELETE FROM users WHERE id").
		WithArgs(1).
		WillReturnResult(sqlmock.NewResult(0, 1))

	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodDelete, "/users/1", nil))

	if rr.Code != http.StatusNoContent {
		t.Fatalf("want 204, got %d", rr.Code)
	}
}

func TestDeleteUser_NotFound(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	dbWrite = db
	mock.ExpectExec("DELETE FROM users WHERE id").
		WithArgs(99).
		WillReturnResult(sqlmock.NewResult(0, 0))

	rr := httptest.NewRecorder()
	newTestRouter().ServeHTTP(rr, httptest.NewRequest(http.MethodDelete, "/users/99", nil))

	if rr.Code != http.StatusNotFound {
		t.Fatalf("want 404, got %d", rr.Code)
	}
}

func TestMustGetEnv(t *testing.T) {
	os.Setenv("TEST_KEY", "value")
	defer os.Unsetenv("TEST_KEY")
	if got := mustGetEnv("TEST_KEY"); got != "value" {
		t.Fatalf("want 'value', got %q", got)
	}
}
