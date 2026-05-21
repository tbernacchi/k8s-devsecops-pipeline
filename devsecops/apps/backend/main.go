package main

import (
	"database/sql"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strconv"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
	log "github.com/sirupsen/logrus"
)

var (
	dbWrite *sql.DB
	dbRead  *sql.DB
)

func mustGetEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		log.Fatalf("missing required environment variable: %s", key)
	}
	return value
}

func initDB() {
	writeDSN := mustGetEnv("DB_WRITE_DSN")
	readDSN := os.Getenv("DB_READ_DSN")
	if readDSN == "" {
		readDSN = writeDSN
	}

	var err error
	dbWrite, err = sql.Open("postgres", writeDSN)
	if err != nil {
		log.WithError(err).Fatal("failed to open write DB")
	}
	dbWrite.SetMaxOpenConns(25)
	dbWrite.SetMaxIdleConns(5)
	if err := dbWrite.Ping(); err != nil {
		log.WithError(err).Fatal("failed to ping write DB")
	}

	dbRead, err = sql.Open("postgres", readDSN)
	if err != nil {
		log.WithError(err).Fatal("failed to open read DB")
	}
	dbRead.SetMaxOpenConns(25)
	dbRead.SetMaxIdleConns(5)
	if err := dbRead.Ping(); err != nil {
		log.WithError(err).Fatal("failed to ping read DB")
	}

	_, err = dbWrite.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id   INTEGER PRIMARY KEY,
			name TEXT NOT NULL
		)
	`)
	if err != nil {
		log.WithError(err).Fatal("failed to create users table")
	}
}

type User struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	if err := dbWrite.Ping(); err != nil {
		log.WithError(err).Error("db ping failed")
		http.Error(w, "db unavailable", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func getUsers(w http.ResponseWriter, r *http.Request) {
	rows, err := dbRead.QueryContext(r.Context(), "SELECT id, name FROM users")
	if err != nil {
		log.WithError(err).Error("getUsers query failed")
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Name); err != nil {
			log.WithError(err).Error("scan failed")
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		users = append(users, u)
	}
	if users == nil {
		users = []User{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

func getUser(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(mux.Vars(r)["id"])
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	var u User
	err = dbRead.QueryRowContext(r.Context(), "SELECT id, name FROM users WHERE id = $1", id).Scan(&u.ID, &u.Name)
	if err == sql.ErrNoRows {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}
	if err != nil {
		log.WithError(err).Error("getUser query failed")
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

func createUser(w http.ResponseWriter, r *http.Request) {
	b, err := io.ReadAll(r.Body)
	defer r.Body.Close()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var u User
	if err := json.Unmarshal(b, &u); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	_, err = dbWrite.ExecContext(r.Context(), "INSERT INTO users (id, name) VALUES ($1, $2)", u.ID, u.Name)
	if err != nil {
		log.WithError(err).Error("createUser insert failed")
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(u)
}

func updateUser(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(mux.Vars(r)["id"])
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	b, err := io.ReadAll(r.Body)
	defer r.Body.Close()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var u User
	if err := json.Unmarshal(b, &u); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	result, err := dbWrite.ExecContext(r.Context(), "UPDATE users SET name = $1 WHERE id = $2", u.Name, id)
	if err != nil {
		log.WithError(err).Error("updateUser exec failed")
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}

	u.ID = id
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

func deleteUser(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(mux.Vars(r)["id"])
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	result, err := dbWrite.ExecContext(r.Context(), "DELETE FROM users WHERE id = $1", id)
	if err != nil {
		log.WithError(err).Error("deleteUser exec failed")
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func main() {
	log.SetFormatter(&log.JSONFormatter{})
	log.SetOutput(os.Stdout)

	initDB()

	router := mux.NewRouter()
	router.HandleFunc("/healthz", healthzHandler).Methods("GET")
	router.HandleFunc("/users", getUsers).Methods("GET")
	router.HandleFunc("/users/{id:[0-9]+}", getUser).Methods("GET")
	router.HandleFunc("/users", createUser).Methods("POST")
	router.HandleFunc("/users/{id:[0-9]+}", updateUser).Methods("PUT")
	router.HandleFunc("/users/{id:[0-9]+}", deleteUser).Methods("DELETE")

	log.Info("Starting backend on :8080")
	if err := http.ListenAndServe(":8080", router); err != nil {
		log.WithError(err).Fatal("server failed")
	}
}
