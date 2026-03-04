import subprocess
import os


def dump_tables(host, user, password, database, tables, output_dir="dumps"):
    """Dump specified tables using mysqldump in the given order, saving each to a separate SQL file."""
    # Create output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    for table in tables:
        output_file = os.path.join(output_dir, f"{table.lower()}.sql")
        try:
            # Construct mysqldump command
            cmd = [
                "mysqldump",
                "-h", host,
                "-u", user,
                f"--password={password}",
                "--default-character-set=utf8mb4",
                "--set-charset",
                "--single-transaction",
                "--skip-extended-insert",
                "--hex-blob",
                "--routines",
                "--triggers",
                database,
                table,
            ]
            # Run mysqldump and redirect output to file
            with open(output_file, "w") as f:
                result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True, check=True)
            print(f"📥 Successfully dumped table '{table}' to {output_file}")
        except subprocess.CalledProcessError as err:
            print(f"❌ Error dumping table '{table}': {err.stderr}")
        except Exception as err:
            print(f"❌ Unexpected error for table '{table}': {err}")
            

def main():
    # Database connection details
    host="localhost"
    user="observer"
    password="observer_password"
    database="observer_research"

    # Load order (case-insensitive table names)
    load_order = [
        "concept",
        "provider",
        "person",
        "visit_occurrence",
        "note",
        "condition_occurrence",
        "drug_exposure",
        "procedure_occurrence",
        "observation",
        "measurement",
        "audit_logs",
        "patient_survey",
        "provider_survey",
        "labs"
    ]

    # Convert load_order to lowercase for case-insensitive matching
    tables = load_order

    # Specify output directory
    output_dir = input("Enter output directory for SQL files (default: 'dumps'): ") or "dumps"

    # Dump tables in the specified order
    dump_tables(host, user, password, database, tables, output_dir)

if __name__ == "__main__":
    main()