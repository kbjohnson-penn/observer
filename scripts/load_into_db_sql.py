import os
import subprocess

# Database connection config
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "rootpassword",
    "database": "observer_research",
}

# Folder containing the SQL files
SQL_FOLDER = r"C:\Users\mhill1\Downloads\helper_functions\dumps"

# Order of SQL files to run
SQL_ORDER = [
    "concept.sql",
    "provider.sql",
    "person.sql",
    "visit_occurrence.sql",
    "note.sql",
    "condition_occurrence.sql",
    "drug_exposure.sql",
    "procedure_occurrence.sql",
    "observation.sql",
    "measurement.sql",
    "audit_logs.sql",
    "patient_survey.sql",
    "provider_survey.sql",
    "labs.sql",
]

def run_sql_file(file_path):
    command = [
        "mysql",
        f"-h{DB_CONFIG['host']}",
        f"-u{DB_CONFIG['user']}",
        f"-p{DB_CONFIG['password']}",
        DB_CONFIG["database"],
    ]

    with open(file_path, "rb") as sql_file:
        process = subprocess.run(
            command,
            stdin=sql_file,
            capture_output=True,
            text=True
        )

    if process.returncode != 0:
        raise Exception(process.stderr)

def main():
    try:
        for sql_file in SQL_ORDER:
            file_path = os.path.join(SQL_FOLDER, sql_file)

            print(f"📥 Loading SQL file {sql_file} into Observer database...")

            run_sql_file(file_path)

        print("✅ All SQL files loaded successfully.")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()